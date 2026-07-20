import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';

/// Encodes and decodes a [PlayerSave], with an integrity tag.
///
/// **On the integrity tag:** this is tamper *deterrence*, not anti-cheat. The
/// key is derived on-device, so a determined attacker with the binary can forge
/// it. That is accepted: the goal is to stop casual save editing (a text editor
/// and a JSON file) and to detect genuine corruption, both of which it does
/// well. Real anti-cheat is server-side run replay, which the deterministic
/// simulation in docs/12-architecture.md §12.0 leaves the door open for.
///
/// Claiming more than that in a design doc, and then shipping a client-side
/// HMAC, is how teams end up believing their economy is secure when it is not.
class SaveCodec {
  const SaveCodec({required String integritySalt}) : _salt = integritySalt;

  /// Compiled-in salt. Not a secret — see the class doc.
  final String _salt;

  static const String _payloadKey = 'payload';
  static const String _tagKey = 'tag';
  static const String _versionKey = 'schemaVersion';

  /// Serialises [save] into a self-describing envelope.
  ///
  /// The envelope carries `schemaVersion` at the top level, *outside* the
  /// payload, so the migration runner can read the version without first
  /// decoding a payload it may not understand.
  String encode(PlayerSave save) {
    final String payload = jsonEncode(save.toJson());
    return jsonEncode(<String, dynamic>{
      _versionKey: save.schemaVersion,
      _payloadKey: payload,
      _tagKey: _tag(payload),
    });
  }

  /// Reads the schema version from an envelope without decoding the payload.
  Result<int, AppError> peekVersion(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const Err<int, AppError>(
          SaveError.corrupt('envelope is not an object'),
        );
      }
      final Object? version = decoded[_versionKey];
      if (version is! int) {
        return const Err<int, AppError>(
          SaveError.corrupt('missing schemaVersion'),
        );
      }
      return Ok<int, AppError>(version);
    } catch (error) {
      return Err<int, AppError>(SaveError.corrupt(error));
    }
  }

  /// Decodes an envelope into a raw JSON map, verifying integrity.
  ///
  /// Returns the map rather than a [PlayerSave] because migrations operate on
  /// untyped JSON — a save from an older schema cannot necessarily be parsed
  /// into today's model.
  Result<Map<String, dynamic>, AppError> decodeToJson(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      return Err<Map<String, dynamic>, AppError>(SaveError.corrupt(error));
    }

    if (decoded is! Map<String, dynamic>) {
      return const Err<Map<String, dynamic>, AppError>(
        SaveError.corrupt('envelope is not an object'),
      );
    }

    final Object? payload = decoded[_payloadKey];
    final Object? tag = decoded[_tagKey];
    if (payload is! String || tag is! String) {
      return const Err<Map<String, dynamic>, AppError>(
        SaveError.corrupt('envelope missing payload or tag'),
      );
    }

    if (!_constantTimeEquals(tag, _tag(payload))) {
      return const Err<Map<String, dynamic>, AppError>(
        SaveError.integrityFailed(),
      );
    }

    try {
      final Object? body = jsonDecode(payload);
      if (body is! Map<String, dynamic>) {
        return const Err<Map<String, dynamic>, AppError>(
          SaveError.corrupt('payload is not an object'),
        );
      }
      return Ok<Map<String, dynamic>, AppError>(body);
    } catch (error) {
      return Err<Map<String, dynamic>, AppError>(SaveError.corrupt(error));
    }
  }

  /// Parses an already-migrated JSON map into a [PlayerSave].
  Result<PlayerSave, AppError> fromJson(Map<String, dynamic> json) {
    try {
      return Ok<PlayerSave, AppError>(PlayerSave.fromJson(json));
    } catch (error) {
      return Err<PlayerSave, AppError>(SaveError.corrupt(error));
    }
  }

  String _tag(String payload) =>
      Hmac(sha256, utf8.encode(_salt)).convert(utf8.encode(payload)).toString();

  /// Compares in time independent of where the first difference falls.
  ///
  /// Overkill for a local file, but it costs nothing and means this routine can
  /// be reused for server-issued tokens later without becoming a timing oracle.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
