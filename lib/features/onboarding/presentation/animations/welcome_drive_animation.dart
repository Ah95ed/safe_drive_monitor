import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';

/// Page 1: WelcomeDriveAnimation
/// Displays a calm car cruising along a road with a slow, reassuring eye blinking sequence.
class WelcomeDriveAnimation extends StatefulWidget {
  final bool isActive;

  const WelcomeDriveAnimation({
    super.key,
    required this.isActive,
  });

  @override
  State<WelcomeDriveAnimation> createState() => _WelcomeDriveAnimationState();
}

class _WelcomeDriveAnimationState extends State<WelcomeDriveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WelcomeDriveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (disableAnimations) {
      return SizedBox(
        height: 220,
        width: 320,
        child: CustomPaint(
          painter: _WelcomeDrivePainter(
            roadProgress: 0.0,
            eyeOpenRatio: 1.0,
            carBobbing: 0.0,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // Road moves continuously
          final roadProgress = t;

          // Eye blink sequence over 3.6 seconds:
          // 0.00 - 0.55: Open (1.0)
          // 0.55 - 0.65: Closing (1.0 -> 0.0)
          // 0.65 - 0.70: Closed (0.0)
          // 0.70 - 0.80: Opening (0.0 -> 1.0)
          // 0.80 - 1.00: Open (1.0)
          double eyeOpen;
          if (t < 0.55) {
            eyeOpen = 1.0;
          } else if (t < 0.65) {
            final p = (t - 0.55) / 0.10;
            eyeOpen = 1.0 - Curves.easeInOut.transform(p);
          } else if (t < 0.70) {
            eyeOpen = 0.0;
          } else if (t < 0.80) {
            final p = (t - 0.70) / 0.10;
            eyeOpen = Curves.easeInOut.transform(p);
          } else {
            eyeOpen = 1.0;
          }

          // Gentle vertical suspension bobbing of car
          final carBobbing = math.sin(t * math.pi * 4) * 1.5;

          return SizedBox(
            height: 220,
            width: 320,
            child: CustomPaint(
              painter: _WelcomeDrivePainter(
                roadProgress: roadProgress,
                eyeOpenRatio: eyeOpen,
                carBobbing: carBobbing,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeDrivePainter extends CustomPainter {
  final double roadProgress;
  final double eyeOpenRatio;
  final double carBobbing;

  _WelcomeDrivePainter({
    required this.roadProgress,
    required this.eyeOpenRatio,
    required this.carBobbing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Ambient Background Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primaryCyan.withValues(alpha: 0.12),
          AppColors.background.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.45), radius: w * 0.45));
    canvas.drawCircle(Offset(w / 2, h * 0.45), w * 0.45, glowPaint);

    // 2. Road surface
    final roadY = h * 0.78;
    final roadPaint = Paint()
      ..color = const Color(0xFF1B222D)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, roadY, w - 20, 24),
        const Radius.circular(12),
      ),
      roadPaint,
    );

    // Road dashed line markers (moving leftwards to give rightward movement illusion)
    final dashPaint = Paint()
      ..color = const Color(0xFF384353)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final dashSpacing = 28.0;
    final dashLength = 14.0;
    final offset = (roadProgress * dashSpacing) % dashSpacing;

    for (double x = 16 - offset; x < w - 20; x += dashSpacing) {
      if (x >= 14 && x + dashLength <= w - 14) {
        canvas.drawLine(Offset(x, roadY + 12), Offset(x + dashLength, roadY + 12), dashPaint);
      }
    }

    // 3. Stylized Minimal Car
    final carCenterX = w * 0.50;
    final carCenterY = roadY - 14 + carBobbing;

    _drawCar(canvas, Offset(carCenterX, carCenterY));

    // 4. Protective Watchful Eye Icon above Car
    final eyeCenter = Offset(w * 0.50, h * 0.28);
    _drawEye(canvas, eyeCenter, eyeOpenRatio);
  }

  void _drawCar(Canvas canvas, Offset center) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF2E3846)
      ..style = PaintingStyle.fill;

    final roofPaint = Paint()
      ..color = const Color(0xFF1E2632)
      ..style = PaintingStyle.fill;

    final headlightGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primaryCyan.withValues(alpha: 0.35),
          AppColors.primaryCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(center.dx + 48, center.dy + 3), radius: 24));

    // Headlight cone forward
    canvas.drawCircle(Offset(center.dx + 48, center.dy + 3), 24, headlightGlow);

    // Car Body Path
    final carPath = Path();
    carPath.moveTo(center.dx - 48, center.dy + 7); // Rear bumper
    carPath.lineTo(center.dx - 48, center.dy);
    carPath.quadraticBezierTo(center.dx - 42, center.dy - 6, center.dx - 32, center.dy - 6); // Trunk
    carPath.lineTo(center.dx - 22, center.dy - 6);
    carPath.quadraticBezierTo(center.dx - 12, center.dy - 20, center.dx + 6, center.dy - 20); // Roof
    carPath.lineTo(center.dx + 16, center.dy - 20);
    carPath.quadraticBezierTo(center.dx + 30, center.dy - 6, center.dx + 44, center.dy - 2); // Hood
    carPath.lineTo(center.dx + 48, center.dy + 2); // Front bumper
    carPath.quadraticBezierTo(center.dx + 50, center.dy + 7, center.dx + 46, center.dy + 7);
    carPath.close();

    canvas.drawPath(carPath, bodyPaint);

    // Cabin Window
    final windowPath = Path();
    windowPath.moveTo(center.dx - 18, center.dy - 6);
    windowPath.quadraticBezierTo(center.dx - 10, center.dy - 17, center.dx + 4, center.dy - 17);
    windowPath.lineTo(center.dx + 13, center.dy - 17);
    windowPath.quadraticBezierTo(center.dx + 23, center.dy - 6, center.dx + 28, center.dy - 6);
    windowPath.close();
    canvas.drawPath(windowPath, roofPaint);

    // Headlight beam dot
    final lightDotPaint = Paint()..color = AppColors.primaryCyan;
    canvas.drawCircle(Offset(center.dx + 47, center.dy + 2), 2.0, lightDotPaint);

    // Taillight soft red accent dot
    final tailLightPaint = Paint()..color = const Color(0xFFD34545).withValues(alpha: 0.85);
    canvas.drawCircle(Offset(center.dx - 47, center.dy + 2), 2.0, tailLightPaint);

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF141920);
    final rimPaint = Paint()
      ..color = const Color(0xFF4A5568)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(center.dx - 28, center.dy + 7), 6.5, wheelPaint);
    canvas.drawCircle(Offset(center.dx - 28, center.dy + 7), 4.0, rimPaint);

    canvas.drawCircle(Offset(center.dx + 28, center.dy + 7), 6.5, wheelPaint);
    canvas.drawCircle(Offset(center.dx + 28, center.dy + 7), 4.0, rimPaint);
  }

  void _drawEye(Canvas canvas, Offset center, double openRatio) {
    final eyeWidth = 52.0;
    final maxEyeHeight = 28.0;
    final currentHeight = maxEyeHeight * openRatio;

    // Outer Aura
    final auraPaint = Paint()
      ..color = AppColors.primaryCyan.withValues(alpha: 0.08 + (0.10 * openRatio))
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: eyeWidth + 24, height: maxEyeHeight + 24),
      auraPaint,
    );

    // Eye Outline
    final outlinePaint = Paint()
      ..color = AppColors.primaryCyan.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final eyePath = Path();
    if (currentHeight <= 1.5) {
      // Closed eye: gentle curved arc
      eyePath.moveTo(center.dx - eyeWidth / 2, center.dy);
      eyePath.quadraticBezierTo(center.dx, center.dy + 4, center.dx + eyeWidth / 2, center.dy);
      canvas.drawPath(eyePath, outlinePaint);
    } else {
      // Top lid
      eyePath.moveTo(center.dx - eyeWidth / 2, center.dy);
      eyePath.quadraticBezierTo(center.dx, center.dy - currentHeight, center.dx + eyeWidth / 2, center.dy);
      // Bottom lid
      eyePath.quadraticBezierTo(center.dx, center.dy + currentHeight, center.dx - eyeWidth / 2, center.dy);
      canvas.drawPath(eyePath, outlinePaint);

      // Pupil / Iris
      if (openRatio > 0.35) {
        final irisRadius = 8.0 * (openRatio).clamp(0.0, 1.0);
        final irisPaint = Paint()
          ..color = AppColors.primaryCyan
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, irisRadius, irisPaint);

        // Soft pupil center
        final pupilPaint = Paint()..color = const Color(0xFF0D1117);
        canvas.drawCircle(center, irisRadius * 0.5, pupilPaint);

        // Reassuring gleam
        final gleamPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(center.dx - irisRadius * 0.25, center.dy - irisRadius * 0.25), 1.5, gleamPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeDrivePainter oldDelegate) {
    return oldDelegate.roadProgress != roadProgress ||
        oldDelegate.eyeOpenRatio != eyeOpenRatio ||
        oldDelegate.carBobbing != carBobbing;
  }
}
