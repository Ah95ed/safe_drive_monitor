import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';

/// Page 3: PrivacyProtectionAnimation
/// Displays a smartphone with on-device camera -> AI processing chip -> protective shield & gentle lock.
class PrivacyProtectionAnimation extends StatefulWidget {
  final bool isActive;

  const PrivacyProtectionAnimation({
    super.key,
    required this.isActive,
  });

  @override
  State<PrivacyProtectionAnimation> createState() =>
      _PrivacyProtectionAnimationState();
}

class _PrivacyProtectionAnimationState
    extends State<PrivacyProtectionAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PrivacyProtectionAnimation oldWidget) {
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
          painter: _PrivacyProtectionPainter(
            stageProgress: 1.0,
            pulseWave: 0.0,
            lockShackleClose: 1.0,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;

          // Animation sequence over 3.4s:
          // 0.00 - 0.30: Camera active glow inside phone
          // 0.30 - 0.65: Data stream passes downward to AI NPU chip
          // 0.65 - 1.00: Protective shield blooms and lock shackle gently closes securely
          final stage = t;
          final pulseWave = (math.sin(t * math.pi * 2) + 1.0) / 2.0;

          double lockClose = 0.0;
          if (t >= 0.70) {
            lockClose = Curves.easeOutBack.transform(((t - 0.70) / 0.20).clamp(0.0, 1.0));
          }

          return SizedBox(
            height: 220,
            width: 320,
            child: CustomPaint(
              painter: _PrivacyProtectionPainter(
                stageProgress: stage,
                pulseWave: pulseWave,
                lockShackleClose: lockClose,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PrivacyProtectionPainter extends CustomPainter {
  final double stageProgress;
  final double pulseWave;
  final double lockShackleClose;

  _PrivacyProtectionPainter({
    required this.stageProgress,
    required this.pulseWave,
    required this.lockShackleClose,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.46);

    // 1. Reassuring Soft Teal/Cyan Background Aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1ABC9C).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 95));
    canvas.drawCircle(center, 95, auraPaint);

    // 2. Vector Smartphone Outline
    _drawPhone(canvas, center);

    // 3. Elements inside phone screen:
    // Top: Camera icon
    _drawCameraIcon(canvas, Offset(center.dx, center.dy - 44));

    // Middle: Flow pulses & AI Chip
    _drawFlowAndChip(canvas, center);

    // 4. Protective Shield with Gently Closing Padlock
    _drawShieldAndLock(canvas, Offset(center.dx, center.dy + 38));
  }

  void _drawPhone(Canvas canvas, Offset center) {
    final phoneWidth = 110.0;
    final phoneHeight = 170.0;
    final phoneRect = Rect.fromCenter(
      center: center,
      width: phoneWidth,
      height: phoneHeight,
    );

    // Phone body
    final bodyPaint = Paint()
      ..color = const Color(0xFF161B22)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF30363D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(phoneRect, const Radius.circular(20)),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(phoneRect, const Radius.circular(20)),
      borderPaint,
    );

    // Screen inner bezel
    final screenRect = Rect.fromCenter(
      center: center,
      width: phoneWidth - 14,
      height: phoneHeight - 20,
    );
    final screenPaint = Paint()
      ..color = const Color(0xFF0D1117)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(14)),
      screenPaint,
    );

    // Speaker pill at top
    final speakerPaint = Paint()..color = const Color(0xFF21262D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 78), width: 22, height: 3),
        const Radius.circular(2),
      ),
      speakerPaint,
    );
  }

  void _drawCameraIcon(Canvas canvas, Offset center) {
    final isCameraActive = stageProgress < 0.40 || stageProgress > 0.85;
    final camColor = isCameraActive ? AppColors.primaryCyan : const Color(0xFF8B949E);

    final lensPaint = Paint()
      ..color = camColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // Camera body
    final camRect = Rect.fromCenter(center: center, width: 24, height: 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(camRect, const Radius.circular(4)),
      lensPaint,
    );

    // Lens circle
    canvas.drawCircle(center, 4.5, lensPaint);

    // Subtle aperture center
    final fillPaint = Paint()
      ..color = camColor.withValues(alpha: isCameraActive ? 0.35 : 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.5, fillPaint);
  }

  void _drawFlowAndChip(Canvas canvas, Offset center) {
    final chipCenter = Offset(center.dx, center.dy - 3);

    // Vertical dashed connection line
    final linePaint = Paint()
      ..color = const Color(0xFF30363D)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(center.dx, center.dy - 32), Offset(center.dx, center.dy - 16), linePaint);
    canvas.drawLine(Offset(center.dx, center.dy + 10), Offset(center.dx, center.dy + 24), linePaint);

    // Downward moving data particle
    if (stageProgress > 0.25 && stageProgress < 0.70) {
      final pProgress = (stageProgress - 0.25) / 0.45;
      final particleY = (center.dy - 32) + (pProgress * 56);
      final particlePaint = Paint()
        ..color = const Color(0xFF38B2AC)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(center.dx, particleY), 2.2, particlePaint);
    }

    // AI Chip Box
    final chipSize = 22.0;
    final chipRect = Rect.fromCenter(center: chipCenter, width: chipSize, height: chipSize);
    final chipPaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.fill;
    final chipBorder = Paint()
      ..color = const Color(0xFF38B2AC).withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRRect(RRect.fromRectAndRadius(chipRect, const Radius.circular(4)), chipPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(chipRect, const Radius.circular(4)), chipBorder);

    // "AI" text inside chip
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'AI',
        style: TextStyle(
          color: Color(0xFF38B2AC),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(chipCenter.dx - textPainter.width / 2, chipCenter.dy - textPainter.height / 2),
    );
  }

  void _drawShieldAndLock(Canvas canvas, Offset center) {
    // Shield
    final shieldPath = Path();
    shieldPath.moveTo(center.dx, center.dy - 18);
    shieldPath.quadraticBezierTo(center.dx + 18, center.dy - 16, center.dx + 18, center.dy - 2);
    shieldPath.quadraticBezierTo(center.dx + 18, center.dy + 14, center.dx, center.dy + 22);
    shieldPath.quadraticBezierTo(center.dx - 18, center.dy + 14, center.dx - 18, center.dy - 2);
    shieldPath.quadraticBezierTo(center.dx - 18, center.dy - 16, center.dx, center.dy - 18);
    shieldPath.close();

    final shieldFill = Paint()
      ..color = const Color(0xFF132E27).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final shieldStroke = Paint()
      ..color = const Color(0xFF2EA043).withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawPath(shieldPath, shieldFill);
    canvas.drawPath(shieldPath, shieldStroke);

    // Padlock in center of shield
    final lockBodyRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 3),
      width: 13,
      height: 10,
    );
    final lockPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(lockBodyRect, const Radius.circular(2)), lockPaint);

    // Padlock Shackle: Animates from open to closed
    final shacklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final shackleYOffset = (1.0 - lockShackleClose) * 2.5;
    final shacklePath = Path();
    shacklePath.moveTo(center.dx - 3.5, center.dy - 2 - shackleYOffset);
    shacklePath.quadraticBezierTo(
      center.dx,
      center.dy - 8 - shackleYOffset,
      center.dx + 3.5,
      center.dy - 2 - (shackleYOffset * 0.2),
    );
    canvas.drawPath(shacklePath, shacklePaint);
  }

  @override
  bool shouldRepaint(covariant _PrivacyProtectionPainter oldDelegate) {
    return oldDelegate.stageProgress != stageProgress ||
        oldDelegate.pulseWave != pulseWave ||
        oldDelegate.lockShackleClose != lockShackleClose;
  }
}
