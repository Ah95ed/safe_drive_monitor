import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';

/// Immersive High-Contrast Driving HUD (Head-Up Display) Mode.
/// Optimized for night driving, car mounts, and windshield reflection projection.
class DrivingHudScreen extends StatefulWidget {
  const DrivingHudScreen({super.key});

  @override
  State<DrivingHudScreen> createState() => _DrivingHudScreenState();
}

class _DrivingHudScreenState extends State<DrivingHudScreen> {
  bool _isWindshieldMirrored = false;
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Consumer<DrowsinessDetectionProvider>(
      builder: (context, provider, _) {
        final alertState = provider.alertState;
        final perclos = provider.perclosPercentage;
        final prediction = provider.lastPrediction;

        Color hudColor;
        String statusText;
        IconData statusIcon;

        switch (alertState) {
          case DriverAlertState.alarm:
            hudColor = AppColors.alarmRed;
            statusText = loc.translate('hud_alarm');
            statusIcon = Icons.warning_rounded;
            break;
          case DriverAlertState.recovering:
            hudColor = AppColors.watchingAmber;
            statusText = loc.translate('hud_recovering');
            statusIcon = Icons.visibility_rounded;
            break;
          case DriverAlertState.drowsy:
            hudColor = AppColors.drowsyOrange;
            statusText = loc.translate('hud_drowsy');
            statusIcon = Icons.error_outline_rounded;
            break;
          case DriverAlertState.watching:
            hudColor = AppColors.watchingAmber;
            statusText = loc.translate('hud_watching');
            statusIcon = Icons.remove_red_eye_rounded;
            break;
          case DriverAlertState.normal:
            hudColor = AppColors.normalGreen;
            statusText = loc.translate('hud_driver_awake');
            statusIcon = Icons.check_circle_outline_rounded;
            break;
        }

        Widget content = Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top HUD Bar: Clock & Windshield Mode Toggle & Exit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.white70, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: loc.translate('hud_exit_tooltip'),
                      ),
                      Text(
                        _formatTime(_currentTime),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isWindshieldMirrored ? Icons.flip_to_back : Icons.flip_to_front,
                          color: _isWindshieldMirrored ? AppColors.primaryCyan : Colors.white70,
                          size: 28,
                        ),
                        onPressed: () {
                          setState(() {
                            _isWindshieldMirrored = !_isWindshieldMirrored;
                          });
                        },
                        tooltip: loc.translate('hud_mirror_tooltip'),
                      ),
                    ],
                  ),

                  // Center Alert HUD Indicator
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hudColor.withValues(alpha: 0.15),
                              border: Border.all(color: hudColor, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: hudColor.withValues(alpha: 0.5),
                                  blurRadius: alertState.isAlarm ? 40 : 20,
                                  spreadRadius: alertState.isAlarm ? 10 : 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              statusIcon,
                              size: 70,
                              color: hudColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            statusText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: hudColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (prediction != null)
                            Text(
                              prediction.state == EyeState.closed
                                  ? loc.translate('hud_eye_closed')
                                  : loc.translate('hud_eye_open'),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white60,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom HUD Bar: PERCLOS Gauge & Driver Face Status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              loc.translate('hud_perclos_label'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              '${perclos.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: hudColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (perclos / 100.0).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(hudColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (_isWindshieldMirrored) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159), // Mirror horizontally for windshield projection
            child: content,
          );
        }

        return content;
      },
    );
  }
}
