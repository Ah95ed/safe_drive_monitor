import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';

/// Page 4: SafeRestAnimation
/// Displays a car cruising, smoothly decelerating, and stopping peacefully at a rest area under a crescent moon.
class SafeRestAnimation extends StatefulWidget {
  final bool isActive;

  const SafeRestAnimation({
    super.key,
    required this.isActive,
  });

  @override
  State<SafeRestAnimation> createState() => _SafeRestAnimationState();
}

class _SafeRestAnimationState extends State<SafeRestAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SafeRestAnimation oldWidget) {
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
          painter: _SafeRestPainter(
            carXRatio: 0.65,
            isStopped: true,
            moonGlowRatio: 1.0,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;

          // Animation timeline (3.8s):
          // 0.00 - 0.45: Car approaches from left (0.20 -> 0.65) with easeOutCubic deceleration
          // 0.45 - 0.90: Car is peacefully parked in the rest bay, moon glows warmly
          // 0.90 - 1.00: Soft hold / loop reset transition

          final double carXRatio;
          final bool isStopped;
          final double moonGlow;

          if (t < 0.45) {
            final progress = t / 0.45;
            final eased = Curves.easeOutCubic.transform(progress);
            carXRatio = 0.15 + (eased * 0.50); // Moves from 0.15 to 0.65
            isStopped = false;
            moonGlow = 0.50 + (eased * 0.50);
          } else {
            carXRatio = 0.65;
            isStopped = true;
            // Soft breathing pulse on the moon glow when resting
            final restTime = (t - 0.45) / 0.55;
            moonGlow = 0.85 + (math.sin(restTime * math.pi * 2) * 0.15);
          }

          return SizedBox(
            height: 220,
            width: 320,
            child: CustomPaint(
              painter: _SafeRestPainter(
                carXRatio: carXRatio,
                isStopped: isStopped,
                moonGlowRatio: moonGlow,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SafeRestPainter extends CustomPainter {
  final double carXRatio;
  final bool isStopped;
  final double moonGlowRatio;

  _SafeRestPainter({
    required this.carXRatio,
    required this.isStopped,
    required this.moonGlowRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Serene Night Sky Gradient
    final skyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1E2E42).withValues(alpha: 0.35 * moonGlowRatio),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.78, h * 0.28), radius: 80));
    canvas.drawCircle(Offset(w * 0.78, h * 0.28), 80, skyPaint);

    // 2. Crescent Moon & Peaceful Stars
    _drawMoonAndStars(canvas, Offset(w * 0.78, h * 0.28));

    // 3. Road & Rest Bay Parking
    final roadY = h * 0.78;
    _drawRoadAndBay(canvas, w, roadY);

    // 4. Rest Area Signpost (Blue 'P' or 'Rest' icon sign)
    _drawRestSign(canvas, Offset(w * 0.82, roadY - 48));

    // 5. Calm Car that parks in the bay
    final carX = w * carXRatio;
    final carY = roadY - 12;
    _drawCar(canvas, Offset(carX, carY));

    // 6. If stopped, show gentle "Zzz" or rest symbol
    if (isStopped) {
      _drawRestIndicator(canvas, Offset(carX, carY - 26));
    }
  }

  void _drawMoonAndStars(Canvas canvas, Offset center) {
    // Crescent Moon
    final moonPaint = Paint()
      ..color = const Color(0xFFF1C40F).withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;

    // Crescent created with difference or quadratic curve
    final moonPath = Path();
    moonPath.moveTo(center.dx, center.dy - 12);
    moonPath.quadraticBezierTo(center.dx + 12, center.dy, center.dx, center.dy + 12);
    moonPath.quadraticBezierTo(center.dx + 6, center.dy, center.dx, center.dy - 12);
    moonPath.close();
    canvas.drawPath(moonPath, moonPaint);

    // Subtle twinkling stars
    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75 * moonGlowRatio)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 48, center.dy - 10), 1.2, starPaint);
    canvas.drawCircle(Offset(center.dx - 24, center.dy + 14), 1.0, starPaint);
    canvas.drawCircle(Offset(center.dx + 26, center.dy - 14), 1.4, starPaint);
  }

  void _drawRoadAndBay(Canvas canvas, double w, double roadY) {
    // Main road
    final roadPaint = Paint()
      ..color = const Color(0xFF1B222D)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(10, roadY, w - 20, 24), const Radius.circular(12)),
      roadPaint,
    );

    // Parking Bay markings on the right
    final bayPaint = Paint()
      ..color = AppColors.primaryCyan.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final bayRect = Rect.fromLTWH(w * 0.52, roadY - 4, w * 0.32, 28);
    canvas.drawRRect(RRect.fromRectAndRadius(bayRect, const Radius.circular(6)), bayPaint);
  }

  void _drawRestSign(Canvas canvas, Offset center) {
    // Sign post
    final postPaint = Paint()
      ..color = const Color(0xFF4A5568)
      ..strokeWidth = 2.0;
    canvas.drawLine(center, Offset(center.dx, center.dy + 48), postPaint);

    // Sign Board (Square with rounded corners)
    final boardRect = Rect.fromCenter(center: center, width: 26, height: 26);
    final boardPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.fill;
    final boardBorder = Paint()
      ..color = AppColors.primaryCyan.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(RRect.fromRectAndRadius(boardRect, const Radius.circular(5)), boardPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(boardRect, const Radius.circular(5)), boardBorder);

    // 'P' letter on sign
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'P',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  void _drawCar(Canvas canvas, Offset center) {
    final bodyPaint = Paint()
      ..color = isStopped ? const Color(0xFF263342) : const Color(0xFF2E3846)
      ..style = PaintingStyle.fill;

    final roofPaint = Paint()
      ..color = const Color(0xFF1E2632)
      ..style = PaintingStyle.fill;

    // Car Body
    final carPath = Path();
    carPath.moveTo(center.dx - 36, center.dy + 5);
    carPath.lineTo(center.dx - 36, center.dy);
    carPath.quadraticBezierTo(center.dx - 30, center.dy - 5, center.dx - 22, center.dy - 5);
    carPath.lineTo(center.dx - 16, center.dy - 5);
    carPath.quadraticBezierTo(center.dx - 8, center.dy - 16, center.dx + 4, center.dy - 16);
    carPath.lineTo(center.dx + 12, center.dy - 16);
    carPath.quadraticBezierTo(center.dx + 22, center.dy - 5, center.dx + 32, center.dy - 2);
    carPath.lineTo(center.dx + 36, center.dy + 2);
    carPath.quadraticBezierTo(center.dx + 38, center.dy + 5, center.dx + 35, center.dy + 5);
    carPath.close();

    canvas.drawPath(carPath, bodyPaint);

    // Cabin Window
    final windowPath = Path();
    windowPath.moveTo(center.dx - 14, center.dy - 5);
    windowPath.quadraticBezierTo(center.dx - 7, center.dy - 13, center.dx + 3, center.dy - 13);
    windowPath.lineTo(center.dx + 10, center.dy - 13);
    windowPath.quadraticBezierTo(center.dx + 18, center.dy - 5, center.dx + 21, center.dy - 5);
    windowPath.close();
    canvas.drawPath(windowPath, roofPaint);

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF141920);
    final rimPaint = Paint()
      ..color = const Color(0xFF4A5568)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset(center.dx - 20, center.dy + 5), 5.0, wheelPaint);
    canvas.drawCircle(Offset(center.dx - 20, center.dy + 5), 3.0, rimPaint);

    canvas.drawCircle(Offset(center.dx + 20, center.dy + 5), 5.0, wheelPaint);
    canvas.drawCircle(Offset(center.dx + 20, center.dy + 5), 3.0, rimPaint);

    // Soft parking lights when stopped
    final lightColor = isStopped ? const Color(0xFFD29922) : AppColors.primaryCyan;
    final headDot = Paint()..color = lightColor.withValues(alpha: isStopped ? 0.65 : 0.90);
    canvas.drawCircle(Offset(center.dx + 35, center.dy + 2), 1.5, headDot);
  }

  void _drawRestIndicator(Canvas canvas, Offset center) {
    // Gentle rest "Zzz" icon floating above parked car
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Zzz',
        style: TextStyle(
          color: const Color(0xFFF1C40F).withValues(alpha: 0.85 * moonGlowRatio),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height),
    );
  }

  @override
  bool shouldRepaint(covariant _SafeRestPainter oldDelegate) {
    return oldDelegate.carXRatio != carXRatio ||
        oldDelegate.isStopped != isStopped ||
        oldDelegate.moonGlowRatio != moonGlowRatio;
  }
}
