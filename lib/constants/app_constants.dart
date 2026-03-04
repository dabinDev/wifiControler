import 'package:flutter/material.dart';

import '../protocol/message_types.dart';

/// 应用常量配置
class AppConstants {
  AppConstants._();

  static const String appName = 'UDP Control Suite';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Flutter UDP Control Suite - 设备控制与管理应用';
}

class NetworkConfig {
  NetworkConfig._();

  static const int defaultUdpPort = 8888;
  static const int maxRetries = 3;
  static const int connectionTimeout = 5000; // 毫秒
  static const int heartbeatInterval = 30000; // 毫秒
  static const int deviceCleanupInterval = 15000; // 毫秒
  static const int messageSendTimeout = 3000; // 毫秒
  static const int broadcastInterval = 1000; // 毫秒
}

class DatabaseConfig {
  DatabaseConfig._();

  static const String databaseName = 'udp_control.db';
  static const int databaseVersion = 1;
  static const int maxLogEntries = 10000;
  static const int maxMessageHistory = 1000;
  static const int maxDeviceHistory = 500;
  static const int cleanupInterval = 24; // 小时
}

class StorageConfig {
  StorageConfig._();

  static const String capturesDir = 'captures';
  static const String recordingsDir = 'recordings';
  static const String logsDir = 'logs';
  static const String tempDir = 'temp';
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int maxStorageAge = 7; // 天
  static const int maxCacheSize = 500 * 1024 * 1024; // 500MB
}

class UiConstants {
  UiConstants._();

  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;
  static const double defaultSpacing = 16.0;
  static const double smallSpacing = 8.0;
  static const double largeSpacing = 24.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const int defaultAnimationDuration = 300; // 毫秒
  static const int fastAnimationDuration = 150; // 毫秒
  static const int slowAnimationDuration = 500; // 毫秒
}

class PermissionConfig {
  PermissionConfig._();

  static const List<String> requiredPermissions = <String>[
    'camera',
    'microphone',
    'storage',
    'notifications',
  ];

  static const List<String> optionalPermissions = <String>[
    'location',
    'phone',
  ];
}

class DeviceConfig {
  DeviceConfig._();

  static const String controllerPrefix = 'ctrl';
  static const String controlledPrefix = 'dev';
  static const int deviceIdLength = 16;
  static const int deviceSecretLength = 32;
  static const int tokenExpirationHours = 24;
  static const int maxTrustedDevices = 50;
  static const int maxBlockedDevices = 100;
}

class LoggingConfig {
  LoggingConfig._();

  static const int maxLogFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxLogFiles = 5;
  static const int logRetentionDays = 7;
  static const bool enableFileLogging = true;
  static const bool enableConsoleLogging = true;
}

class SecurityConfig {
  SecurityConfig._();

  static const int maxLoginAttempts = 5;
  static const int lockoutDuration = 300; // 秒
  static const int sessionTimeout = 3600; // 秒
  static const int passwordMinLength = 8;
  static const bool requireDeviceAuth = true;
  static const bool encryptCommunication = true;
}

class PerformanceConfig {
  PerformanceConfig._();

  static const int maxConcurrentOperations = 10;
  static const int cacheExpirationMinutes = 30;
  static const int memoryCleanupInterval = 300; // 秒
  static const int maxMemoryUsage = 200 * 1024 * 1024; // 200MB
  static const bool enablePerformanceMonitoring = true;
}

/// 消息类型映射
class MessageMapping {
  static const Map<String, String> chineseAbbreviations = <String, String>{
    MessageTypes.hello: '你好',
    MessageTypes.discover: '发现',
    MessageTypes.heartbeat: '心跳',
    MessageTypes.ack: '确认',
    MessageTypes.cmdTakePhoto: '拍照',
    MessageTypes.cmdRecordStart: '开始录像',
    MessageTypes.cmdRecordStop: '停止录像',
    MessageTypes.cmdAudioStart: '开始录音',
    MessageTypes.cmdAudioStop: '停止录音',
    MessageTypes.cmdFileUpload: '上传文件',
    MessageTypes.cmdUploadCancel: '取消上传',
    MessageTypes.cmdRtcStart: '开始推流',
    MessageTypes.cmdRtcStop: '停止推流',
    MessageTypes.cmdCamSwitch: '切换相机',
    MessageTypes.cmdZoomSet: '设置变焦',
    MessageTypes.cmdTorchSet: '设置闪光灯',
    MessageTypes.cmdFocusSet: '设置对焦',
    MessageTypes.cmdCleanFiles: '清理文件',
    MessageTypes.cmdAppRestart: '重启应用',
    MessageTypes.cmdLogQuery: '查询日志',
  };
  
