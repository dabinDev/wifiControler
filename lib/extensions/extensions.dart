import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BuildContext扩展方法
extension ContextExtensions on BuildContext {
  /// 获取主题
  ThemeData get theme => Theme.of(this);
  
  /// 获取文本主题
  TextTheme get textTheme => Theme.of(this).textTheme;
  
  /// 获取颜色方案
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  
  /// 获取媒体查询数据
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  
  /// 获取屏幕尺寸
  Size get screenSize => MediaQuery.of(this).size;
  
  /// 获取屏幕宽度
  double get screenWidth => MediaQuery.of(this).size.width;
  
  /// 获取屏幕高度
  double get screenHeight => MediaQuery.of(this).size.height;
  
  /// 获取设备像素比
  double get pixelRatio => MediaQuery.of(this).devicePixelRatio;
  
  /// 判断是否为横屏
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
  
  /// 判断是否为竖屏
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;
  
  /// 判断是否为平板
  bool get isTablet => MediaQuery.of(this).size.shortestSide >= 600;
  
  /// 判断是否为手机
  bool get isPhone => MediaQuery.of(this).size.shortestSide < 600;
  
  /// 获取状态栏高度
  double get statusBarHeight => MediaQuery.of(this).padding.top;
  
  /// 获取底部安全区域高度
  double get bottomSafeHeight => MediaQuery.of(this).padding.bottom;
  
  /// 获取键盘高度
  double get keyboardHeight => MediaQuery.of(this).viewInsets.bottom;
  
  /// 判断键盘是否显示
  bool get isKeyboardVisible => MediaQuery.of(this).viewInsets.bottom > 0;
  
  /// 获取安全区域
  EdgeInsets get safePadding => MediaQuery.of(this).padding;
  
