import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式枚举
enum ThemeMode {
  system,
  light,
  dark,
}

/// 颜色方案配置
class AppColorScheme {
  const AppColorScheme({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.background,
    required this.error,
    required this.onPrimary,
    required this.onSecondary,
    required this.onSurface,
    required this.onBackground,
    required this.onError,
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color primary;
  final Color secondary;
  final Color surface;
  final Color background;
  final Color error;
  final Color onPrimary;
  final Color onSecondary;
  final Color onSurface;
  final Color onBackground;
  final Color onError;
  final Color success;
  final Color warning;
  final Color info;

  /// 浅色主题
  static const AppColorScheme light = AppColorScheme(
    primary: Color(0xFF1976D2),
    secondary: Color(0xFF03DAC6),
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFF5F5F5),
    error: Color(0xFFD32F2F),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF000000),
    onSurface: Color(0xFF000000),
    onBackground: Color(0xFF000000),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFF9800),
    info: Color(0xFF2196F3),
  );

  /// 深色主题
  static const AppColorScheme dark = AppColorScheme(
    primary: Color(0xFF90CAF9),
    secondary: Color(0xFF03DAC6),
    surface: Color(0xFF121212),
    background: Color(0xFF000000),
    error: Color(0xFFCF6679),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    onBackground: Color(0xFFFFFFFF),
    onError: Color(0xFF000000),
    success: Color(0xFF66BB6A),
    warning: Color(0xFFFFB74D),
    info: Color(0xFF64B5F6),
  );
}

/// 文本主题配置
class AppTextTheme {
  const AppTextTheme({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;

  /// 浅色主题文本样式
  static AppTextTheme light = AppTextTheme(
    displayLarge: const TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    displayMedium: const TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    displaySmall: const TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    headlineLarge: const TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    headlineMedium: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    headlineSmall: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    titleLarge: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: Color(0xFF000000),
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFF000000),
    ),
    titleSmall: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF000000),
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    bodySmall: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF000000),
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFF000000),
    ),
    labelSmall: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Color(0xFF000000),
    ),
  );

  /// 深色主题文本样式
  static AppTextTheme dark = AppTextTheme(
    displayLarge: const TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    displayMedium: const TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    displaySmall: const TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    headlineLarge: const TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    headlineMedium: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    headlineSmall: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    titleLarge: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: Color(0xFFFFFFFF),
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFFFFFFFF),
    ),
    titleSmall: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFFFFFFFF),
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    bodySmall: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Color(0xFFFFFFFF),
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFFFFFFFF),
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFFFFFFFF),
    ),
    labelSmall: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Color(0xFFFFFFFF),
    ),
  );
}

/// 应用主题配置
class AppTheme {
  const AppTheme({
    required this.colorScheme,
    required this.textTheme,
    required this.brightness,
  });

  final AppColorScheme colorScheme;
  final AppTextTheme textTheme;
  final Brightness brightness;

  /// 浅色主题
  static const AppTheme light = AppTheme(
    colorScheme: AppColorScheme.light,
    textTheme: AppTextTheme.light,
    brightness: Brightness.light,
  );

  /// 深色主题
  static const AppTheme dark = AppTheme(
    colorScheme: AppColorScheme.dark,
    textTheme: AppTextTheme.dark,
    brightness: Brightness.dark,
  );

  /// 转换为Material主题
  ThemeData toMaterialTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colorScheme.primary,
        brightness: brightness,
        surface: colorScheme.surface,
        onSurface: colorScheme.onSurface,
        error: colorScheme.error,
        onError: colorScheme.onError,
      ),
      textTheme: TextTheme(
        displayLarge: textTheme.displayLarge,
        displayMedium: textTheme.displayMedium,
        displaySmall: textTheme.displaySmall,
        headlineLarge: textTheme.headlineLarge,
        headlineMedium: textTheme.headlineMedium,
        headlineSmall: textTheme.headlineSmall,
        titleLarge: textTheme.titleLarge,
        titleMedium: textTheme.titleMedium,
        titleSmall: textTheme.titleSmall,
        bodyLarge: textTheme.bodyLarge,
        bodyMedium: textTheme.bodyMedium,
        bodySmall: textTheme.bodySmall,
        labelLarge: textTheme.labelLarge,
        labelMedium: textTheme.labelMedium,
        labelSmall: textTheme.labelSmall,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 2,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark 
              ? Brightness.light 
              : Brightness.dark,
        ),
      ),
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primary.withOpacity(0.2),
        disabledColor: colorScheme.onSurface.withOpacity(0.12),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.primary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surface,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.onSurface.withOpacity(0.12),
        thickness: 1,
      ),
    );
  }
}

/// 主题管理器
class ThemeManager {
  ThemeManager._();
  static final ThemeManager _instance = ThemeManager._();
  factory ThemeManager() => _instance;

  ThemeMode _themeMode = ThemeMode.system;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// 初始化主题管理器
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    final String? savedTheme = _prefs?.getString('theme_mode');
    if (savedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (ThemeMode mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString('theme_mode', mode.name);
  }

  /// 获取当前应用主题
  AppTheme getCurrentTheme({Brightness? systemBrightness}) {
    switch (_themeMode) {
      case ThemeMode.light:
        return AppTheme.light;
      case ThemeMode.dark:
        return AppTheme.dark;
      case ThemeMode.system:
        if (systemBrightness == Brightness.dark) {
          return AppTheme.dark;
        }
        return AppTheme.light;
    }
  }

  /// 获取Material主题
  ThemeData getMaterialTheme({Brightness? systemBrightness}) {
    return getCurrentTheme(systemBrightness: systemBrightness).toMaterialTheme();
  }

  /// 切换到浅色模式
  Future<void> setLightMode() async {
    await setThemeMode(ThemeMode.light);
  }

  /// 切换到深色模式
  Future<void> setDarkMode() async {
    await setThemeMode(ThemeMode.dark);
  }

  /// 切换到系统模式
  Future<void> setSystemMode() async {
    await setThemeMode(ThemeMode.system);
  }

  /// 切换主题（在浅色和深色之间）
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setDarkMode();
        break;
      case ThemeMode.dark:
        await setLightMode();
        break;
      case ThemeMode.system:
        // 如果是系统模式，根据当前系统亮度切换到相反模式
        await setLightMode();
        break;
    }
  }
}

/// 全局主题管理器实例
final ThemeManager themeManager = ThemeManager();
