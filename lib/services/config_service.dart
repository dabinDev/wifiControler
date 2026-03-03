import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppConfig {
  const AppConfig({
    required this.udpPort,
    required this.serverUrl,
    required this.deviceToken,
    required this.enableEncryption,
    required this.encryptionKey,
    required this.commandTimeout,
    required this.maxRetries,
    required this.heartbeatInterval,
    required this.deviceCleanupInterval,
    required this.logRetentionDays,
    required this.enableNetworkStats,
    required this.enableRealDeviceStatus,
    required this.enableCommandHistory,
    required this.maxLogEntries,
  });

  final int udpPort;
  final String serverUrl;
  final String deviceToken;
  final bool enableEncryption;
  final String encryptionKey;
  final int commandTimeout; // seconds
  final int maxRetries;
  final int heartbeatInterval; // seconds
  final int deviceCleanupInterval; // seconds
  final int logRetentionDays;
  final bool enableNetworkStats;
  final bool enableRealDeviceStatus;
  final bool enableCommandHistory;
  final int maxLogEntries;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'udpPort': udpPort,
        'serverUrl': serverUrl,
        'deviceToken': deviceToken,
        'enableEncryption': enableEncryption,
        'encryptionKey': encryptionKey,
        'commandTimeout': commandTimeout,
        'maxRetries': maxRetries,
        'heartbeatInterval': heartbeatInterval,
        'deviceCleanupInterval': deviceCleanupInterval,
        'logRetentionDays': logRetentionDays,
        'enableNetworkStats': enableNetworkStats,
        'enableRealDeviceStatus': enableRealDeviceStatus,
        'enableCommandHistory': enableCommandHistory,
        'maxLogEntries': maxLogEntries,
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        udpPort: json['udpPort'] as int? ?? 50001,
        serverUrl: json['serverUrl'] as String? ?? 'https://your-server.example.com/api',
        deviceToken: json['deviceToken'] as String? ?? 'default-device-token',
        enableEncryption: json['enableEncryption'] as bool? ?? false,
        encryptionKey: json['encryptionKey'] as String? ?? 'default-encryption-key',
        commandTimeout: json['commandTimeout'] as int? ?? 30,
        maxRetries: json['maxRetries'] as int? ?? 3,
        heartbeatInterval: json['heartbeatInterval'] as int? ?? 3,
        deviceCleanupInterval: json['deviceCleanupInterval'] as int? ?? 15,
        logRetentionDays: json['logRetentionDays'] as int? ?? 7,
        enableNetworkStats: json['enableNetworkStats'] as bool? ?? true,
        enableRealDeviceStatus: json['enableRealDeviceStatus'] as bool? ?? true,
        enableCommandHistory: json['enableCommandHistory'] as bool? ?? true,
        maxLogEntries: json['maxLogEntries'] as int? ?? 1000,
      );

  AppConfig copyWith({
    int? udpPort,
    String? serverUrl,
    String? deviceToken,
    bool? enableEncryption,
    String? encryptionKey,
    int? commandTimeout,
    int? maxRetries,
    int? heartbeatInterval,
    int? deviceCleanupInterval,
    int? logRetentionDays,
    bool? enableNetworkStats,
    bool? enableRealDeviceStatus,
    bool? enableCommandHistory,
    int? maxLogEntries,
  }) {
    return AppConfig(
      udpPort: udpPort ?? this.udpPort,
      serverUrl: serverUrl ?? this.serverUrl,
      deviceToken: deviceToken ?? this.deviceToken,
      enableEncryption: enableEncryption ?? this.enableEncryption,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      commandTimeout: commandTimeout ?? this.commandTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
      deviceCleanupInterval: deviceCleanupInterval ?? this.deviceCleanupInterval,
      logRetentionDays: logRetentionDays ?? this.logRetentionDays,
      enableNetworkStats: enableNetworkStats ?? this.enableNetworkStats,
      enableRealDeviceStatus: enableRealDeviceStatus ?? this.enableRealDeviceStatus,
      enableCommandHistory: enableCommandHistory ?? this.enableCommandHistory,
      maxLogEntries: maxLogEntries ?? this.maxLogEntries,
    );
  }

  @override
  String toString() {
    return 'AppConfig(udpPort: $udpPort, serverUrl: $serverUrl, enableEncryption: $enableEncryption)';
  }
}

class ConfigService {
  ConfigService._();
  static final ConfigService _instance = ConfigService._();
  factory ConfigService() => _instance;

  AppConfig? _config;
  final StreamController<AppConfig> _configController = StreamController<AppConfig>.broadcast();
  File? _configFile;

  Stream<AppConfig> get configStream => _configController.stream;
  AppConfig get config {
    return _config ?? const AppConfig(
      udpPort: 50001,
      serverUrl: 'https://your-server.example.com/api',
      deviceToken: 'default-device-token',
      enableEncryption: false,
      encryptionKey: 'default-encryption-key',
      commandTimeout: 30,
      maxRetries: 3,
      heartbeatInterval: 3,
      deviceCleanupInterval: 15,
      logRetentionDays: 7,
      enableNetworkStats: true,
      enableRealDeviceStatus: true,
      enableCommandHistory: true,
      maxLogEntries: 1000,
    );
  }

  Future<void> initialize() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      _configFile = File('${appDocDir.path}/app_config.json');
      
