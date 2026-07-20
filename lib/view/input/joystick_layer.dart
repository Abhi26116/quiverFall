import 'package:flutter/widgets.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/game/feel/joystick_model.dart';
import 'package:quiverfall/game/feel/juice.dart';

/// The floating joystick, as a widget.
///
/// docs/10 §10.6: it appears wherever the left thumb lands in the bottom-left
/// of the screen, and is **invisible until touched**. The invisibility is not
/// minimalism — a permanently drawn stick anchors the thumb to one spot, and a
/// game whose core trade is "move or root" cannot afford to make moving feel
/// like reaching.
///
/// All the maths lives in [JoystickModel]. This widget only converts pointer
/// events into calls on it and draws the result, which is what keeps the
/// feel-critical part testable without a widget tree.
class JoystickLayer extends StatefulWidget {
  const JoystickLayer({
    required this.model,
    required this.child,
    this.leftHanded = false,
    super.key,
  });

  final JoystickModel model;
  final Widget child;

  /// Mirrors the stick zone to the right. docs/10 §10.0 lists left-handed mode
  /// as a gated accessibility requirement, not an option.
  final bool leftHanded;

  @override
  State<JoystickLayer> createState() => _JoystickLayerState();
}

class _JoystickLayerState extends State<JoystickLayer> {
  /// Repaint signal. A `ValueNotifier` rather than `setState` so a thumb drag
  /// repaints one `CustomPaint` instead of rebuilding the widget subtree at
  /// 60 Hz — the HUD above this must not be laid out again every frame.
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  /// The pointer that owns the stick. A second finger — reaching for the
  /// ultimate button — must never steal movement mid-strafe.
  int? _pointer;

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;

    final Size size = context.size ?? Size.zero;
    if (!JoystickModel.claims(
      event.localPosition.dx,
      event.localPosition.dy,
      size.width,
      size.height,
      leftHanded: widget.leftHanded,
    )) {
      return;
    }

    _pointer = event.pointer;
    widget.model.begin(event.localPosition.dx, event.localPosition.dy);
    _repaint.value++;
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    widget.model.drag(event.localPosition.dx, event.localPosition.dy);
    _repaint.value++;
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    // Releasing centres the stick, which means the player is stationary, which
    // means their Draw starts ramping on the very next tick.
    widget.model.end();
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          IgnorePointer(
            child: CustomPaint(
              painter: _JoystickPainter(
                model: widget.model,
                repaint: _repaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({required this.model, required Listenable repaint})
      : super(repaint: repaint);

  final JoystickModel model;

  @override
  void paint(Canvas canvas, Size size) {
    if (!model.isActive) return;

    final Offset origin = Offset(model.originX, model.originY);

    // Low contrast on purpose. The stick is a confirmation that the touch
    // landed, not a thing to look at — the player's eyes belong on the arena.
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Tokens.ink.withOpacity(0.22);
    canvas.drawCircle(origin, Juice.joystickFullDeflectionDp, ring);

    // The dead zone is drawn because it is a real gameplay boundary: inside it
    // the player is *stationary* and the Draw is ramping.
    ring.color = Tokens.ink.withOpacity(0.10);
    canvas.drawCircle(origin, Juice.joystickDeadZoneDp, ring);

    final Offset knob = origin +
        Offset(model.outputX, model.outputY) * Juice.joystickFullDeflectionDp;

    final Paint fill = Paint()
      ..color = Tokens.accent.withOpacity(0.34 + 0.4 * model.magnitude);
    canvas.drawCircle(knob, 16, fill);

    fill.color = Tokens.accent.withOpacity(0.9);
    canvas.drawCircle(knob, 5, fill);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) => false;
}
