import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Theme data for dark Warm Slate palette
class DarkMorandiTheme {
  static const Color background = Color(0xFF2a3240); // Warm dark slate
  static const Color surface = Color(0xFF313B4A); // Slightly lighter slate
  static const Color primary = Color(
    0xFF6b90b5,
  ); // Brighter blue for visibility
  static const Color secondary = Color(
    0xFF6b90b5,
  ); // Same accent for consistency
  static const Color accent = Color(0xFF6b90b5); // Brighter blue accent
  static const Color textPrimary = Color(0xFFe8e6e3); // Warm off-white
  static const Color textSecondary = Color(0xFFa8a6a3); // Muted warm grey
  static const Color sidebarBg = Color(0xFF1e2530); // Deep warm charcoal
  static const Color userMessageBg = Color(0xFF5a7a9a); // Muted blue
  static const Color aiMessageBg = Color(0xFF3a4555); // Warm medium-dark grey
}

/// Theme data for light Warm Slate palette
class LightMorandiTheme {
  static const Color background = Color(0xFFf8f7f5); // Warm off-white
  static const Color surface = Color(0xFFFFFFFF); // White surface
  static const Color primary = Color(0xFF5b7c99); // Accent color
  static const Color secondary = Color(0xFF5b7c99); // Same accent
  static const Color accent = Color(0xFF5b7c99); // Accent color
  static const Color textPrimary = Color(0xFF3d4855); // Warmer dark slate
  static const Color textSecondary = Color(0xFF7a8a9a); // Muted slate
  static const Color sidebarBg = Color(0xFF3d4855); // Warmer dark slate
  static const Color userMessageBg = Color(0xFF6b8cae); // Softer warmer blue
  static const Color aiMessageBg = Color(0xFFe8e6e3); // Warm light grey
}

/// App-wide styles that respond to theme changes
class AppStyles {
  static bool _isDarkMode = false;

  /// Set the current theme mode
  static void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
  }

  /// Check current theme mode
  static bool get isDarkMode => _isDarkMode;

  // Dynamic Morandi Palette colors
  static Color get mBackground =>
      _isDarkMode ? DarkMorandiTheme.background : LightMorandiTheme.background;

  static Color get mSurface =>
      _isDarkMode ? DarkMorandiTheme.surface : LightMorandiTheme.surface;

  static Color get mPrimary =>
      _isDarkMode ? DarkMorandiTheme.primary : LightMorandiTheme.primary;

  static Color get mSecondary =>
      _isDarkMode ? DarkMorandiTheme.secondary : LightMorandiTheme.secondary;

  static Color get mAccent =>
      _isDarkMode ? DarkMorandiTheme.accent : LightMorandiTheme.accent;

  static Color get mTextPrimary => _isDarkMode
      ? DarkMorandiTheme.textPrimary
      : LightMorandiTheme.textPrimary;

  static Color get mTextSecondary => _isDarkMode
      ? DarkMorandiTheme.textSecondary
      : LightMorandiTheme.textSecondary;

  static Color get mSidebarBg =>
      _isDarkMode ? DarkMorandiTheme.sidebarBg : LightMorandiTheme.sidebarBg;

  static Color get mUserMessageBg => _isDarkMode
      ? DarkMorandiTheme.userMessageBg
      : LightMorandiTheme.userMessageBg;

  static Color get mAiMessageBg => _isDarkMode
      ? DarkMorandiTheme.aiMessageBg
      : LightMorandiTheme.aiMessageBg;

  // Priority Colors (same for both themes)
  static const Color priorityHigh = Color(0xFFFF6B6B); // Bright Coral
  static const Color priorityMedium = Color(0xFFFFA94D); // Bright Orange
  static Color get priorityLow => _isDarkMode
      ? const Color(0xFF6B7580) // Darker muted gray for dark theme
      : const Color(0xFFC5CCD3); // Muted Gray for light theme

  /// Returns background color based on priority level
  /// Priority 1 = High (brightest), 2 = Medium, 3+ = Low (muted)
  static Color getPriorityColor(dynamic priority) {
    final int p = priority is int
        ? priority
        : int.tryParse(priority?.toString() ?? '3') ?? 3;
    switch (p) {
      case 1:
        return priorityHigh;
      case 2:
        return priorityMedium;
      default:
        return priorityLow;
    }
  }

  // Corner Radii
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 20.0;
  static const double radiusLarge = 32.0;

  static BorderRadius get bRadiusSmall => BorderRadius.circular(radiusSmall);
  static BorderRadius get bRadiusMedium => BorderRadius.circular(radiusMedium);
  static BorderRadius get bRadiusLarge => BorderRadius.circular(radiusLarge);

  /// Get Flutter ThemeData for MaterialApp
  static ThemeData getThemeData() {
    return ThemeData(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: mBackground,
      primaryColor: mPrimary,
      colorScheme: ColorScheme(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primary: mPrimary,
        onPrimary: _isDarkMode ? Colors.black : Colors.white,
        secondary: mSecondary,
        onSecondary: _isDarkMode ? Colors.black : Colors.white,
        error: priorityHigh,
        onError: Colors.white,
        surface: mSurface,
        onSurface: mTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: mSurface,
        foregroundColor: mTextPrimary,
        elevation: 0,
      ),
      cardColor: mSurface,
      dialogBackgroundColor: mSurface,
      dividerColor: mBackground,
    );
  }
}

class ProjectIcons {
  static final Map<String, IconData> _iconMap = {
    'folder': LucideIcons.folder,
    'briefcase': LucideIcons.briefcase,
    'home': LucideIcons.home,
    'shopping_cart': LucideIcons.shoppingCart,
    'user': LucideIcons.user,
    'users': LucideIcons.users,
    'book': LucideIcons.book,
    'code': LucideIcons.code,
    'database': LucideIcons.database,
    'heart': LucideIcons.heart,
    'star': LucideIcons.star,
    'music': LucideIcons.music,
    'video': LucideIcons.video,
    'camera': LucideIcons.camera,
    'map': LucideIcons.map,
    'plane': LucideIcons.plane,
    'coffee': LucideIcons.coffee,
    'pizza': LucideIcons.pizza,
    'zap': LucideIcons.zap,
    'target': LucideIcons.target,
    'flag': LucideIcons.flag,
    'bookmark': LucideIcons.bookmark,
    'calendar': LucideIcons.calendar,
  };

  static List<String> get availableIcons => _iconMap.keys.toList();

  static IconData getIcon(String? name) {
    if (name == null) return LucideIcons.folder;
    return _iconMap[name] ?? LucideIcons.folder;
  }
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