      if (await _configFile!.exists()) {
        final String content = await _configFile!.readAsString();
        final Map<String, dynamic> json = jsonDecode(content) as Map<String, dynamic>;
        _config = AppConfig.fromJson(json);
        _log('Config loaded from file: ${_configFile!.path}');
      } else {
        _config = config; // 使用默认配置
        await saveConfig(_config!);
        _log('Default config created and saved');
      }
      
      _configController.add(_config!);
    } catch (error) {
      _log('Failed to initialize config: $error');
      _config = config; // 使用默认配置
      _configController.add(_config!);
    }
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    try {
      _config = newConfig;
      await saveConfig(_config!);
      _configController.add(_config!);
      _log('Config updated: ${_config!.toString()}');
    } catch (error) {
      _log('Failed to update config: $error');
      rethrow;
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    if (_configFile == null) {
      throw StateError('Config service not initialized');
    }
    
    try {
      final String jsonContent = jsonEncode(config.toJson());
      await _configFile!.writeAsString(jsonContent);
      _log('Config saved to file: ${_configFile!.path}');
    } catch (error) {
      _log('Failed to save config: $error');
      rethrow;
    }
  }

  Future<void> resetToDefaults() async {
    final AppConfig defaultConfig = const AppConfig(
      udpPort: 50001,
      serverUrl: 'https://your-server.example.com/api',
      deviceToken: 'default-device-token',
      enableEncryption: false,
      encryptionKey: 'default-encryption-key',
      commandTimeout: 30,
      maxRetries: 3,
      heartbeatInterval: 3,
      deviceCleanupInterval: 15,
      logRetentionDays: 7,
      enableNetworkStats: true,
      enableRealDeviceStatus: true,
      enableCommandHistory: true,
      maxLogEntries: 1000,
    );
    
    await updateConfig(defaultConfig);
    _log('Config reset to defaults');
  }

  Future<void> exportConfig(String filePath) async {
    if (_config == null) {
      throw StateError('No config to export');
    }
    
    try {
      final File exportFile = File(filePath);
      final String jsonContent = const JsonEncoder.withIndent('  ').convert(_config!.toJson());
      await exportFile.writeAsString(jsonContent);
      _log('Config exported to: $filePath');
    } catch (error) {
      _log('Failed to export config: $error');
      rethrow;
    }
  }

  Future<void> importConfig(String filePath) async {
    try {
      final File importFile = File(filePath);
      final String content = await importFile.readAsString();
      final Map<String, dynamic> json = jsonDecode(content) as Map<String, dynamic>;
      final AppConfig importedConfig = AppConfig.fromJson(json);
      
      await updateConfig(importedConfig);
      _log('Config imported from: $filePath');
    } catch (error) {
      _log('Failed to import config: $error');
      rethrow;
    }
  }

  // 新增：获取配置摘要
  Map<String, dynamic> getConfigSummary() {
    final AppConfig cfg = _config ?? config;
    return <String, dynamic>{
      'network': <String, dynamic>{
        'udpPort': cfg.udpPort,
        'serverUrl': cfg.serverUrl,
        'enableEncryption': cfg.enableEncryption,
        'enableNetworkStats': cfg.enableNetworkStats,
      },
      'security': <String, dynamic>{
        'deviceToken': cfg.deviceToken.substring(0, 8) + '...',
        'encryptionKey': cfg.encryptionKey.substring(0, 4) + '...',
      },
      'performance': <String, dynamic>{
        'commandTimeout': '${cfg.commandTimeout}s',
        'maxRetries': cfg.maxRetries,
        'heartbeatInterval': '${cfg.heartbeatInterval}s',
      },
      'features': <String, dynamic>{
        'enableRealDeviceStatus': cfg.enableRealDeviceStatus,
        'enableCommandHistory': cfg.enableCommandHistory,
        'maxLogEntries': cfg.maxLogEntries,
      },
      'maintenance': <String, dynamic>{
        'deviceCleanupInterval': '${cfg.deviceCleanupInterval}s',
        'logRetentionDays': '${cfg.logRetentionDays}天',
      },
    };
  }

  // 新增：验证配置
  List<String> validateConfig(AppConfig config) {
    final List<String> errors = <String>[];
    
    if (config.udpPort < 1024 || config.udpPort > 65535) {
      errors.add('UDP端口必须在1024-65535范围内');
    }
    
    if (!Uri.tryParse(config.serverUrl)!.hasAbsolutePath) {
      errors.add('服务器URL格式无效');
    }
    
    if (config.deviceToken.length < 8) {
      errors.add('设备令牌长度至少8位');
    }
    
    if (config.enableEncryption && config.encryptionKey.length < 8) {
      errors.add('启用加密时，加密密钥长度至少8位');
    }
    
    if (config.commandTimeout < 5 || config.commandTimeout > 300) {
      errors.add('命令超时时间必须在5-300秒范围内');
    }
    
    if (config.maxRetries < 0 || config.maxRetries > 10) {
      errors.add('重试次数必须在0-10范围内');
    }
    
    if (config.heartbeatInterval < 1 || config.heartbeatInterval > 60) {
      errors.add('心跳间隔必须在1-60秒范围内');
    }
    
    if (config.maxLogEntries < 100 || config.maxLogEntries > 10000) {
      errors.add('最大日志条数必须在100-10000范围内');
    }
    
    return errors;
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[ConfigService] $message');
    }
  }

  void dispose() {
    _configController.close();
  }
}
