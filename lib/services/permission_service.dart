import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum PermissionType {
  camera,
  microphone,
  storage,
  location,
  phone,
  notifications,
}

class PermissionInfo {
  const PermissionInfo({
    required this.type,
    required this.status,
    required this.isGranted,
    required this.isPermanentlyDenied,
    this.reason,
  });

  final PermissionType type;
  final ph.PermissionStatus status;
  final bool isGranted;
  final bool isPermanentlyDenied;
  final String? reason;
}

class PermissionService {
  PermissionService._();
  static final PermissionService _instance = PermissionService._();
  factory PermissionService() => _instance;

  final Map<PermissionType, PermissionInfo> _permissionStatuses = <PermissionType, PermissionInfo>{};
  final StreamController<Map<PermissionType, PermissionInfo>> _permissionController = 
      StreamController<Map<PermissionType, PermissionInfo>>.broadcast();
  
  Stream<Map<PermissionType, PermissionInfo>> get permissionStream => _permissionController.stream;
  Map<PermissionType, PermissionInfo> get permissionStatuses => 
      Map<PermissionType, PermissionInfo>.unmodifiable(_permissionStatuses);

  Future<void> initialize() async {
    if (kIsWeb) {
      _log('Permission service: Web platform detected, permissions not required');
      return;
    }

    // 检查所有必需的权限
    await _checkAllPermissions();
    _permissionController.add(_permissionStatuses);
  }

  Future<void> _checkAllPermissions() async {
    final List<PermissionType> requiredPermissions = <PermissionType>[
      PermissionType.camera,
      PermissionType.microphone,
      PermissionType.storage,
      PermissionType.notifications,
    ];

    for (final PermissionType type in requiredPermissions) {
      await _checkPermission(type);
    }
  }

  Future<void> _checkPermission(PermissionType type) async {
    try {
      final ph.Permission permission = _getPermission(type);
      final ph.PermissionStatus status = await permission.status;
      
      _permissionStatuses[type] = PermissionInfo(
        type: type,
        status: status,
        isGranted: status.isGranted,
        isPermanentlyDenied: status.isPermanentlyDenied,
        reason: _getPermissionReason(type),
      );
      
      _log('Permission ${type.name}: ${status.name}');
    } catch (error) {
      _log('Failed to check permission ${type.name}: $error');
      _permissionStatuses[type] = PermissionInfo(
        type: type,
        status: ph.PermissionStatus.denied,
        isGranted: false,
        isPermanentlyDenied: false,
        reason: '检查失败: $error',
      );
    }
  }

