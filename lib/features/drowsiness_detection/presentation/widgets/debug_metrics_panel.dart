import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/app/theme/app_typography.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/roi_strategy.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';

class DebugMetricsPanel extends StatelessWidget {
  const DebugMetricsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DrowsinessDetectionProvider>(
      builder: (context, provider, child) {
        final prediction = provider.lastPrediction;
        final driverFace = provider.currentDriverFace;

        return ExpansionTile(
          collapsedBackgroundColor: AppColors.surface,
          backgroundColor: AppColors.surfaceElevated,
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.primaryCyan),
          ),
          leading: const Icon(Icons.bug_report, color: AppColors.primaryCyan),
          title: const Text(
            'لوحة فحص الموديل والأداء (Debug Panel)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            // Model Raw Scores
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Open Score [0]',
                    value: prediction?.openScore.toStringAsFixed(4) ?? '0.0000',
                    color: AppColors.normalGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Closed Score [1]',
                    value: prediction?.closedScore.toStringAsFixed(4) ?? '0.0000',
                    color: AppColors.alarmRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Timings & Performance
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Inference',
                    value: '${provider.inferenceTime.inMilliseconds} ms',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Face Det.',
                    value: '${provider.faceDetectionTime.inMilliseconds} ms',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Driver Face ID',
                    value: driverFace != null ? '#${driverFace.trackingId ?? 1}' : 'None',
                    color: driverFace != null ? AppColors.normalGreen : AppColors.watchingAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Preprocessing',
                    value: '${provider.preprocessingTime.inMilliseconds} ms',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'FPS / Dropped',
                    value:
                        '${provider.processedFps.toStringAsFixed(1)} / ${provider.droppedFramesCount}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'PERCLOS (60s)',
                    value: '${provider.perclosPercentage.toStringAsFixed(1)}%',
                    color: provider.perclosPercentage >= 25.0
                        ? AppColors.alarmRed
                        : provider.perclosPercentage >= 15.0
                            ? AppColors.watchingAmber
                            : AppColors.normalGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Head Pitch',
                    value: '${driverFace?.headEulerAngleX?.toStringAsFixed(1) ?? '0.0'}°',
                    color: provider.isHeadNodDetected ? AppColors.alarmRed : AppColors.primaryCyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Adaptive Interval',
                    value: '${provider.inferenceInterval.inMilliseconds} ms',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Side-by-side Decision Comparison
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Legacy Java (2 frames):',
                          style: AppTypography.metricLabel),
                      Text(
                        provider.isLegacyAlarmTriggered
                            ? '🚨 ALARM (Active)'
                            : 'Normal (Safe)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: provider.isLegacyAlarmTriggered
                              ? AppColors.alarmRed
                              : AppColors.normalGreen,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Flutter State Machine:',
                          style: AppTypography.metricLabel),
                      Text(
                        provider.alertState.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: provider.alertState.isAlarm
                              ? AppColors.alarmRed
                              : AppColors.primaryCyan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ROI Strategy Switching
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ROI Strategy:',
                  style: AppTypography.metricLabel,
                ),
                DropdownButton<RoiStrategy>(
                  value: provider.roiStrategy,
                  dropdownColor: AppColors.surfaceElevated,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: RoiStrategy.eyeBand,
                      child: Text('Eye Band (ML Kit Landmarks)'),
                    ),
                    DropdownMenuItem(
                      value: RoiStrategy.fullFace,
                      child: Text('Full Face Crop'),
                    ),
                    DropdownMenuItem(
                      value: RoiStrategy.legacyCenterCrop,
                      child: Text('Legacy Center Crop (Fallback)'),
                    ),
                  ],
                  onChanged: (strategy) {
                    if (strategy != null) {
                      provider.setRoiStrategy(strategy);
                    }
                  },
                ),
              ],
            ),

            // Tensor Layout Switching
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tensor Layout:',
                  style: AppTypography.metricLabel,
                ),
                DropdownButton<TensorChannelLayout>(
                  value: provider.tensorLayout,
                  dropdownColor: AppColors.surfaceElevated,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: TensorChannelLayout.interleavedRgb,
                      child: Text('Interleaved RGB (Modern)'),
                    ),
                    DropdownMenuItem(
                      value: TensorChannelLayout.planarRgb,
                      child: Text('Planar RGB (Java Parity)'),
                    ),
                  ],
                  onChanged: (layout) {
                    if (layout != null) {
                      provider.setTensorLayout(layout);
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MetricTile({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.metricLabel),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.metricValue.copyWith(
              color: color ?? AppColors.primaryCyan,
            ),
          ),
        ],
      ),
    );
  }
}
