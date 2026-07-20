import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:quiverfall/core/clock.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/local/save_store.dart';
import 'package:quiverfall/data/models/player_save.dart';

/// Owns the in-memory [PlayerSave] and its persistence.
///
/// Everything in the app reads and mutates the save through this object; no
/// feature touches [SaveStore] directly.
///
/// **Write policy** (docs/12-architecture.md §12.7): mutations are applied to
/// memory immediately and persisted on a 400 ms debounce, plus an unconditional
/// flush when the app is backgrounded. Writing synchronously on every mutation
/// would put disk I/O on the frame path during a run — a Spire purchase or a
/// gold pickup must never cost a frame.
class PlayerRepository {
  PlayerRepository({
    required SaveStore store,
    required Clock clock,
    required Logger logger,
    Duration debounce = const Duration(milliseconds: 400),
  })  : _store = store,
        _clock = clock,
        _logger = logger,
        _debounce = debounce;

  final SaveStore _store;
  final Clock _clock;
  final Logger _logger;
  final Duration _debounce;

  /// Current save. Listenable so UI can rebuild on change without Riverpod
  /// needing to sit in the hot path.
  final ValueNotifier<PlayerSave?> saveNotifier =
      ValueNotifier<PlayerSave?>(null);

  Timer? _debounceTimer;
  bool _dirty = false;
  bool _writing = false;

  /// True when the last load had to fall back to a backup slot. Phase 17 reports
  /// this as `save_recovered`.
  bool lastLoadRecoveredFromBackup = false;

  /// Non-null when the last load ran a migration, carrying the source version.
  int? lastLoadMigratedFrom;

  PlayerSave get save {
    final PlayerSave? current = saveNotifier.value;
    if (current == null) {
      throw StateError(
        'PlayerRepository.save read before load(). '
        'Bootstrap must complete before any feature reads the save.',
      );
    }
    return current;
  }

  bool get isLoaded => saveNotifier.value != null;

  /// Loads the save, creating a fresh one if none exists.
  ///
  /// A genuinely absent save is not an error — it is a new player. Every other
  /// failure is surfaced, because silently replacing an unreadable save with a
  /// blank one would erase a real player's progress.
  Future<Result<PlayerSave, AppError>> load({
    required String Function() newPlayerIdFactory,
  }) async {
    final Result<SaveReadResult, AppError> read = await _store.read();

    switch (read) {
      case Ok<SaveReadResult, AppError>(value: final SaveReadResult result):
        lastLoadRecoveredFromBackup = result.recoveredFromBackup;
        lastLoadMigratedFrom = result.migratedFrom;
        final PlayerSave touched =
            result.save.copyWith(lastSeenAt: _clock.nowUtc());
        saveNotifier.value = touched;
        // A recovered or migrated save is written straight back so the repaired
        // state becomes the new primary rather than being re-derived every
        // launch.
        if (result.recoveredFromBackup || result.migratedFrom != null) {
          _markDirty(immediate: true);
        }
        return Ok<PlayerSave, AppError>(touched);

      case Err<SaveReadResult, AppError>(error: final AppError error):
        if (error.code == 'save_not_found') {
          final DateTime now = _clock.nowUtc();
          final PlayerSave fresh = PlayerSave.initial(
            playerId: newPlayerIdFactory(),
            now: now,
          );
          saveNotifier.value = fresh;
          _logger.i('Created new player save', tag: 'save');
          final Result<void, AppError> written = await _store.write(fresh);
          if (written case Err<void, AppError>(error: final AppError e)) {
            return Err<PlayerSave, AppError>(e);
          }
          return Ok<PlayerSave, AppError>(fresh);
        }
        _logger.e('Save load failed', tag: 'save', error: error);
        return Err<PlayerSave, AppError>(error);
    }
  }

  /// Applies [transform] to the save and schedules a debounced write.
  ///
  /// The transform must be pure — it may be invoked while a write is in flight.
  void mutate(PlayerSave Function(PlayerSave save) transform) {
    saveNotifier.value = transform(save);
    _markDirty();
  }

  /// Applies [transform] and persists before returning.
  ///
  /// Use for mutations that must not be lost if the process dies immediately
  /// afterwards: completed purchases, granted ad rewards, run results.
  Future<Result<void, AppError>> mutateAndFlush(
    PlayerSave Function(PlayerSave save) transform,
  ) async {
    saveNotifier.value = transform(save);
    return flush();
  }

  void _markDirty({bool immediate = false}) {
    _dirty = true;
    _debounceTimer?.cancel();
    if (immediate) {
      unawaited(flush());
      return;
    }
    _debounceTimer = Timer(_debounce, () {
      unawaited(flush());
    });
  }

  /// Persists immediately if there is anything pending.
  ///
  /// Called on `AppLifecycleState.paused`, before showing an ad, and after any
  /// transaction that must survive a crash.
  Future<Result<void, AppError>> flush() async {
    _debounceTimer?.cancel();
    if (!_dirty || !isLoaded) {
      return const Ok<void, AppError>(null);
    }
    if (_writing) {
      // A write is already in flight; leave _dirty set so the in-flight write's
      // continuation picks up the newer state.
      return const Ok<void, AppError>(null);
    }

    _writing = true;
    _dirty = false;
    try {
      final Result<void, AppError> result = await _store.write(save);
      if (result case Err<void, AppError>(error: final AppError error)) {
        // Restore the dirty flag: the data is still unpersisted, and a later
        // flush should retry rather than assume success.
        _dirty = true;
        _logger.e('Save flush failed', tag: 'save', error: error);
        return Err<void, AppError>(error);
      }
      await _store.flush();
      return const Ok<void, AppError>(null);
    } finally {
      _writing = false;
      if (_dirty) {
        // State changed while we were writing — schedule another pass.
        _markDirty();
      }
    }
  }

  /// Wipes local data. Used by "Delete account" in Settings.
  Future<Result<void, AppError>> deleteEverything() async {
    _debounceTimer?.cancel();
    _dirty = false;
    saveNotifier.value = null;
    return _store.clear();
  }

  void dispose() {
    _debounceTimer?.cancel();
    saveNotifier.dispose();
  }
}
