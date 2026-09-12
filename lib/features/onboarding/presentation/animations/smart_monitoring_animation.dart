import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';

/// Page 2: SmartMonitoringAnimation
/// Displays a clean silhouette with face tracking frame, eye focal reticle, and "المراقبة تعمل ✓" badge.
class SmartMonitoringAnimation extends StatefulWidget {
  final bool isActive;

  const SmartMonitoringAnimation({
    super.key,
    required this.isActive,
  });

  @override
  State<SmartMonitoringAnimation> createState() =>
      _SmartMonitoringAnimationState();
}

class _SmartMonitoringAnimationState extends State<SmartMonitoringAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SmartMonitoringAnimation oldWidget) {
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
          painter: _SmartMonitoringPainter(
            faceAlpha: 1.0,
            eyeReticleScale: 1.0,
            badgeAlpha: 1.0,
            pulseOffset: 0.0,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;

          // Sequence breakdown (3.2s):
          // Phase 1 (0.00 - 0.25): Face frame fades in & scales gently
          // Phase 2 (0.25 - 0.60): Eye tracking reticle activates and locks in
          // Phase 3 (0.60 - 0.90): "المراقبة تعمل ✓" badge fades in
          // Phase 4 (0.90 - 1.00): Rest / subtle hold

          final double faceAlpha =
              (t < 0.25) ? Curves.easeOut.transform(t / 0.25) : 1.0;

          final double eyeScale;
          if (t < 0.25) {
            eyeScale = 0.0;
          } else if (t < 0.50) {
            eyeScale = Curves.easeOutBack.transform((t - 0.25) / 0.25);
          } else {
            eyeScale = 1.0;
          }

          final double badgeAlpha;
          if (t < 0.55) {
            badgeAlpha = 0.0;
          } else if (t < 0.80) {
            badgeAlpha = Curves.easeIn.transform((t - 0.55) / 0.25);
          } else {
            badgeAlpha = 1.0;
          }

          final pulseOffset = (t >= 0.50) ? (t - 0.50) / 0.50 : 0.0;

          return SizedBox(
            height: 220,
            width: 320,
            child: CustomPaint(
              painter: _SmartMonitoringPainter(
                faceAlpha: faceAlpha,
                eyeReticleScale: eyeScale.clamp(0.0, 1.1),
                badgeAlpha: badgeAlpha,
                pulseOffset: pulseOffset,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SmartMonitoringPainter extends CustomPainter {
  final double faceAlpha;
  final double eyeReticleScale;
  final double badgeAlpha;
  final double pulseOffset;

  _SmartMonitoringPainter({
    required this.faceAlpha,
    required this.eyeReticleScale,
    required this.badgeAlpha,
    required this.pulseOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.40);

    // 1. Soft Ambient Radial Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primaryCyan.withValues(alpha: 0.10 * faceAlpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 90));
    canvas.drawCircle(center, 90, glowPaint);

    // 2. Minimal Human Head Silhouette
    _drawSilhouette(canvas, center);

    // 3. Face Tracking Bounding Frame (Rounded corner brackets)
    _drawTrackingFrame(canvas, center);

    // 4. Eye Focus Reticle
    if (eyeReticleScale > 0.05) {
      _drawEyeReticle(canvas, center);
    }

    // 5. "المراقبة تعمل ✓" Status Pill Badge
    if (badgeAlpha > 0.05) {
      _drawStatusBadge(canvas, Offset(w / 2, h * 0.85));
    }
  }

  void _drawSilhouette(Canvas canvas, Offset center) {
    final fillPaint = Paint()
      ..color = const Color(0xFF1E2632).withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF303C4E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Head oval
    final headRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 12),
      width: 48,
      height: 60,
    );
    canvas.drawOval(headRect, fillPaint);
    canvas.drawOval(headRect, strokePaint);

    // Shoulders
    final shoulderPath = Path();
    shoulderPath.moveTo(center.dx - 46, center.dy + 42);
    shoulderPath.quadraticBezierTo(
      center.dx - 32,
      center.dy + 20,
      center.dx - 18,
      center.dy + 18,
    );
    shoulderPath.lineTo(center.dx + 18, center.dy + 18);
    shoulderPath.quadraticBezierTo(
      center.dx + 32,
      center.dy + 20,
      center.dx + 46,
      center.dy + 42,
    );
    shoulderPath.close();

    canvas.drawPath(shoulderPath, fillPaint);
    canvas.drawPath(shoulderPath, strokePaint);
  }

  void _drawTrackingFrame(Canvas canvas, Offset center) {
    final frameWidth = 104.0;
    final frameHeight = 118.0;
    final left = center.dx - frameWidth / 2;
    final top = center.dy - 46;
    final right = left + frameWidth;
    final bottom = top + frameHeight;
    final bracketLen = 14.0;
    final cornerRadius = 8.0;

    final framePaint = Paint()
      ..color = AppColors.primaryCyan.withValues(alpha: 0.75 * faceAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Top-Left corner
    final tl = Path()
      ..moveTo(left, top + bracketLen)
      ..lineTo(left, top + cornerRadius)
      ..quadraticBezierTo(left, top, left + cornerRadius, top)
      ..lineTo(left + bracketLen, top);
    canvas.drawPath(tl, framePaint);

    // Top-Right corner
    final tr = Path()
      ..moveTo(right - bracketLen, top)
      ..lineTo(right - cornerRadius, top)
      ..quadraticBezierTo(right, top, right, top + cornerRadius)
      ..lineTo(right, top + bracketLen);
    canvas.drawPath(tr, framePaint);

    // Bottom-Left corner
    final bl = Path()
      ..moveTo(left, bottom - bracketLen)
      ..lineTo(left, bottom - cornerRadius)
      ..quadraticBezierTo(left, bottom, left + cornerRadius, bottom)
      ..lineTo(left + bracketLen, bottom);
    canvas.drawPath(bl, framePaint);

    // Bottom-Right corner
    final br = Path()
      ..moveTo(right - bracketLen, bottom)
      ..lineTo(right - cornerRadius, bottom)
      ..quadraticBezierTo(right, bottom, right, bottom - cornerRadius)
      ..lineTo(right, bottom - bracketLen);
    canvas.drawPath(br, framePaint);
  }

  void _drawEyeReticle(Canvas canvas, Offset center) {
    final eyeY = center.dy - 14;
    final reticleWidth = 38.0 * eyeReticleScale;
    final reticleHeight = 16.0 * eyeReticleScale;
    final reticleRect = Rect.fromCenter(
      center: Offset(center.dx, eyeY),
      width: reticleWidth,
      height: reticleHeight,
    );

    final reticlePaint = Paint()
      ..color = const Color(0xFF38B2AC).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(reticleRect, const Radius.circular(6)),
      reticlePaint,
    );

    // Left and Right eye subtle focal dots
    final dotPaint = Paint()
      ..color = const Color(0xFF38B2AC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 10, eyeY), 2.0, dotPaint);
    canvas.drawCircle(Offset(center.dx + 10, eyeY), 2.0, dotPaint);
  }

  void _drawStatusBadge(Canvas canvas, Offset center) {
    final badgeWidth = 136.0;
    final badgeHeight = 30.0;
    final badgeRect = Rect.fromCenter(
      center: center,
      width: badgeWidth,
      height: badgeHeight,
    );

    // Background pill
    final bgPaint = Paint()
      ..color = const Color(0xFF11251E).withValues(alpha: 0.90 * badgeAlpha)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = AppColors.normalGreen.withValues(alpha: 0.70 * badgeAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(15)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(15)),
      borderPaint,
    );

    // Green Checkmark icon
    final checkPaint = Paint()
      ..color = AppColors.normalGreen.withValues(alpha: badgeAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path();
    checkPath.moveTo(center.dx - 48, center.dy);
    checkPath.lineTo(center.dx - 44, center.dy + 4);
    checkPath.lineTo(center.dx - 38, center.dy - 4);
    canvas.drawPath(checkPath, checkPaint);

    // "المراقبة تعمل" Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'المراقبة تعمل',
        style: TextStyle(
          color: AppColors.textPrimary.withValues(alpha: badgeAlpha),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - 30, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SmartMonitoringPainter oldDelegate) {
    return oldDelegate.faceAlpha != faceAlpha ||
        oldDelegate.eyeReticleScale != eyeReticleScale ||
        oldDelegate.badgeAlpha != badgeAlpha ||
        oldDelegate.pulseOffset != pulseOffset;
  }
}