  static const Map<String, String> descriptions = <String, String>{
    MessageTypes.hello: '设备问候消息',
    MessageTypes.discover: '设备发现请求',
    MessageTypes.heartbeat: '心跳保持连接',
    MessageTypes.ack: '消息确认回复',
    MessageTypes.cmdTakePhoto: '拍照命令',
    MessageTypes.cmdRecordStart: '开始录像命令',
    MessageTypes.cmdRecordStop: '停止录像命令',
    MessageTypes.cmdAudioStart: '开始录音命令',
    MessageTypes.cmdAudioStop: '停止录音命令',
    MessageTypes.cmdFileUpload: '文件上传命令',
    MessageTypes.cmdUploadCancel: '取消上传命令',
    MessageTypes.cmdRtcStart: '开始推流命令',
    MessageTypes.cmdRtcStop: '停止推流命令',
    MessageTypes.cmdCamSwitch: '切换相机命令',
    MessageTypes.cmdZoomSet: '设置变焦命令',
    MessageTypes.cmdTorchSet: '设置闪光灯命令',
    MessageTypes.cmdFocusSet: '设置对焦命令',
    MessageTypes.cmdCleanFiles: '清理文件命令',
    MessageTypes.cmdAppRestart: '重启应用命令',
    MessageTypes.cmdLogQuery: '日志查询命令',
  };
  
  /// 根据消息类型获取中文缩写
  static String getChineseAbbreviation(String messageType) {
    return chineseAbbreviations[messageType] ?? messageType;
  }
  
  /// 根据中文缩写获取消息类型
  static String? getMessageTypeFromAbbreviation(String abbreviation) {
    for (MapEntry<String, String> entry in chineseAbbreviations.entries) {
      if (entry.value == abbreviation) {
        return entry.key;
      }
    }
    return null;
  }
  
  /// 获取消息描述
  static String getDescription(String messageType) {
    return descriptions[messageType] ?? '未知消息类型';
  }
  
  /// 获取所有控制命令
  static List<String> getCommandMessages() {
    return <String>[
      MessageTypes.cmdRecordStart,
      MessageTypes.cmdRecordStop,
      MessageTypes.cmdTakePhoto,
      MessageTypes.cmdAudioStart,
      MessageTypes.cmdAudioStop,
      MessageTypes.cmdFileUpload,
      MessageTypes.cmdUploadCancel,
      MessageTypes.cmdRtcStart,
      MessageTypes.cmdRtcStop,
      MessageTypes.cmdCamSwitch,
      MessageTypes.cmdZoomSet,
      MessageTypes.cmdTorchSet,
      MessageTypes.cmdFocusSet,
      MessageTypes.cmdCleanFiles,
      MessageTypes.cmdAppRestart,
      MessageTypes.cmdLogQuery,
    ];
  }
  
  /// 获取所有响应消息
  static List<String> getResponseMessages() {
    return <String>[];
  }
  
  /// 获取所有状态消息
  static List<String> getStatusMessages() {
    return <String>[];
  }
  
  /// 获取所有系统消息
  static List<String> getSystemMessages() {
    return <String>[
      MessageTypes.hello,
      MessageTypes.discover,
      MessageTypes.heartbeat,
      MessageTypes.ack,
    ];
  }
}

/// 错误代码常量
class ErrorCodes {
  // 私有构造函数
  ErrorCodes._();
  
  /// 通用错误
  static const String unknownError = 'UNKNOWN_ERROR';
  static const String invalidParameter = 'INVALID_PARAMETER';
  static const String operationFailed = 'OPERATION_FAILED';
  static const String timeoutError = 'TIMEOUT_ERROR';
  
  /// 网络错误
  static const String networkUnavailable = 'NETWORK_UNAVAILABLE';
  static const String connectionFailed = 'CONNECTION_FAILED';
  static const String sendFailed = 'SEND_FAILED';
  static const String receiveFailed = 'RECEIVE_FAILED';
  
