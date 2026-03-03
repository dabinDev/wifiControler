import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceRole {
  controller,
  controlled,
  unknown,
}

enum PermissionLevel {
  guest,      // 访客：只能查看基本信息
  user,       // 用户：可以发送基本命令
  operator,   // 操作员：可以发送所有命令
  admin,      // 管理员：完全控制权限
}

class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.role,
    required this.permissionLevel,
    required this.publicKey,
    required this.createdAt,
    required this.lastSeen,
    this.ipAddress,
    this.description,
    this.isTrusted = false,
    this.isBlocked = false,
  });

  final String deviceId;
  final String deviceName;
  final DeviceRole role;
  final PermissionLevel permissionLevel;
  final String publicKey;
  final DateTime createdAt;
  final DateTime lastSeen;
  final String? ipAddress;
  final String? description;
  final bool isTrusted;
  final bool isBlocked;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'role': role.name,
      'permissionLevel': permissionLevel.name,
      'publicKey': publicKey,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'ipAddress': ipAddress,
      'description': description,
      'isTrusted': isTrusted,
      'isBlocked': isBlocked,
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      role: DeviceRole.values.firstWhere(
        (DeviceRole r) => r.name == json['role'],
        orElse: () => DeviceRole.unknown,
      ),
      permissionLevel: PermissionLevel.values.firstWhere(
        (PermissionLevel p) => p.name == json['permissionLevel'],
        orElse: () => PermissionLevel.guest,
      ),
      publicKey: json['publicKey'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int),
      ipAddress: json['ipAddress'] as String?,
      description: json['description'] as String?,
      isTrusted: json['isTrusted'] as bool? ?? false,
      isBlocked: json['isBlocked'] as bool? ?? false,
    );
  }
}

class AuthToken {
  const AuthToken({
    required this.token,
    required this.deviceId,
    required this.expiresAt,
    required this.permissionLevel,
  });

  final String token;
  final String deviceId;
  final DateTime expiresAt;
  final PermissionLevel permissionLevel;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'token': token,
      'deviceId': deviceId,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'permissionLevel': permissionLevel.name,
    };
  }

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      token: json['token'] as String,
      deviceId: json['deviceId'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int),
      permissionLevel: PermissionLevel.values.firstWhere(
        (PermissionLevel p) => p.name == json['permissionLevel'],
        orElse: () => PermissionLevel.guest,
      ),
    );
  }
}

class AuthenticationService {
  AuthenticationService._();
  static final AuthenticationService _instance = AuthenticationService._();
  factory AuthenticationService() => _instance;

  final Map<String, DeviceInfo> _knownDevices = <String, DeviceInfo>{};
  final Map<String, AuthToken> _activeTokens = <String, AuthToken>{};
  final Map<String, String> _deviceSecrets = <String, String>{};
  
  final StreamController<DeviceInfo> _deviceController = 
      StreamController<DeviceInfo>.broadcast();
  final StreamController<String> _authEventController = 
      StreamController<String>.broadcast();
  
  Stream<DeviceInfo> get deviceEvents => _deviceController.stream;
  Stream<String> get authEvents => _authEventController.stream;
  
  SharedPreferences? _prefs;
  String? _currentDeviceId;
  String? _currentDeviceSecret;
  DeviceInfo? _currentDeviceInfo;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // 加载已保存的设备信息
      await _loadKnownDevices();
      
      // 生成或加载当前设备信息
      await _initializeCurrentDevice();
      
      // 清理过期令牌
      _cleanupExpiredTokens();
      