  ph.Permission _getPermission(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return ph.Permission.camera;
      case PermissionType.microphone:
        return ph.Permission.microphone;
      case PermissionType.storage:
        if (Platform.isAndroid) {
          return Platform.version.startsWith('Android 13') 
              ? ph.Permission.photos 
              : ph.Permission.storage;
        }
        return ph.Permission.photos;
      case PermissionType.location:
        return ph.Permission.location;
      case PermissionType.phone:
        return ph.Permission.phone;
      case PermissionType.notifications:
        return ph.Permission.notification;
    }
  }

  String _getPermissionReason(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return '需要相机权限来拍摄照片和录制视频';
      case PermissionType.microphone:
        return '需要麦克风权限来录制音频';
      case PermissionType.storage:
        return '需要存储权限来保存照片、视频和日志文件';
      case PermissionType.location:
        return '需要位置权限来提供基于位置的服务';
      case PermissionType.phone:
        return '需要电话权限来获取设备信息';
      case PermissionType.notifications:
        return '需要通知权限来显示重要消息和提醒';
    }
  }

  Future<bool> requestPermission(PermissionType type) async {
    if (kIsWeb) {
      return true; // Web平台不需要权限请求
    }

    try {
      final ph.Permission permission = _getPermission(type);
      final ph.PermissionStatus status = await permission.request();
      
      // 更新权限状态
      await _checkPermission(type);
      _permissionController.add(_permissionStatuses);
      
      if (status.isGranted) {
        _log('Permission ${type.name} granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        _log('Permission ${type.name} permanently denied');
        return false;
      } else {
        _log('Permission ${type.name} denied');
        return false;
      }
    } catch (error) {
      _log('Failed to request permission ${type.name}: $error');
      return false;
    }
  }

  Future<bool> requestAllPermissions() async {
    if (kIsWeb) {
      return true;
    }

    final List<PermissionType> requiredPermissions = <PermissionType>[
      PermissionType.camera,
      PermissionType.microphone,
      PermissionType.storage,
      PermissionType.notifications,
    ];

    bool allGranted = true;
    
    for (final PermissionType type in requiredPermissions) {
      final bool granted = await requestPermission(type);
      if (!granted) {
        allGranted = false;
      }
    }
    
    return allGranted;
  }

  Future<bool> openAppSettings() async {
    try {
      final bool opened = await ph.openAppSettings();
      _log('App settings opened: $opened');
      return opened;
    } catch (error) {
      _log('Failed to open app settings: $error');
      return false;
    }
  }

  bool isPermissionGranted(PermissionType type) {
    return _permissionStatuses[type]?.isGranted ?? false;
  }

  bool areAllPermissionsGranted() {
    final List<PermissionType> requiredPermissions = <PermissionType>[
      PermissionType.camera,
      PermissionType.microphone,
      PermissionType.storage,
      PermissionType.notifications,
    ];
    
    return requiredPermissions.every((PermissionType type) => isPermissionGranted(type));
  }

  List<PermissionType> getDeniedPermissions() {
    return _permissionStatuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key)
        .toList();
  }

  List<PermissionType> getPermanentlyDeniedPermissions() {
    return _permissionStatuses.entries
        .where((entry) => entry.value.isPermanentlyDenied)
        .map((entry) => entry.key)
        .toList();
  }

  // 新增：获取权限摘要
  Map<String, dynamic> getPermissionSummary() {
    final int totalPermissions = _permissionStatuses.length;
    final int grantedCount = _permissionStatuses.values
        .where((status) => status.isGranted)
        .length;
    final int deniedCount = totalPermissions - grantedCount;
    final int permanentlyDeniedCount = _permissionStatuses.values
        .where((status) => status.isPermanentlyDenied)
        .length;
    
    return <String, dynamic>{
      'totalPermissions': totalPermissions,
      'grantedCount': grantedCount,
      'deniedCount': deniedCount,
      'permanentlyDeniedCount': permanentlyDeniedCount,
      'allGranted': areAllPermissionsGranted(),
      'deniedPermissions': getDeniedPermissions().map((type) => type.name).toList(),
      'permanentlyDeniedPermissions': getPermanentlyDeniedPermissions().map((type) => type.name).toList(),
    };
  }

  // 新增：检查特定功能权限
  Future<bool> canTakePhoto() async {
    return isPermissionGranted(PermissionType.camera) && 
           isPermissionGranted(PermissionType.storage);
  }

  Future<bool> canRecordVideo() async {
    return isPermissionGranted(PermissionType.camera) && 
           isPermissionGranted(PermissionType.microphone) &&
           isPermissionGranted(PermissionType.storage);
  }

  Future<bool> canRecordAudio() async {
    return isPermissionGranted(PermissionType.microphone) &&
           isPermissionGranted(PermissionType.storage);
  }

  Future<bool> canUploadFiles() async {
    return isPermissionGranted(PermissionType.storage);
  }

  Future<bool> canShowNotifications() async {
    return isPermissionGranted(PermissionType.notifications);
  }

  // 新增：权限状态监听
  Future<void> refreshPermissionStatus() async {
    await _checkAllPermissions();
    _permissionController.add(_permissionStatuses);
    _log('Permission status refreshed');
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[PermissionService] $message');
    }
  }

  void dispose() {
    _permissionController.close();
  }
}

// 全局权限实例
final PermissionService permissionService = PermissionService();