  /// 显示SnackBar
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    String message, {
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    return ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor ?? colorScheme.onSurface),
        ),
        backgroundColor: backgroundColor ?? colorScheme.surface,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// 隐藏当前SnackBar
  void hideSnackBar() {
    ScaffoldMessenger.of(this).hideCurrentSnackBar();
  }
  
  /// 显示底部弹窗
  Future<T?> showModalBottomSheet<T>({
    required WidgetBuilder builder,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    bool isDismissible = true,
    bool enableDrag = true,
    RouteSettings? routeSettings,
    AnimationController? transitionAnimationController,
  }) {
    return showModalBottomSheet<T>(
      context: this,
      builder: builder,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape ?? const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: clipBehavior,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      routeSettings: routeSettings,
      transitionAnimationController: transitionAnimationController,
    );
  }
  
  /// 显示对话框
  Future<T?> showDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
  }) {
    return showDialog<T>(
      context: this,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    );
  }
  
  /// 显示确认对话框
  Future<bool> showConfirmDialog({
    String title = '确认',
    String content = '确定要执行此操作吗？',
    String confirmText = '确定',
    String cancelText = '取消',
  }) async {
    final bool? result = await showDialog<bool>(
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  
  /// 显示加载对话框
  void showLoadingDialog({String message = '加载中...'}) {
    showDialog(
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        content: Row(
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
  
  /// 隐藏加载对话框
  void hideLoadingDialog() {
    Navigator.of(this).pop();
  }
  
  /// 导航到新页面
  Future<T?> push<T>(Route<T> route) {
    return Navigator.of(this).push(route);
  }
  
  /// 导航到命名路由
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) {
    return Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
  }
  
  /// 替换当前页面
  Future<T?> pushReplacement<T, TO>(Route<T> route, {TO? result}) {
    return Navigator.of(this).pushReplacement<T, TO>(route, result: result);
  }
  
  /// 替换为命名路由
  Future<T?> pushReplacementNamed<T, TO>(String routeName, {TO? result, Object? arguments}) {
    return Navigator.of(this).pushReplacementNamed<T, TO>(routeName, result: result, arguments: arguments);
  }
  
  /// 返回上一页
  void pop<T>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }
  
  /// 返回到指定页面
  void popUntil(RoutePredicate predicate) {
    Navigator.of(this).popUntil(predicate);
  }
}

/// String扩展方法
extension StringExtensions on String {
  /// 是否为空或null
  bool get isNullOrEmpty => isEmpty;
  
  /// 是否不为空
  bool get isNotNullOrEmpty => isNotEmpty;
  
  /// 首字母大写
  String get capitalize {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
  
  /// 首字母小写
  String get uncapitalize {
    if (isEmpty) return this;
    return this[0].toLowerCase() + substring(1);
  }
  
  /// 截取字符串
  String truncate(int length, {String suffix = '...'}) {
    if (this.length <= length) return this;
    return substring(0, length - suffix.length) + suffix;
  }
  
  /// 移除所有空格
  String get removeAllSpaces => replaceAll(' ', '');
  
  /// 移除多余空格
  String get removeExtraSpaces => replaceAll(RegExp(r'\\s+'), ' ').trim();
  
  /// 是否为邮箱
  bool get isEmail => RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$').hasMatch(this);
  
  /// 是否为手机号（中国）
  bool get isPhoneNumber => RegExp(r'^1[3-9]\\d{9}$').hasMatch(this);
  
  /// 是否为IP地址
  bool get isIpAddress => RegExp(r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$').hasMatch(this);
  
  /// 是否为URL
  bool get isUrl => RegExp(r'^https?://(?:[-\\w.])+(?:[:\\d]+)?(?:/(?:[\\w/_.])*(?:\\?(?:[\\w&=%.])*)?(?:#(?:\\w*))?)?$').hasMatch(this);
  
  /// 是否为数字
  bool get isNumeric => RegExp(r'^\\d+$').hasMatch(this);
  
  /// 转换为整数
  int? toInt() => int.tryParse(this);
  
  /// 转换为双精度浮点数
  double? toDouble() => double.tryParse(this);
  
  /// 转换为布尔值
  bool toBool() {
    return toLowerCase() == 'true';
  }
  
  /// 反转字符串
  String get reverse => split('').reversed.join('');
  
  /// 计算单词数量
  int get wordCount => trim().split(RegExp(r'\\s+')).length;
  
  /// 计算字符数量（不包含空格）
  int get charCountWithoutSpaces => replaceAll(' ', '').length;
}

/// int扩展方法
extension IntExtensions on int {
  /// 是否在指定范围内
  bool isBetween(int min, int max) => this >= min && this <= max;
  
  /// 转换为文件大小字符串
  String get toFileSize {
    if (this < 1024) return '${this}B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)}KB';
    if (this < 1024 * 1024 * 1024) return '${(this / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
  
  /// 转换为时长字符串
  String get toDuration {
    final int hours = this ~/ 3600;
    final int minutes = (this % 3600) ~/ 60;
    final int seconds = this % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
  
  /// 转换为百分比字符串
  String toPercentage({int decimalDigits = 1}) {
    return '${(this * 100).toStringAsFixed(decimalDigits)}%';
  }
  
  /// 转换为罗马数字
  String get toRomanNumeral {
    if (this <= 0 || this > 3999) return this.toString();
    
    final List<int> values = <int>[1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    final List<String> symbols = <String>['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    
    int num = this;
    String result = '';
    
    for (int i = 0; i < values.length; i++) {
      while (num >= values[i]) {
        result += symbols[i];
        num -= values[i];
      }
    }
    
    return result;
  }
}

/// double扩展方法
extension DoubleExtensions on double {
  /// 是否在指定范围内
  bool isBetween(double min, double max) => this >= min && this <= max;
  
  /// 限制在指定范围内
  double clamp(double min, double max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
  
  /// 转换为百分比字符串
  String toPercentage({int decimalDigits = 1}) {
    return '${(this * 100).toStringAsFixed(decimalDigits)}%';
  }
  
  /// 保留指定小数位数
  double toFixed(int decimalDigits) {
    return double.parse(toStringAsFixed(decimalDigits));
  }
  
  /// 是否近似相等（用于浮点数比较）
  bool isApproximately(double other, {double tolerance = 0.0001}) {
    return (this - other).abs() < tolerance;
  }
}

/// DateTime扩展方法
extension DateTimeExtensions on DateTime {
  /// 是否为今天
  bool get isToday {
    final DateTime now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  /// 是否为昨天
  bool get isYesterday {
    final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }
  
  /// 是否为明天
  bool get isTomorrow {
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }
  
  /// 获取一天的开始时间
  DateTime get startOfDay => DateTime(year, month, day);
  
  /// 获取一天的结束时间
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
  
  /// 获取一周的开始时间（周一）
  DateTime get startOfWeek {
    final DateTime monday = subtract(Duration(days: weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }
  
  /// 获取一周的结束时间（周日）
  DateTime get endOfWeek {
    final DateTime sunday = add(Duration(days: 7 - weekday));
    return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
  }
  
  /// 获取一月的开始时间
  DateTime get startOfMonth => DateTime(year, month, 1);
  
  /// 获取一月的结束时间
  DateTime get endOfMonth {
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, lastDay, 23, 59, 59, 999);
  }
  
  /// 获取相对时间描述
  String get relativeTime {
    final Duration diff = DateTime.now().difference(this);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return 'yyyy-MM-dd';
    }
  }
  
  /// 获取友好的时间描述
  String get friendlyTime {
    if (isToday) {
      return '今天 ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } else if (isYesterday) {
      return '昨天 ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } else if (isTomorrow) {
      return '明天 ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } else {
      return '$year-$month-$day';
    }
  }
  
  /// 是否是闰年
  bool get isLeapYear {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  }
  
  /// 获取该月的天数
  int get daysInMonth {
    return DateTime(year, month + 1, 0).day;
  }
  
  /// 获取该年的天数
  int get daysInYear {
    return isLeapYear ? 366 : 365;
  }
  
  /// 获取该年的第几天
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays + 1;
  }
}

/// List扩展方法
extension ListExtensions<T> on List<T> {
  /// 是否为空或null
  bool get isNullOrEmpty => isEmpty;
  
  /// 是否不为空
  bool get isNotNullOrEmpty => isNotEmpty;
  
  /// 安全获取元素
  T? safeGet(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
  
  /// 获取第一个元素
  T? get firstOrNull => isEmpty ? null : first;
  
  /// 获取最后一个元素
  T? get lastOrNull => isEmpty ? null : last;
  
  /// 分组
  Map<K, List<T>> groupBy<K>(K Function(T) keyFunction) {
    final Map<K, List<T>> result = <K, List<T>>{};
    for (final T item in this) {
      final K key = keyFunction(item);
      result.putIfAbsent(key, () => <T>[]).add(item);
    }
    return result;
  }
  
  /// 去重
  List<T> distinct([bool Function(T, T)? equals]) {
    if (equals == null) {
      return toSet().toList();
    }
    
    final List<T> result = <T>[];
    for (final T item in this) {
      if (!result.any((T existing) => equals(existing, item))) {
        result.add(item);
      }
    }
    return result;
  }
  
  /// 分块
  List<List<T>> chunked(int chunkSize) {
    final List<List<T>> result = <List<T>>[];
    for (int i = 0; i < length; i += chunkSize) {
      result.add(sublist(i, (i + chunkSize).clamp(0, length)));
    }
    return result;
  }
  
  /// 查找索引
  int? indexOfWhere(bool Function(T) predicate) {
    for (int i = 0; i < length; i++) {
      if (predicate(this[i])) return i;
    }
    return null;
  }
  
  /// 查找最后一个索引
  int? lastIndexOfWhere(bool Function(T) predicate) {
    for (int i = length - 1; i >= 0; i--) {
      if (predicate(this[i])) return i;
    }
    return null;
  }
}

/// Map扩展方法
extension MapExtensions<K, V> on Map<K, V> {
  /// 是否为空或null
  bool get isNullOrEmpty => isEmpty;
  
  /// 是否不为空
  bool get isNotNullOrEmpty => isNotEmpty;
  
  /// 安全获取值
  V? safeGet(K key) => this[key];
  
  /// 获取值或默认值
  V getOrDefault(K key, V defaultValue) => this[key] ?? defaultValue;
  
  /// 获取值或执行函数
  V getOrElse(K key, V Function() defaultValue) {
    final V? value = this[key];
    return value ?? defaultValue();
  }
  
  /// 如果键不存在则添加
  V putIfAbsent(K key, V Function() valueFunction) {
    return putIfAbsent(key, valueFunction);
  }
  
  /// 过滤
  Map<K, V> filterWhere(bool Function(K, V) predicate) {
    final Map<K, V> result = <K, V>{};
    forEach((K key, V value) {
      if (predicate(key, value)) {
        result[key] = value;
      }
    });
    return result;
  }
  
  /// 映射值
  Map<K, V2> mapValues<V2>(V2 Function(V) transform) {
    final Map<K, V2> result = <K, V2>{};
    forEach((K key, V value) {
      result[key] = transform(value);
    });
    return result;
  }
  
  /// 映射键
  Map<K2, V> mapKeys<K2>(K2 Function(K) transform) {
    final Map<K2, V> result = <K2, V>{};
    forEach((K key, V value) {
      result[transform(key)] = value;
    });
    return result;
  }
}

/// Color扩展方法
extension ColorExtensions on Color {
  /// 获取颜色的十六进制字符串
  String get toHex {
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
  
  /// 获取颜色的RGB值
  List<int> get rgb => <int>[red, green, blue];
  
  /// 获取颜色的RGBA值
  List<int> get rgba => <int>[red, green, blue, alpha];
  
  /// 获取颜色的亮度
  double get luminance {
    return (0.299 * red + 0.587 * green + 0.114 * blue) / 255;
  }
  
  /// 是否为深色
  bool get isDark => luminance < 0.5;
  
  /// 是否为浅色
  bool get isLight => luminance >= 0.5;
  
  /// 混合颜色
  Color blend(Color other, double ratio) {
    final int r = (red * (1 - ratio) + other.red * ratio).round();
    final int g = (green * (1 - ratio) + other.green * ratio).round();
    final int b = (blue * (1 - ratio) + other.blue * ratio).round();
    final int a = (alpha * (1 - ratio) + other.alpha * ratio).round();
    return Color.fromARGB(a, r, g, b);
  }
  
  /// 获取互补色
  Color get complementary {
    return Color.fromARGB(alpha, 255 - red, 255 - green, 255 - blue);
  }
}

/// Widget扩展方法
extension WidgetExtensions on Widget {
  /// 添加内边距
  Widget padding(EdgeInsetsGeometry padding) {
    return Padding(padding: padding, child: this);
  }
  
  /// 添加外边距
  Widget margin(EdgeInsetsGeometry margin) {
    return Container(margin: margin, child: this);
  }
  
  /// 添加圆角
  Widget clipRRect(BorderRadius borderRadius) {
    return ClipRRect(borderRadius: borderRadius, child: this);
  }
  
  /// 添加背景色
  Widget backgroundColor(Color color) {
    return Container(color: color, child: this);
  }
  
  /// 添加手势检测
  Widget onTap(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }
  
  /// 添加长按手势
  Widget onLongPress(VoidCallback onLongPress) {
    return GestureDetector(onLongPress: onLongPress, child: this);
  }
  
  /// 添加透明度
  Widget opacity(double opacity) {
    return Opacity(opacity: opacity, child: this);
  }
  
  /// 添加旋转
  Widget rotate(double angle) {
    return Transform.rotate(angle: angle, child: this);
  }
  
  /// 添加缩放
  Widget scale(double scale) {
    return Transform.scale(scale: scale, child: this);
  }
  
  /// 添加平移
  Widget translate(Offset offset) {
    return Transform.translate(offset: offset, child: this);
  }
  
  /// 添加对齐
  Widget align(Alignment alignment) {
    return Align(alignment: alignment, child: this);
  }
  
  /// 添加居中
  Widget center() {
    return Center(child: this);
  }
  
  /// 添加扩展
  Widget expand({int flex = 1}) {
    return Expanded(flex: flex, child: this);
  }
  
  /// 添加灵活空间
  Widget flexible({int flex = 1, FlexFit fit = FlexFit.loose}) {
    return Flexible(flex: flex, fit: fit, child: this);
  }
  
  /// 添加定位
  Widget positioned({
    double left = 0.0,
    double top = 0.0,
    double right = 0.0,
    double bottom = 0.0,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: this,
    );
  }
  
  /// 添加可见性控制
  Widget visible(bool visible, {Widget? replacement}) {
    return Visibility(
      visible: visible,
      child: this,
      replacement: replacement ?? const SizedBox.shrink(),
    );
  }
  
  /// 添加条件显示
  Widget when(bool condition, {Widget? otherwise}) {
    return condition ? this : (otherwise ?? const SizedBox.shrink());
  }
  
  /// 添加安全区域
  Widget safeArea({
    bool top = true,
    bool bottom = true,
    bool left = true,
    bool right = true,
  }) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: this,
    );
  }
  
  /// 添加英雄动画
  Widget hero(String tag, {Object? flightShuttleBuilder}) {
    return Hero(
      tag: tag,
      child: this,
      flightShuttleBuilder: flightShuttleBuilder as FlightShuttleBuilderBuilder?,
    );
  }
  
  /// 添加装饰
  Widget decorated({
    Color? color,
    DecorationImage? image,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BlendMode? backgroundBlendMode,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        image: image,
        border: border,
        borderRadius: borderRadius,
        boxShadow: boxShadow,
        gradient: gradient,
        backgroundBlendMode: backgroundBlendMode,
        shape: shape,
      ),
      child: this,
    );
  }
  
  /// 添加约束
  Widget constraints(BoxConstraints constraints) {
    return ConstrainedBox(constraints: constraints, child: this);
  }
  
  /// 添加限制
  Widget limitSize({double? maxWidth, double? maxHeight}) {
    return LimitedBox(
      maxWidth: maxWidth ?? double.infinity,
      maxHeight: maxHeight ?? double.infinity,
      child: this,
    );
  }
  
  /// 添加宽高比
  Widget aspectRatio(double aspectRatio) {
    return AspectRatio(aspectRatio: aspectRatio, child: this);
  }
  
  /// 添加分数大小
  Widget fractionallySizedBox({
    double? widthFactor,
    double? heightFactor,
    Alignment alignment = Alignment.center,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      alignment: alignment,
      child: this,
    );
  }
}

/// Duration扩展方法
extension DurationExtensions on Duration {
  /// 获取格式化的时间字符串
  String get formatted {
    final String twoDigits(int n) => n.toString().padLeft(2, '0');
    
    if (inDays > 0) {
      return '${twoDigits(inDays)}:${twoDigits(inHours.remainder(24))}:${twoDigits(inMinutes.remainder(60))}:${twoDigits(inSeconds.remainder(60))}';
    } else if (inHours > 0) {
      return '${twoDigits(inHours)}:${twoDigits(inMinutes.remainder(60))}:${twoDigits(inSeconds.remainder(60))}';
    } else if (inMinutes > 0) {
      return '${twoDigits(inMinutes)}:${twoDigits(inSeconds.remainder(60))}';
    } else {
      return '${twoDigits(inSeconds)}';
    }
  }
  
  /// 获取友好的时间描述
  String get friendly {
    if (inSeconds < 60) {
      return '${inSeconds}秒';
    } else if (inMinutes < 60) {
      return '${inMinutes}分钟';
    } else if (inHours < 24) {
      return '${inHours}小时';
    } else {
      return '${inDays}天';
    }
  }
}

/// Future扩展方法
extension FutureExtensions<T> on Future<T> {
  /// 添加超时处理
  Future<T?> timeoutWithDefault(Duration duration, {T? defaultValue}) {
    return timeout(duration).catchError((Object error) {
      return defaultValue;
    });
  }
  
  /// 添加重试机制
  Future<T> retry(int maxAttempts, Future<T> Function() operation) async {
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (error) {
        attempts++;
        if (attempts >= maxAttempts) {
          rethrow;
        }
        // 等待一段时间后重试
        await Future.delayed(Duration(seconds: attempts));
      }
    }
    
    throw Exception('Max retry attempts reached');
  }
}

/// HapticFeedback扩展方法
extension HapticExtensions on HapticFeedback {
  /// 轻微震动
  static Future<void> light() {
    return HapticFeedback.lightImpact();
  }
  
  /// 中等震动
  static Future<void> medium() {
    return HapticFeedback.mediumImpact();
  }
  
  /// 强烈震动
  static Future<void> heavy() {
    return HapticFeedback.heavyImpact();
  }
  
  /// 选择震动
  static Future<void> selection() {
    return HapticFeedback.selectionClick();
  }
  
  /// 通知震动
  static Future<void> notification() {
    return HapticFeedback.notification(HapticFeedbackType.success);
  }
}

/// Clipboard扩展方法
extension ClipboardExtensions on Clipboard {
  /// 复制文本到剪贴板
  static Future<void> copyText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
  
  /// 从剪贴板获取文本
  static Future<String> getText() async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    return data?.text ?? '';
  }
}

/// 自定义异常类
class AppException implements Exception {
  const AppException(this.message, {this.code, this.stackTrace});
  
  final String message;
  final String? code;
  final StackTrace? stackTrace;
  
  @override
  String toString() {
    if (code != null) {
      return 'AppException[$code]: $message';
    }
    return 'AppException: $message';
  }
}

/// 结果类型
class Result<T> {
  const Result.success(this.value) : _error = null;
  const Result.failure(this._error) : value = null;
  
  final T? value;
  final String? _error;
  
  bool get isSuccess => _error == null;
  bool get isFailure => _error != null;
  
  String get error => _error ?? '';
  
  T get data {
    if (value == null) {
      throw Exception('No data available. Error: $_error');
    }
    return value!;
  }
  
  static Result<T> success<T>(T value) => Result<T>.success(value);
  static Result<T> failure<T>(String error) => Result<T>.failure(error);
  
  Result<R> map<R>(R Function(T) mapper) {
    if (isSuccess && value != null) {
      try {
        return Result<R>.success(mapper(value!));
      } catch (error) {
        return Result<R>.failure(error.toString());
      }
    }
    return Result<R>.failure(_error!);
  }
  
  Result<T> onError(String Function(String) errorHandler) {
    if (isFailure) {
      return Result<T>.failure(errorHandler(_error!));
    }
    return this;
  }
}
