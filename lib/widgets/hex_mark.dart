import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The app's hex-mark brand icon: a hexagon outline with a download arrow
/// through the middle. Drawn on a 64x64 logical grid, scaled to [size].
class HexMark extends StatelessWidget {
  final double size;

  const HexMark({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HexMarkPainter()),
    );
  }
}

class _HexMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.save();
    canvas.scale(scale);

    final hexPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final leftHex = Path()
      ..moveTo(32, 6)
      ..lineTo(12, 18)
      ..lineTo(12, 46)
      ..lineTo(24, 53);
    canvas.drawPath(leftHex, hexPaint);

    final rightHex = Path()
      ..moveTo(32, 58)
      ..lineTo(52, 46)
      ..lineTo(52, 18)
      ..lineTo(40, 11);
    canvas.drawPath(rightHex, hexPaint);

    final arrowPaint = Paint()
      ..color = AppColors.accentBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arrowStem = Path()
      ..moveTo(32, 15)
      ..lineTo(32, 38);
    canvas.drawPath(arrowStem, arrowPaint);

    final arrowHead = Path()
      ..moveTo(21, 28)
      ..lineTo(32, 39)
      ..lineTo(43, 28);
    canvas.drawPath(arrowHead, arrowPaint);

    final basePaint = Paint()
      ..color = const Color(0xFF1FA0E4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(23, 48), const Offset(41, 48), basePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HexMarkPainter oldDelegate) => false;
}
