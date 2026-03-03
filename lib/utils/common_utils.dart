import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 日期时间工具类
class DateTimeUtils {
  static const String _defaultDateFormat = 'yyyy-MM-dd';
  static const String _defaultTimeFormat = 'HH:mm:ss';
  static const String _defaultDateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  
  /// 格式化日期
  static String formatDate(DateTime date, {String? format}) {
    return DateFormat(format ?? _defaultDateFormat).format(date);
  }
  
  /// 格式化时间
  static String formatTime(DateTime time, {String? format}) {
    return DateFormat(format ?? _defaultTimeFormat).format(time);
  }
  
  /// 格式化日期时间
  static String formatDateTime(DateTime dateTime, {String? format}) {
    return DateFormat(format ?? _defaultDateTimeFormat).format(dateTime);
  }
  
  /// 获取相对时间描述
  static String getRelativeTime(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return formatDate(dateTime);
    }
  }
  
  /// 获取友好的时间描述
  static String getFriendlyTime(DateTime dateTime) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final DateTime targetDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (targetDate == today) {
      return '今天 ${formatTime(dateTime)}';
    } else if (targetDate == yesterday) {
      return '昨天 ${formatTime(dateTime)}';
    } else if (targetDate == tomorrow) {
      return '明天 ${formatTime(dateTime)}';
    } else {
      return formatDateTime(dateTime);
    }
  }
  
  /// 是否为今天
  static bool isToday(DateTime dateTime) {
    final DateTime now = DateTime.now();
    return dateTime.year == now.year &&
           dateTime.month == now.month &&
           dateTime.day == now.day;
  }
  
  /// 是否为昨天
  static bool isYesterday(DateTime dateTime) {
    final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
           dateTime.month == yesterday.month &&
           dateTime.day == yesterday.day;
  }
  
  /// 获取一天的开始时间
  static DateTime getStartOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
  
  /// 获取一天的结束时间
  static DateTime getEndOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59, 999);
  }
}

/// 字符串工具类
class StringUtils {
  /// 是否为空或null
  static bool isEmpty(String? str) {
    return str == null || str.trim().isEmpty;
  }
  
  /// 是否不为空
  static bool isNotEmpty(String? str) {
    return !isEmpty(str);
  }
  
  /// 截取字符串
  static String truncate(String str, int length, {String suffix = '...'}) {
    if (str.length <= length) return str;
    return str.substring(0, length - suffix.length) + suffix;
  }
  
  /// 首字母大写
  static String capitalize(String str) {
    if (isEmpty(str)) return str;
    return str[0].toUpperCase() + str.substring(1).toLowerCase();
  }
  
  /// 驼峰命名转下划线
  static String camelToSnake(String str) {
    return str.replaceAllMapped(
      RegExp(r'(?<!^)(?=[A-Z])'),
      (Match match) => '_${match.group(0)}',
    ).toLowerCase();
  }
  