  /// 权限错误
  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String permissionRequired = 'PERMISSION_REQUIRED';
  
  /// 设备错误
  static const String deviceNotFound = 'DEVICE_NOT_FOUND';
  static const String deviceOffline = 'DEVICE_OFFLINE';
  static const String deviceBusy = 'DEVICE_BUSY';
  
  /// 文件错误
  static const String fileNotFound = 'FILE_NOT_FOUND';
  static const String fileAccessDenied = 'FILE_ACCESS_DENIED';
  static const String storageFull = 'STORAGE_FULL';
  
  /// 认证错误
  static const String authenticationFailed = 'AUTHENTICATION_FAILED';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String unauthorized = 'UNAUTHORIZED';
}

/// 错误消息映射
class ErrorMessages {
  static const Map<String, String> messages = <String, String>{
    ErrorCodes.unknownError: '未知错误',
    ErrorCodes.invalidParameter: '参数无效',
    ErrorCodes.operationFailed: '操作失败',
    ErrorCodes.timeoutError: '操作超时',
    ErrorCodes.networkUnavailable: '网络不可用',
    ErrorCodes.connectionFailed: '连接失败',
    ErrorCodes.sendFailed: '发送失败',
    ErrorCodes.receiveFailed: '接收失败',
    ErrorCodes.permissionDenied: '权限被拒绝',
    ErrorCodes.permissionRequired: '需要权限',
    ErrorCodes.deviceNotFound: '设备未找到',
    ErrorCodes.deviceOffline: '设备离线',
    ErrorCodes.deviceBusy: '设备忙碌',
    ErrorCodes.fileNotFound: '文件未找到',
    ErrorCodes.fileAccessDenied: '文件访问被拒绝',
    ErrorCodes.storageFull: '存储空间不足',
    ErrorCodes.authenticationFailed: '认证失败',
    ErrorCodes.tokenExpired: '令牌已过期',
    ErrorCodes.unauthorized: '未授权访问',
  };
  
  /// 根据错误代码获取错误消息
  static String getMessage(String errorCode) {
    return messages[errorCode] ?? '未知错误';
  }
}

/// 正则表达式常量
class RegexPatterns {
  // 私有构造函数
  RegexPatterns._();
  
  /// 邮箱验证
  static const String email = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
  
  /// 手机号验证（中国）
  static const String phoneNumber = r'^1[3-9]\\d{9}$';
  
  /// IP地址验证
  static const String ipAddress = r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$';
  
  /// URL验证
  static const String url = r'^https?://(?:[-\\w.])+(?:[:\\d]+)?(?:/(?:[\\w/_.])*(?:\\?(?:[\\w&=%.])*)?(?:#(?:\\w*))?)?$';
  
  /// 设备ID验证
  static const String deviceId = r'^[a-zA-Z0-9]{16}$';
  
  /// 端口号验证
  static const String port = r'^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$';
  
  /// 文件名验证
  static const String fileName = r'^[^\\\\/:*?\"<>|]+$';
  
  /// 密码强度验证（至少8位，包含大小写字母和数字）
  static const String strongPassword = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d@$!%*?&]{8,}$';
}

/// 动画持续时间常量
class AnimationDurations {
  // 私有构造函数
  AnimationDurations._();
  
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration extraSlow = Duration(milliseconds: 800);
  static const Duration pageTransition = Duration(milliseconds: 250);
  static const Duration buttonPress = Duration(milliseconds: 100);
  static const Duration fadeIn = Duration(milliseconds: 200);
  static const Duration slideUp = Duration(milliseconds: 300);
  static const Duration slideDown = Duration(milliseconds: 300);
}

/// 图标常量
class AppIcons {
  // 私有构造函数
  AppIcons._();
  
  /// 导航图标
  static const IconData home = Icons.home;
  static const IconData settings = Icons.settings;
  static const IconData back = Icons.arrow_back;
  static const IconData menu = Icons.menu;
  
  /// 网络图标
  static const IconData wifi = Icons.wifi;
  static const IconData wifiOff = Icons.wifi_off;
  static const IconData signal = Icons.signal_cellular_4_bar;
  static const IconData signalOff = Icons.signal_cellular_off;
  