      _log('Authentication service initialized');
    } catch (error) {
      _log('Failed to initialize authentication service: $error');
      rethrow;
    }
  }

  // 初始化当前设备
  Future<void> _initializeCurrentDevice() async {
    try {
      _currentDeviceId = _prefs?.getString('current_device_id');
      _currentDeviceSecret = _prefs?.getString('current_device_secret');
      
      if (_currentDeviceId == null || _currentDeviceSecret == null) {
        // 生成新设备信息
        _currentDeviceId = _generateDeviceId();
        _currentDeviceSecret = _generateSecret();
        
        await _prefs?.setString('current_device_id', _currentDeviceId!);
        await _prefs?.setString('current_device_secret', _currentDeviceSecret!);
      }
      
      // 创建或加载当前设备信息
      _currentDeviceInfo = _knownDevices[_currentDeviceId];
      if (_currentDeviceInfo == null) {
        _currentDeviceInfo = DeviceInfo(
          deviceId: _currentDeviceId!,
          deviceName: 'Device-${_currentDeviceId!.substring(0, 8)}',
          role: DeviceRole.unknown, // 将在设置角色时更新
          permissionLevel: PermissionLevel.user,
          publicKey: _generatePublicKey(_currentDeviceId!, _currentDeviceSecret!),
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        
        _knownDevices[_currentDeviceId!] = _currentDeviceInfo!;
        await _saveKnownDevices();
      }
      
      _deviceSecrets[_currentDeviceId!] = _currentDeviceSecret!;
      _log('Current device initialized: $_currentDeviceId');
    } catch (error) {
      _log('Failed to initialize current device: $error');
    }
  }

  // 设置设备角色
  Future<void> setDeviceRole(DeviceRole role) async {
    try {
      if (_currentDeviceInfo == null) return;
      
      _currentDeviceInfo = DeviceInfo(
        deviceId: _currentDeviceInfo!.deviceId,
        deviceName: _currentDeviceInfo!.deviceName,
        role: role,
        permissionLevel: _getDefaultPermissionLevel(role),
        publicKey: _currentDeviceInfo!.publicKey,
        createdAt: _currentDeviceInfo!.createdAt,
        lastSeen: DateTime.now(),
        ipAddress: _currentDeviceInfo!.ipAddress,
        description: _currentDeviceInfo!.description,
        isTrusted: _currentDeviceInfo!.isTrusted,
        isBlocked: _currentDeviceInfo!.isBlocked,
      );
      
      _knownDevices[_currentDeviceInfo!.deviceId] = _currentDeviceInfo!;
      await _saveKnownDevices();
      
      _authEventController.add('role_updated');
      _log('Device role set to: ${role.name}');
    } catch (error) {
      _log('Failed to set device role: $error');
    }
  }

  // 获取默认权限级别
  PermissionLevel _getDefaultPermissionLevel(DeviceRole role) {
    switch (role) {
      case DeviceRole.controller:
        return PermissionLevel.operator;
      case DeviceRole.controlled:
        return PermissionLevel.user;
      case DeviceRole.unknown:
        return PermissionLevel.guest;
    }
  }

  // 认证设备
  Future<AuthToken?> authenticateDevice(String deviceId, String signature, String timestamp) async {
    try {
      final DeviceInfo? deviceInfo = _knownDevices[deviceId];
      if (deviceInfo == null) {
        _log('Unknown device: $deviceId');
        return null;
      }

      if (deviceInfo.isBlocked) {
        _log('Blocked device attempted authentication: $deviceId');
        return null;
      }

      // 验证签名
      if (!_verifySignature(deviceId, signature, timestamp)) {
        _log('Invalid signature for device: $deviceId');
        return null;
      }

      // 检查时间戳（防止重放攻击）
      final int requestTime = int.parse(timestamp);
      final int currentTime = DateTime.now().millisecondsSinceEpoch;
      if ((currentTime - requestTime).abs() > 30000) { // 30秒窗口
        _log('Timestamp out of range for device: $deviceId');
        return null;
      }

      // 生成令牌
      final AuthToken token = _generateToken(deviceInfo);
      _activeTokens[token.token] = token;
      
      // 更新设备最后活跃时间
      final DeviceInfo updatedDevice = DeviceInfo(
        deviceId: deviceInfo.deviceId,
        deviceName: deviceInfo.deviceName,
        role: deviceInfo.role,
        permissionLevel: deviceInfo.permissionLevel,
        publicKey: deviceInfo.publicKey,
        createdAt: deviceInfo.createdAt,
        lastSeen: DateTime.now(),
        ipAddress: deviceInfo.ipAddress,
        description: deviceInfo.description,
        isTrusted: deviceInfo.isTrusted,
        isBlocked: deviceInfo.isBlocked,
      );
      
      _knownDevices[deviceId] = updatedDevice;
      await _saveKnownDevices();
      
      _deviceController.add(updatedDevice);
      _authEventController.add('device_authenticated');
      
      _log('Device authenticated: $deviceId');
      return token;
    } catch (error) {
      _log('Failed to authenticate device: $error');
      return null;
    }
  }

  // 验证令牌
  bool verifyToken(String token, String? requiredPermission) {
    try {
      final AuthToken? authToken = _activeTokens[token];
      if (authToken == null) {
        _log('Token not found: $token');
        return false;
      }

      if (authToken.isExpired) {
        _activeTokens.remove(token);
        _log('Token expired: $token');
        return false;
      }

      // 检查权限
      if (requiredPermission != null) {
        return _hasPermission(authToken.permissionLevel, requiredPermission);
      }

      return true;
    } catch (error) {
      _log('Failed to verify token: $error');
      return false;
    }
  }

  // 检查权限
  bool _hasPermission(PermissionLevel userLevel, String requiredPermission) {
    final Map<String, List<PermissionLevel>> permissionMap = <String, List<PermissionLevel>>{
      'view_info': <PermissionLevel>[PermissionLevel.guest, PermissionLevel.user, PermissionLevel.operator, PermissionLevel.admin],
      'send_basic_commands': <PermissionLevel>[PermissionLevel.user, PermissionLevel.operator, PermissionLevel.admin],
      'send_all_commands': <PermissionLevel>[PermissionLevel.operator, PermissionLevel.admin],
      'manage_devices': <PermissionLevel>[PermissionLevel.admin],
      'system_config': <PermissionLevel>[PermissionLevel.admin],
    };

    final List<PermissionLevel>? allowedLevels = permissionMap[requiredPermission];
    if (allowedLevels == null) {
      return false; // 未知权限
    }

    return allowedLevels.contains(userLevel);
  }

  // 生成签名
  String generateSignature(String timestamp) {
    if (_currentDeviceId == null || _currentDeviceSecret == null) {
      return '';
    }

    final String data = '$_currentDeviceId:$timestamp';
    final String secret = _currentDeviceSecret!;
    final Hmac hmac = Hmac(sha256, utf8.encode(secret));
    final Digest digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  // 验证签名
  bool _verifySignature(String deviceId, String signature, String timestamp) {
    try {
      final String? secret = _deviceSecrets[deviceId];
      if (secret == null) {
        return false;
      }

      final String data = '$deviceId:$timestamp';
      final Hmac hmac = Hmac(sha256, utf8.encode(secret));
      final Digest expectedDigest = hmac.convert(utf8.encode(data));
      final String expectedSignature = expectedDigest.toString();

      return signature == expectedSignature;
    } catch (error) {
      _log('Failed to verify signature: $error');
      return false;
    }
  }

  // 添加信任设备
  Future<void> addTrustedDevice(DeviceInfo deviceInfo) async {
    try {
      final DeviceInfo trustedDevice = DeviceInfo(
        deviceId: deviceInfo.deviceId,
        deviceName: deviceInfo.deviceName,
        role: deviceInfo.role,
        permissionLevel: deviceInfo.permissionLevel,
        publicKey: deviceInfo.publicKey,
        createdAt: deviceInfo.createdAt,
        lastSeen: DateTime.now(),
        ipAddress: deviceInfo.ipAddress,
        description: deviceInfo.description,
        isTrusted: true,
        isBlocked: false,
      );
      
      _knownDevices[deviceInfo.deviceId] = trustedDevice;
      await _saveKnownDevices();
      
      _deviceController.add(trustedDevice);
      _authEventController.add('trusted_device_added');
      
      _log('Trusted device added: ${deviceInfo.deviceId}');
    } catch (error) {
      _log('Failed to add trusted device: $error');
    }
  }

  // 阻止设备
  Future<void> blockDevice(String deviceId) async {
    try {
      final DeviceInfo? deviceInfo = _knownDevices[deviceId];
      if (deviceInfo == null) return;
      
      final DeviceInfo blockedDevice = DeviceInfo(
        deviceId: deviceInfo.deviceId,
        deviceName: deviceInfo.deviceName,
        role: deviceInfo.role,
        permissionLevel: deviceInfo.permissionLevel,
        publicKey: deviceInfo.publicKey,
        createdAt: deviceInfo.createdAt,
        lastSeen: deviceInfo.lastSeen,
        ipAddress: deviceInfo.ipAddress,
        description: deviceInfo.description,
        isTrusted: deviceInfo.isTrusted,
        isBlocked: true,
      );
      
      _knownDevices[deviceId] = blockedDevice;
      await _saveKnownDevices();
      
      // 移除该设备的所有活动令牌
      _activeTokens.removeWhere((String token, AuthToken authToken) => authToken.deviceId == deviceId);
      
      _deviceController.add(blockedDevice);
      _authEventController.add('device_blocked');
      
      _log('Device blocked: $deviceId');
    } catch (error) {
      _log('Failed to block device: $error');
    }
  }

  // 生成令牌
  AuthToken _generateToken(DeviceInfo deviceInfo) {
    final String tokenData = '${deviceInfo.deviceId}:${DateTime.now().millisecondsSinceEpoch}:${Random().nextInt(1000000)}';
    final String token = sha256.convert(utf8.encode(tokenData)).toString();
    
    return AuthToken(
      token: token,
      deviceId: deviceInfo.deviceId,
      expiresAt: DateTime.now().add(const Duration(hours: 24)), // 24小时有效期
      permissionLevel: deviceInfo.permissionLevel,
    );
  }

  // 生成设备ID
  String _generateDeviceId() {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String random = Random().nextInt(10000).toString().padLeft(4, '0');
    final String deviceData = '$timestamp:$random';
    return sha256.convert(utf8.encode(deviceData)).toString().substring(0, 16);
  }

  // 生成密钥
  String _generateSecret() {
    final String randomData = '${Random().nextInt(1000000)}:${DateTime.now().millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(randomData)).toString();
  }

  // 生成公钥
  String _generatePublicKey(String deviceId, String secret) {
    final String keyData = '$deviceId:$secret';
    return sha256.convert(utf8.encode(keyData)).toString();
  }

  // 清理过期令牌
  void _cleanupExpiredTokens() {
    final List<String> expiredTokens = <String>[];
    
    _activeTokens.forEach((String token, AuthToken authToken) {
      if (authToken.isExpired) {
        expiredTokens.add(token);
      }
    });
    
    for (final String token in expiredTokens) {
      _activeTokens.remove(token);
    }
    
    if (expiredTokens.isNotEmpty) {
      _log('Cleaned up ${expiredTokens.length} expired tokens');
    }
  }

  // 获取已知设备列表
  List<DeviceInfo> getKnownDevices() {
    return _knownDevices.values.toList();
  }

  // 获取信任设备列表
  List<DeviceInfo> getTrustedDevices() {
    return _knownDevices.values
        .where((DeviceInfo device) => device.isTrusted && !device.isBlocked)
        .toList();
  }

  // 获取被阻止设备列表
  List<DeviceInfo> getBlockedDevices() {
    return _knownDevices.values
        .where((DeviceInfo device) => device.isBlocked)
        .toList();
  }

  // 获取当前设备信息
  DeviceInfo? getCurrentDeviceInfo() {
    return _currentDeviceInfo;
  }

  // 获取当前设备ID
  String? getCurrentDeviceId() {
    return _currentDeviceId;
  }

  // 保存已知设备
  Future<void> _saveKnownDevices() async {
    try {
      final List<Map<String, dynamic>> devicesJson = _knownDevices.values
          .map((DeviceInfo device) => device.toJson())
          .toList();
      
      await _prefs?.setString('known_devices', jsonEncode(devicesJson));
    } catch (error) {
      _log('Failed to save known devices: $error');
    }
  }

  // 加载已知设备
  Future<void> _loadKnownDevices() async {
    try {
      final String? devicesJson = _prefs?.getString('known_devices');
      if (devicesJson != null) {
        final List<dynamic> devicesList = jsonDecode(devicesJson) as List<dynamic>;
        
        for (final dynamic deviceJson in devicesList) {
          final DeviceInfo device = DeviceInfo.fromJson(deviceJson as Map<String, dynamic>);
          _knownDevices[device.deviceId] = device;
        }
      }
      
      _log('Loaded ${_knownDevices.length} known devices');
    } catch (error) {
      _log('Failed to load known devices: $error');
    }
  }

  // 获取认证统计
  Map<String, dynamic> getAuthStats() {
    return <String, dynamic>{
      'totalDevices': _knownDevices.length,
      'trustedDevices': getTrustedDevices().length,
      'blockedDevices': getBlockedDevices().length,
      'activeTokens': _activeTokens.length,
      'currentDeviceId': _currentDeviceId,
      'currentDeviceRole': _currentDeviceInfo?.role.name,
    };
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[AuthService] $message');
    }
  }

  void dispose() {
    _deviceController.close();
    _authEventController.close();
  }
}

// 全局认证服务实例
final AuthenticationService authService = AuthenticationService();
