import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 简化版硬件服务：提供模拟的硬件功能
class HardwareService {
  HardwareService._();
  static final HardwareService _instance = HardwareService._();
  factory HardwareService() => _instance;

  bool _recorderInitialized = false;

  /// 初始化录音器（模拟）
  Future<void> initRecorder() async {
    if (_recorderInitialized) return;
    await Future.delayed(const Duration(milliseconds: 100));
    _recorderInitialized = true;
    _log('录音器初始化完成（模拟）');
  }

  /// 拍照（模拟）
  Future<String?> takePhoto() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final String photoPath = '/mock/photos/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      _log('拍照成功（模拟）: $photoPath');
      return photoPath;
    } catch (e) {
      _log('拍照失败（模拟）: $e');
    }
    return null;
  }

  /// 录像（模拟）
  Future<String?> startVideoRecording() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final String videoPath = '/mock/videos/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      _log('录像开始（模拟）: $videoPath');
      return videoPath;
    } catch (e) {
      _log('录像开始失败（模拟）: $e');
    }
    return null;
  }

  /// 开始录音（模拟）
  Future<String?> startAudioRecording() async {
    try {
      await initRecorder();
      await Future.delayed(const Duration(milliseconds: 200));
      final String audioPath = '/mock/audio/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      _log('录音开始（模拟）: $audioPath');
      return audioPath;
    } catch (e) {
      _log('录音开始失败（模拟）: $e');
    }
    return null;
  }

  /// 停止录音（模拟）
  Future<String?> stopAudioRecording() async {
    try {
      if (!_recorderInitialized) return null;
      await Future.delayed(const Duration(milliseconds: 100));
      final String audioPath = '/mock/audio/audio_${DateTime.now().millisecondsSinceEpoch}_finished.wav';
      _log('录音停止（模拟）: $audioPath');
      return audioPath;
    } catch (e) {
      _log('录音停止失败（模拟）: $e');
    }
    return null;
  }

  /// 获取电池信息（模拟）
  Future<Map<String, dynamic>> getBatteryInfo() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final int batteryLevel = 60 + Random().nextInt(40);
    final bool isCharging = Random().nextBool();
    return <String, dynamic>{
      'level': batteryLevel,
      'isCharging': isCharging,
      'state': isCharging ? 'charging' : 'discharging',
    };
  }

  /// 获取存储信息（模拟）
  Future<Map<String, dynamic>> getStorageInfo() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final double free = 8.0 + Random().nextDouble() * 20;
    final double total = 64.0;
    return <String, dynamic>{
      'freeGB': free,
      'totalGB': total,
      'free': free * 1024,
      'total': total * 1024,
    };
  }

  /// 获取网络信息（模拟）
  Future<Map<String, dynamic>> getNetworkInfo() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final List<String> types = ['wifi', 'mobile', 'ethernet'];
    final String type = types[Random().nextInt(types.length)];
    final int signalStrength = -30 - Random().nextInt(50);
    return <String, dynamic>{
      'type': type,
      'signalStrength': signalStrength,
      'connected': true,
    };
  }

  /// 获取设备信息（模拟）
  Future<Map<String, dynamic>> getDeviceInfo() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return <String, dynamic>{
      'model': 'Mock Device',
      'brand': 'MockBrand',
      'manufacturer': 'MockManufacturer',
      'product': 'mock_product',
      'androidVersion': '13.0',
      'sdkInt': 33,
      'isPhysicalDevice': true,
    };
  }

  /// 获取模拟的CPU温度
  double getCpuTemp() {
    return 35.0 + Random().nextDouble() * 25;
  }

  /// 获取内存使用率（模拟）
  double getMemoryUsage() {
    return 30.0 + Random().nextDouble() * 40;
  }

  /// 释放资源
  Future<void> dispose() async {
    _recorderInitialized = false;
    _log('硬件服务已释放');
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[HardwareService] $message');
    }
  }
}
