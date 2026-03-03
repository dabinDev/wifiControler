import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._();

  static const String _keyUdpPort = 'udp_port';
  static const String _keyServerBaseUrl = 'server_base_url';
  static const String _keyDeviceToken = 'device_token';
  static const String _keyHeartbeatInterval = 'heartbeat_interval';
  static const String _keyDeviceCleanupInterval = 'device_cleanup_interval';
  static const String _keyMaxLogEntries = 'max_log_entries';
  static const String _keyMaxMessageBucketSize = 'max_message_bucket_size';
  static const String _keyEnableEncryption = 'enable_encryption';
  static const String _keyConnectionTimeout = 'connection_timeout';
  static const String _keyRetryAttempts = 'retry_attempts';

  // 默认配置
  static const int defaultUdpPort = 50001;
  static const String defaultServerBaseUrl = 'https://your-server.example.com/api';
  static const String defaultDeviceToken = 'replace-with-device-token';
  static const int defaultHeartbeatInterval = 3;
  static const int defaultDeviceCleanupInterval = 15;
  static const int defaultMaxLogEntries = 200;
  static const int defaultMaxMessageBucketSize = 120;
  static const bool defaultEnableEncryption = false;
  static const int defaultConnectionTimeout = 5000;
  static const int defaultRetryAttempts = 3;

  static late SharedPreferences _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // UDP端口配置
  static int get udpPort => _prefs.getInt(_keyUdpPort) ?? defaultUdpPort;
  static Future<void> setUdpPort(int port) async {
    await _prefs.setInt(_keyUdpPort, port);
  }

  // 服务器基础URL
  static String get serverBaseUrl => _prefs.getString(_keyServerBaseUrl) ?? defaultServerBaseUrl;
  static Future<void> setServerBaseUrl(String url) async {
    await _prefs.setString(_keyServerBaseUrl, url);
  }

  // 设备Token
  static String get deviceToken => _prefs.getString(_keyDeviceToken) ?? defaultDeviceToken;
  static Future<void> setDeviceToken(String token) async {
    await _prefs.setString(_keyDeviceToken, token);
  }

  // 心跳间隔（秒）
  static int get heartbeatInterval => _prefs.getInt(_keyHeartbeatInterval) ?? defaultHeartbeatInterval;
  static Future<void> setHeartbeatInterval(int interval) async {
    await _prefs.setInt(_keyHeartbeatInterval, interval);
  }

  // 设备清理间隔（秒）
  static int get deviceCleanupInterval => _prefs.getInt(_keyDeviceCleanupInterval) ?? defaultDeviceCleanupInterval;
  static Future<void> setDeviceCleanupInterval(int interval) async {
    await _prefs.setInt(_keyDeviceCleanupInterval, interval);
  }

  // 最大日志条数
  static int get maxLogEntries => _prefs.getInt(_keyMaxLogEntries) ?? defaultMaxLogEntries;
  static Future<void> setMaxLogEntries(int count) async {
    await _prefs.setInt(_keyMaxLogEntries, count);
  }

  // 最大消息桶大小
  static int get maxMessageBucketSize => _prefs.getInt(_keyMaxMessageBucketSize) ?? defaultMaxMessageBucketSize;
  static Future<void> setMaxMessageBucketSize(int size) async {
    await _prefs.setInt(_keyMaxMessageBucketSize, size);
  }

  // 是否启用加密
  static bool get enableEncryption => _prefs.getBool(_keyEnableEncryption) ?? defaultEnableEncryption;
  static Future<void> setEnableEncryption(bool enabled) async {
    await _prefs.setBool(_keyEnableEncryption, enabled);
  }

  // 连接超时时间（毫秒）
  static int get connectionTimeout => _prefs.getInt(_keyConnectionTimeout) ?? defaultConnectionTimeout;
  static Future<void> setConnectionTimeout(int timeout) async {
    await _prefs.setInt(_keyConnectionTimeout, timeout);
  }

  // 重试次数
  static int get retryAttempts => _prefs.getInt(_keyRetryAttempts) ?? defaultRetryAttempts;
  static Future<void> setRetryAttempts(int attempts) async {
    await _prefs.setInt(_keyRetryAttempts, attempts);
  }

  // 重置所有配置到默认值
  static Future<void> resetToDefaults() async {
    await _prefs.clear();
  }

  // 导出配置为JSON
  static String exportConfig() {
    final Map<String, dynamic> config = <String, dynamic>{
      'udpPort': udpPort,
      'serverBaseUrl': serverBaseUrl,
      'deviceToken': deviceToken,
      'heartbeatInterval': heartbeatInterval,
      'deviceCleanupInterval': deviceCleanupInterval,
      'maxLogEntries': maxLogEntries,
      'maxMessageBucketSize': maxMessageBucketSize,
      'enableEncryption': enableEncryption,
      'connectionTimeout': connectionTimeout,
      'retryAttempts': retryAttempts,
    };
    return jsonEncode(config);
  }

  // 从JSON导入配置
  static Future<void> importConfig(String configJson) async {
    try {
      final Map<String, dynamic> config = jsonDecode(configJson) as Map<String, dynamic>;
      
      if (config['udpPort'] != null) await setUdpPort(config['udpPort'] as int);
      if (config['serverBaseUrl'] != null) await setServerBaseUrl(config['serverBaseUrl'] as String);
      if (config['deviceToken'] != null) await setDeviceToken(config['deviceToken'] as String);
      if (config['heartbeatInterval'] != null) await setHeartbeatInterval(config['heartbeatInterval'] as int);
      if (config['deviceCleanupInterval'] != null) await setDeviceCleanupInterval(config['deviceCleanupInterval'] as int);
      if (config['maxLogEntries'] != null) await setMaxLogEntries(config['maxLogEntries'] as int);
      if (config['maxMessageBucketSize'] != null) await setMaxMessageBucketSize(config['maxMessageBucketSize'] as int);
      if (config['enableEncryption'] != null) await setEnableEncryption(config['enableEncryption'] as bool);
      if (config['connectionTimeout'] != null) await setConnectionTimeout(config['connectionTimeout'] as int);
      if (config['retryAttempts'] != null) await setRetryAttempts(config['retryAttempts'] as int);
    } catch (e) {
      throw Exception('配置导入失败: $e');
    }
  }

  // 获取所有配置的摘要
  static Map<String, dynamic> getConfigSummary() {
    return <String, dynamic>{
      'udpPort': udpPort,
      'serverBaseUrl': serverBaseUrl,
      'heartbeatInterval': heartbeatInterval,
      'deviceCleanupInterval': deviceCleanupInterval,
      'maxLogEntries': maxLogEntries,
      'enableEncryption': enableEncryption,
      'connectionTimeout': connectionTimeout,
      'retryAttempts': retryAttempts,
    };
  }
}