  /// 下划线转驼峰命名
  static String snakeToCamel(String str) {
    return str.split('_').map((String part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join('');
  }
  
  /// 生成随机字符串
  static String generateRandomString(int length, {String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'}) {
    final Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(length).map((_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }
  
  /// 验证邮箱格式
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$').hasMatch(email);
  }
  
  /// 验证手机号格式（中国）
  static bool isValidPhoneNumber(String phone) {
    return RegExp(r'^1[3-9]\\d{9}$').hasMatch(phone);
  }
  
  /// 验证IP地址格式
  static bool isValidIpAddress(String ip) {
    return RegExp(r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$').hasMatch(ip);
  }
  
  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// 数值工具类
class NumberUtils {
  /// 格式化数字
  static String formatNumber(num number, {int? decimalDigits}) {
    return NumberFormat('#,##0${decimalDigits != null ? '.${'#' * decimalDigits}' : ''}').format(number);
  }
  
  /// 格式化百分比
  static String formatPercentage(double value, {int decimalDigits = 1}) {
    return '${(value * 100).toStringAsFixed(decimalDigits)}%';
  }
  
  /// 生成随机整数
  static int randomInt(int min, int max) {
    return Random().nextInt(max - min + 1) + min;
  }
  
  /// 生成随机小数
  static double randomDouble(double min, double max) {
    return Random().nextDouble() * (max - min) + min;
  }
  
  /// 限制数值范围
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
  
  /// 计算平均值
  static double average(List<num> numbers) {
    if (numbers.isEmpty) return 0.0;
    return numbers.reduce((num a, num b) => a + b) / numbers.length;
  }
  
  /// 计算总和
  static num sum(List<num> numbers) {
    return numbers.reduce((num a, num b) => a + b);
  }
  
  /// 查找最大值
  static num max(List<num> numbers) {
    if (numbers.isEmpty) throw ArgumentError('List is empty');
    return numbers.reduce((num a, num b) => a > b ? a : b);
  }
  
  /// 查找最小值
  static num min(List<num> numbers) {
    if (numbers.isEmpty) throw ArgumentError('List is empty');
    return numbers.reduce((num a, num b) => a < b ? a : b);
  }
}

/// 文件工具类
class FileUtils {
  /// 获取文件扩展名
  static String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }
  
  /// 获取文件名（不含扩展名）
  static String getFileName(String filePath) {
    final String fileName = filePath.split('/').last;
    final int dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }
  
  /// 获取文件名（含扩展名）
  static String getFileNameWithExtension(String filePath) {
    return filePath.split('/').last;
  }
  
  /// 是否为图片文件
  static bool isImageFile(String filePath) {
    final String extension = getFileExtension(filePath);
    return <String>['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(extension);
  }
  
  /// 是否为视频文件
  static bool isVideoFile(String filePath) {
    final String extension = getFileExtension(filePath);
    return <String>['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm'].contains(extension);
  }
  
  /// 是否为音频文件
  static bool isAudioFile(String filePath) {
    final String extension = getFileExtension(filePath);
    return <String>['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(extension);
  }
  
  /// 是否为文档文件
  static bool isDocumentFile(String filePath) {
    final String extension = getFileExtension(filePath);
    return <String>['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].contains(extension);
  }
  
  /// 获取文件类型图标
  static IconData getFileIcon(String filePath) {
    if (isImageFile(filePath)) return Icons.image;
    if (isVideoFile(filePath)) return Icons.video_file;
    if (isAudioFile(filePath)) return Icons.audio_file;
    if (isDocumentFile(filePath)) return Icons.description;
    return Icons.insert_drive_file;
  }
}

/// 验证工具类
class ValidationUtils {
  /// 验证必填字段
  static String? validateRequired(String? value, String fieldName) {
    if (StringUtils.isEmpty(value)) {
      return '$fieldName不能为空';
    }
    return null;
  }
  
  /// 验证最小长度
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value != null && value.length < minLength) {
      return '$fieldName长度不能少于$minLength个字符';
    }
    return null;
  }
  
  /// 验证最大长度
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value != null && value.length > maxLength) {
      return '$fieldName长度不能超过$maxLength个字符';
    }
    return null;
  }
  
  /// 验证邮箱
  static String? validateEmail(String? value) {
    if (StringUtils.isNotEmpty(value) && !StringUtils.isValidEmail(value!)) {
      return '请输入有效的邮箱地址';
    }
    return null;
  }
  
  /// 验证手机号
  static String? validatePhone(String? value) {
    if (StringUtils.isNotEmpty(value) && !StringUtils.isValidPhoneNumber(value!)) {
      return '请输入有效的手机号码';
    }
    return null;
  }
  
  /// 验证IP地址
  static String? validateIpAddress(String? value) {
    if (StringUtils.isNotEmpty(value) && !StringUtils.isValidIpAddress(value!)) {
      return '请输入有效的IP地址';
    }
    return null;
  }
  
  /// 验证端口范围
  static String? validatePort(String? value) {
    if (StringUtils.isEmpty(value)) return null;
    
    final int? port = int.tryParse(value!);
    if (port == null) {
      return '端口必须是数字';
    }
    if (port < 1 || port > 65535) {
      return '端口范围必须在1-65535之间';
    }
    return null;
  }
}

/// 加密工具类
class CryptoUtils {
  /// 生成MD5哈希
  static String generateMD5(String input) {
    // 这里需要导入crypto包
    // import 'package:crypto/crypto.dart';
    // return md5.convert(utf8.encode(input)).toString();
    return input; // 临时返回原值
  }
  
  /// 生成SHA256哈希
  static String generateSHA256(String input) {
    // 这里需要导入crypto包
    // import 'package:crypto/crypto.dart';
    // return sha256.convert(utf8.encode(input)).toString();
    return input; // 临时返回原值
  }
  
  /// 生成随机盐值
  static String generateSalt({int length = 16}) {
    return StringUtils.generateRandomString(length);
  }
  
  /// 生成UUID
  static String generateUUID() {
    return '${DateTime.now().millisecondsSinceEpoch}-${StringUtils.generateRandomString(8)}';
  }
}

/// 设备信息工具类
class DeviceUtils {
  /// 获取设备类型
  static String getDeviceType() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (kIsWeb) return 'Web';
    return 'Unknown';
  }
  
  /// 是否为移动设备
  static bool isMobileDevice() {
    return Platform.isAndroid || Platform.isIOS;
  }
  
  /// 是否为桌面设备
  static bool isDesktopDevice() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
  
  /// 获取设备唯一标识
  static Future<String> getDeviceId() async {
    // 这里可以使用device_info_plus包获取设备唯一标识
    // import 'package:device_info_plus/device_info_plus.dart';
    return CryptoUtils.generateUUID();
  }
}

/// 网络工具类
class NetworkUtils {
  /// 验证URL格式
  static bool isValidUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  /// 构建URL
  static String buildUrl(String baseUrl, Map<String, String?> params) {
    final Uri uri = Uri.parse(baseUrl);
    final Map<String, String> queryParams = <String, String>{};
    
    queryParams.addAll(uri.queryParameters);
    params.forEach((String key, String? value) {
      if (StringUtils.isNotEmpty(value)) {
        queryParams[key] = value!;
      }
    });
    
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: uri.path,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    ).toString();
  }
  
  /// 获取URL中的参数
  static Map<String, String> getUrlParams(String url) {
    try {
      final Uri uri = Uri.parse(url);
      return uri.queryParameters;
    } catch (e) {
      return <String, String>{};
    }
  }
}

/// JSON工具类
class JsonUtils {
  /// 安全解析JSON
  static Map<String, dynamic>? safeDecodeJson(String json) {
    try {
      final dynamic decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('JSON解析错误: $e');
      }
      return null;
    }
  }
  
  /// 安全编码JSON
  static String? safeEncodeJson(Map<String, dynamic> json) {
    try {
      return jsonEncode(json);
    } catch (e) {
      if (kDebugMode) {
        print('JSON编码错误: $e');
      }
      return null;
    }
  }
  
  /// 从JSON中获取字符串值
  static String getString(Map<String, dynamic>? json, String key, {String defaultValue = ''}) {
    if (json == null) return defaultValue;
    final dynamic value = json[key];
    return value?.toString() ?? defaultValue;
  }
  
  /// 从JSON中获取整数值
  static int getInt(Map<String, dynamic>? json, String key, {int defaultValue = 0}) {
    if (json == null) return defaultValue;
    final dynamic value = json[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }
  
  /// 从JSON中获取双精度值
  static double getDouble(Map<String, dynamic>? json, String key, {double defaultValue = 0.0}) {
    if (json == null) return defaultValue;
    final dynamic value = json[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
  
  /// 从JSON中获取布尔值
  static bool getBool(Map<String, dynamic>? json, String key, {bool defaultValue = false}) {
    if (json == null) return defaultValue;
    final dynamic value = json[key];
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is int) {
      return value != 0;
    }
    return defaultValue;
  }
  
  /// 从JSON中获取列表
  static List<T> getList<T>(Map<String, dynamic>? json, String key, {List<T> defaultValue = const []}) {
    if (json == null) return defaultValue;
    final dynamic value = json[key];
    if (value is List) {
      return value.cast<T>();
    }
    return defaultValue;
  }
}

/// 防抖动工具
class Debouncer {
  final Duration duration;
  Timer? _timer;
  
  Debouncer({required this.duration});
  
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }
  
  void cancel() {
    _timer?.cancel();
  }
  
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 节流工具
class Throttler {
  final Duration duration;
  Timer? _timer;
  bool _isRunning = false;
  
  Throttler({required this.duration});
  
  void run(VoidCallback action) {
    if (_isRunning) return;
    
    _isRunning = true;
    action();
    
    _timer = Timer(duration, () {
      _isRunning = false;
    });
  }
  
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }
}

/// 简单缓存类
class SimpleCache<K, V> {
  final Map<K, _CacheItem<V>> _cache = <K, _CacheItem<V>>{};
  final Duration duration;
  Timer? _cleanupTimer;
  
  SimpleCache({this.duration = const Duration(minutes: 5)}) {
    _startCleanupTimer();
  }
  
  void put(K key, V value) {
    _cache[key] = _CacheItem<V>(value, DateTime.now().add(duration));
  }
  
  V? get(K key) {
    final _CacheItem<V>? item = _cache[key];
    if (item == null) return null;
    
    if (DateTime.now().isAfter(item.expiry)) {
      _cache.remove(key);
      return null;
    }
    
    return item.value;
  }
  
  void remove(K key) {
    _cache.remove(key);
  }
  
  void clear() {
    _cache.clear();
  }
  
  int get size => _cache.length;
  
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(duration, (_) => _cleanup());
  }
  
  void _cleanup() {
    final DateTime now = DateTime.now();
    _cache.removeWhere((K key, _CacheItem<V> item) => now.isAfter(item.expiry));
  }
  
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

class _CacheItem<V> {
  final V value;
  final DateTime expiry;
  
  _CacheItem(this.value, this.expiry);
}
