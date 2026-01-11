import 'package:flutter/material.dart';

class AppStyles {
  // Morandi Palette
  static const Color mBackground = Color(0xFFE5E2DA); // Pale Sand
  static const Color mSurface = Color(0xFFF2F0E9); // Lighter Sand
  static const Color mPrimary = Color(0xFF7A8D9A); // Deep Muted Blue
  static const Color mSecondary = Color(0xFFACB8A8); // Sage Green
  static const Color mAccent = Color(0xFFD6BDBC); // Dusty Rose
  static const Color mTextPrimary = Color(0xFF5A6268); // Dark Grey Muted
  static const Color mTextSecondary = Color(0xFF8E979F); // Muted Slate
  static const Color mSidebarBg = Color(0xFF4A555C); // Deep Muted Slate

  // Corner Radii
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 20.0;
  static const double radiusLarge = 32.0;

  static BorderRadius get bRadiusSmall => BorderRadius.circular(radiusSmall);
  static BorderRadius get bRadiusMedium => BorderRadius.circular(radiusMedium);
  static BorderRadius get bRadiusLarge => BorderRadius.circular(radiusLarge);
}

class GridDotPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;

  GridDotPainter({
    this.dotColor = const Color(0xFFBDC3C7),
    this.spacing = 30.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
