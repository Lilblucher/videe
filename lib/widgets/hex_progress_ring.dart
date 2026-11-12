import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Hexagonal download-progress ring: hex outline `M32 4 L54 17 L54 47 L32 60
/// L10 47 L10 17 Z` on a 64x64 grid, with a track stroke and an accent
/// progress stroke whose length is driven by [progress] (0-1), plus a
/// glow matching the one accent-glow exception in the design spec.
class HexProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final Widget? center;
  final Color trackColor;
  final Color progressColor;
  final bool glow;

  const HexProgressRing({
    super.key,
    required this.progress,
    this.size = 104,
    this.center,
    this.trackColor = AppColors.hairline,
    this.progressColor = AppColors.accent,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _HexRingPainter(
              progress: progress.clamp(0, 1),
              trackColor: trackColor,
              progressColor: progressColor,
              glow: glow,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _HexRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final bool glow;

  _HexRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.glow,
  });

  Path _hexPath() {
    return Path()
      ..moveTo(32, 4)
      ..lineTo(54, 17)
      ..lineTo(54, 47)
      ..lineTo(32, 60)
      ..lineTo(10, 47)
      ..lineTo(10, 17)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.save();
    canvas.scale(scale);

    final path = _hexPath();

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, trackPaint);

    if (progress > 0) {
      final metrics = path.computeMetrics().first;
      final extracted = metrics.extractPath(0, metrics.length * progress);

      if (glow) {
        final glowPaint = Paint()
          ..color = progressColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawPath(extracted, glowPaint);
      }

      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(extracted, progressPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HexRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.trackColor != trackColor;
}