  /// 设备图标
  static const IconData device = Icons.devices;
  static const IconData smartphone = Icons.smartphone;
  static const IconData tablet = Icons.tablet;
  static const IconData desktop = Icons.desktop_windows;
  
  /// 状态图标
  static const IconData online = Icons.check_circle;
  static const IconData offline = Icons.cancel;
  static const IconData busy = Icons.hourglass_empty;
  static const IconData error = Icons.error;
  static const IconData warning = Icons.warning;
  static const IconData info = Icons.info;
  
  /// 操作图标
  static const IconData add = Icons.add;
  static const IconData remove = Icons.remove;
  static const IconData edit = Icons.edit;
  static const IconData delete = Icons.delete;
  static const IconData refresh = Icons.refresh;
  static const IconData download = Icons.download;
  static const IconData upload = Icons.upload;
  
  /// 媒体图标
  static const IconData camera = Icons.camera_alt;
  static const IconData video = Icons.videocam;
  static const IconData microphone = Icons.mic;
  static const IconData image = Icons.image;
  static const IconData play = Icons.play_arrow;
  static const IconData pause = Icons.pause;
  static const IconData stop = Icons.stop;
  
  /// 文件图标
  static const IconData file = Icons.insert_drive_file;
  static const IconData folder = Icons.folder;
  static const IconData folderOpen = Icons.folder_open;
  static const IconData document = Icons.description;
  
  /// 安全图标
  static const IconData lock = Icons.lock;
  static const IconData unlock = Icons.lock_open;
  static const IconData key = Icons.vpn_key;
  static const IconData shield = Icons.security;
  
  /// 其他图标
  static const IconData search = Icons.search;
  static const IconData filter = Icons.filter_list;
  static const IconData sort = Icons.sort;
  static const IconData more = Icons.more_vert;
  static const IconData close = Icons.close;
  static const IconData check = Icons.check;
  static const IconData cancel = Icons.cancel;
}

/// 颜色常量
class AppColors {
  // 私有构造函数
  AppColors._();
  
  /// 主色调
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF63A4FF);
  static const Color primaryDark = Color(0xFF004BA0);
  
  /// 辅助色
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryLight = Color(0xFF66FFF9);
  static const Color secondaryDark = Color(0xFF00A896);
  
  /// 状态色
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF80E27E);
  static const Color successDark = Color(0xFF087F23);
  
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFCC80);
  static const Color warningDark = Color(0xFFE65100);
  
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFFF5252);
  static const Color errorDark = Color(0xFFB71C1C);
  
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF0D47A1);
  
  /// 中性色
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
  
  /// 透明度变体
  static Color primaryWithOpacity(double opacity) => primary.withOpacity(opacity);
  static Color secondaryWithOpacity(double opacity) => secondary.withOpacity(opacity);
  static Color successWithOpacity(double opacity) => success.withOpacity(opacity);
  static Color warningWithOpacity(double opacity) => warning.withOpacity(opacity);
  static Color errorWithOpacity(double opacity) => error.withOpacity(opacity);
  static Color infoWithOpacity(double opacity) => info.withOpacity(opacity);
  static Color greyWithOpacity(double opacity) => grey600.withOpacity(opacity);
}

/// 字体大小常量
class FontSizes {
  // 私有构造函数
  FontSizes._();
  
  static const double xs = 10.0;
  static const double sm = 12.0;
  static const double base = 14.0;
  static const double lg = 16.0;
  static const double xl = 18.0;
  static const double xl2 = 20.0;
  static const double xl3 = 24.0;
  static const double xl4 = 30.0;
  static const double xl5 = 36.0;
  static const double xl6 = 48.0;
  static const double xl7 = 60.0;
  static const double xl8 = 72.0;
}

/// 间距常量
class Spacings {
  // 私有构造函数
  Spacings._();
  
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double base = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xl2 = 48.0;
  static const double xl3 = 64.0;
  static const double xl4 = 96.0;
  static const double xl5 = 128.0;
}

/// 断点常量
class Breakpoints {
  // 私有构造函数
  Breakpoints._();
  
  static const double xs = 0;
  static const double sm = 600;
  static const double md = 960;
  static const double lg = 1280;
  static const double xl = 1920;
}
