import 'package:flutter/material.dart';

class DotGridBackground extends StatelessWidget {
  final Widget? child;
  final Color dotColor;
  final double spacing;

  const DotGridBackground({
    super.key,
    this.child,
    this.dotColor = const Color(0xFFE0E0E0),
    this.spacing = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(color: dotColor, spacing: spacing),
      child: child,
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  _DotGridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const dotRadius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Offset rows slightly for a nicer look if desired, but image shows square grid
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
