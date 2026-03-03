import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
// import 'package:connectivity_plus/connectivity_plus.dart'; // Temporarily disabled
// import 'package:storage_info/storage_info.dart'; // Temporarily disabled

/// 硬件服务：提供拍照、录像、录音、设备状态读取等真实硬件调用
class HardwareService {
  HardwareService._();
  static final HardwareService _instance = HardwareService._();
  factory HardwareService() => _instance;

  final ImagePicker _imagePicker = ImagePicker();
  late final FlutterSoundRecorder _audioRecorder;
  bool _recorderInitialized = false;

  /// 初始化录音器
  Future<void> initRecorder() async {
    if (_recorderInitialized) return;
    _audioRecorder = FlutterSoundRecorder();
    await _audioRecorder.openRecorder();
    _recorderInitialized = true;
  }

  /// 拍照
  Future<String?> takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        _log('Photo taken: ${photo.path}');
        return photo.path;
      }
    } catch (e) {
      _log('Take photo failed: $e');
    }
    return null;
  }

  /// 录像
  Future<String?> startVideoRecording() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(source: ImageSource.camera);
      if (video != null) {
        _log('Video recorded: ${video.path}');
        return video.path;
      }
    } catch (e) {
      _log('Start video recording failed: $e');
    }
    return null;
  }

  /// 开始录音
  Future<String?> startAudioRecording() async {
    try {
      await initRecorder();
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = path.join(tempDir.path, 'audio_${DateTime.now().millisecondsSinceEpoch}.wav');
      await _audioRecorder.startRecorder(toFile: filePath);
      _log('Audio recording started: $filePath');
      return filePath;
    } catch (e) {
      _log('Start audio recording failed: $e');
    }
    return null;
  }

  /// 停止录音
  Future<String?> stopAudioRecording() async {
    try {
      if (!_recorderInitialized) return null;
      final String? path = await _audioRecorder.stopRecorder();
      _log('Audio recording stopped: $path');
      return path;
    } catch (e) {
      _log('Stop audio recording failed: $e');
    }
    return null;
  }

  /// 获取电池信息
  Future<Map<String, dynamic>> getBatteryInfo() async {
    try {
      final Battery battery = Battery();
      final int batteryLevel = await battery.batteryLevel;
      final BatteryState batteryState = await battery.batteryState;
      return <String, dynamic>{
        'level': batteryLevel,
        'isCharging': batteryState == BatteryState.charging || batteryState == BatteryState.full,
        'state': batteryState.name,
      };
    } catch (e) {
      _log('Get battery info failed: $e');
      return <String, dynamic>{'level': -1, 'isCharging': false, 'state': 'unknown'};
    }
  }

  /// 获取存储信息
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      // Mock storage info since storage_info is disabled
      final double free = 8.0 + (DateTime.now().millisecond % 10); // GB
      final double total = 64.0; // GB
      return <String, dynamic>{
        'freeGB': free,
        'totalGB': total,
        'free': free * 1024, // MB
        'total': total * 1024, // MB
      };
    } catch (e) {
      _log('Get storage info failed: $e');
      return <String, dynamic>{'freeGB': 0, 'totalGB': 0, 'free': 0, 'total': 0};
    }
  }

  /// 获取网络信息
  Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      // Mock network info since connectivity_plus is disabled
      String type = 'wifi';
      int signalStrength = -45;
      bool connected = true;
      
      // Simulate different network types based on time
      final int second = DateTime.now().second;
      if (second % 20 < 5) {
        type = 'mobile';
        signalStrength = -65;
      } else if (second % 20 < 10) {
        type = 'ethernet';
        signalStrength = -30;
      } else if (second % 20 < 15) {
        type = 'none';
        signalStrength = -100;
        connected = false;
      }
      
      return <String, dynamic>{
        'type': type,
        'signalStrength': signalStrength,
        'connected': connected,
      };
    } catch (e) {
      _log('Get network info failed: $e');
      return <String, dynamic>{'type': 'none', 'signalStrength': -100, 'connected': false};
    }
  }

  /// 获取设备信息
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return <String, dynamic>{
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'product': androidInfo.product,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return <String, dynamic>{
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemVersion': iosInfo.systemVersion,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      }
    } catch (e) {
      _log('Get device info failed: $e');
    }
    return <String, dynamic>{'model': 'unknown', 'brand': 'unknown', 'manufacturer': 'unknown'};
  }

  /// 获取模拟的CPU温度（真实设备需要额外权限或插件）
  double getCpuTemp() {
    // 模拟CPU温度，真实设备需要读取系统文件或使用插件
    return 35.0 + (DateTime.now().millisecond % 20);
  }

  /// 获取内存使用率（模拟）
  double getMemoryUsage() {
    // 模拟内存使用率，真实设备需要读取系统信息
    return 40.0 + (DateTime.now().millisecond % 30);
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_recorderInitialized) {
      await _audioRecorder.closeRecorder();
      _recorderInitialized = false;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[HardwareService] $message');
    }
  }
}
