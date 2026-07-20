import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/events.dart';

/// Advances Draw and Momentum.
///
/// The rhythm this produces — root to escalate, move to survive, repeat — is
/// the second-to-second loop of the entire game (docs/01-vision.md §1.1). Every
/// constant it reads is in [DrawState]; this system only sequences them.
///
/// Ordering note: this runs *after* movement, so `isMoving` reflects the motion
/// that actually happened this tick rather than the input that requested it.
/// A player pinned against a wall is standing still, and the Draw should ramp —
/// which is both what the mechanic promises and what players expect.
abstract final class DrawSystem {
  static void update(
    DrawState state,
    bool isMoving,
    double dt,
    SimEventBuffer events,
  ) {
    final DrawTier tierBefore = state.tier;
    final int momentumBefore = state.momentumStacks;

    if (state.drawLockRemaining > 0) {
      state.drawLockRemaining -= dt;
      if (state.drawLockRemaining < 0) state.drawLockRemaining = 0;
    }

    if (isMoving) {
      _updateMoving(state, dt);
    } else {
      _updateStationary(state, dt);
    }

    state.wasMovingLastTick = isMoving;

    final DrawTier tierAfter = state.tier;
    if (tierAfter != tierBefore) {
      events.emit(
        SimEventType.drawTierChanged,
        valueA: tierAfter.index.toDouble(),
        valueB: tierBefore.index.toDouble(),
      );
    }
    if (state.momentumStacks != momentumBefore) {
      events.emit(
        SimEventType.momentumChanged,
        valueA: state.momentumStacks.toDouble(),
        valueB: momentumBefore.toDouble(),
      );
    }
  }

  static void _updateMoving(DrawState state, double dt) {
    // Moving drops the Draw immediately and completely. No partial retention —
    // the decision to move must cost the whole ramp, or the trade is not a
    // trade.
    state.drawSeconds = 0;
    state.sinceStoppedSeconds = 0;

    if (state.momentumStacks < state.maxMomentum) {
      state.momentumChargeSeconds += dt;
      while (state.momentumChargeSeconds >= DrawState.secondsPerMomentumStack &&
          state.momentumStacks < state.maxMomentum) {
        state.momentumChargeSeconds -= DrawState.secondsPerMomentumStack;
        state.momentumStacks++;
      }
    } else {
      // At cap, hold the charge at zero so a stack is not banked for later.
      state.momentumChargeSeconds = 0;
    }
  }

  static void _updateStationary(DrawState state, double dt) {
    if (!state.isDrawLocked) {
      state.drawSeconds += dt;
    }

    state.sinceStoppedSeconds += dt;

    // Momentum survives a brief pause, then drops all at once. The grace window
    // is what lets a player tap-stop to fire without immediately losing their
    // defensive layer — and the hard cliff afterwards is what makes the loss
    // legible when it happens.
    if (state.sinceStoppedSeconds >= DrawState.momentumGraceSeconds &&
        state.momentumStacks > 0) {
      state.momentumStacks = 0;
      state.momentumChargeSeconds = 0;
    }
  }
}
