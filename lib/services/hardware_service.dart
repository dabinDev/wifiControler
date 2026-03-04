import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// 硬件服务：真实相机/录像/录音，本地保存文件
class HardwareService {
  HardwareService._();
  static final HardwareService _instance = HardwareService._();
  factory HardwareService() => _instance;

  CameraController? _cameraController;
  bool _cameraInitializing = false;
  bool _videoRecording = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _recorderInitialized = false;

  /// 初始化录音器
  Future<void> initRecorder() async {
    if (_recorderInitialized) return;
    _recorderInitialized = true;
    _log('录音器初始化完成');
  }

  Future<void> _ensureCameraInitialized() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return;
    }
    if (_cameraInitializing) return;
    _cameraInitializing = true;
    try {
      final PermissionStatus cameraStatus = await Permission.camera.request();
      final PermissionStatus micStatus = await Permission.microphone.request();
      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        throw StateError('Camera or microphone permission denied');
      }

      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera available');
      }

      _cameraController?.dispose();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await _cameraController!.initialize();
      _log('Camera initialized');
    } finally {
      _cameraInitializing = false;
    }
  }

  Future<String> _ensureOutputDir(String folder) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory outDir = Directory(path.join(appDir.path, folder));
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir.path;
  }

  /// 拍照（真实）
  Future<String?> takePhoto() async {
    try {
      await _ensureCameraInitialized();
      final XFile file = await _cameraController!.takePicture();
      final String outputDir = await _ensureOutputDir('captures');
      final String destPath = path.join(
        outputDir,
        'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(file.path).copy(destPath);
      _log('拍照成功: $destPath');
      return destPath;
    } catch (e) {
      _log('拍照失败: $e');
    }
    return null;
  }

  /// 开始录像
  Future<String?> startVideoRecording() async {
    try {
      await _ensureCameraInitialized();
      if (_videoRecording) return null;
      await _cameraController!.startVideoRecording();
      _videoRecording = true;
      _log('录像开始');
      return 'recording';
    } catch (e) {
      _log('录像开始失败: $e');
    }
    return null;
  }

  /// 停止录像
  Future<String?> stopVideoRecording() async {
    try {
      if (_cameraController == null || !_videoRecording) return null;
      final XFile file = await _cameraController!.stopVideoRecording();
      _videoRecording = false;
      final String outputDir = await _ensureOutputDir('recordings');
      final String destPath = path.join(
        outputDir,
        'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await File(file.path).copy(destPath);
      _log('录像完成: $destPath');
      return destPath;
    } catch (e) {
      _log('录像停止失败: $e');
    }
    return null;
  }

  /// 开始录音
  Future<String?> startAudioRecording() async {
    try {
      await initRecorder();
      if (!await _audioRecorder.hasPermission()) {
        throw StateError('Microphone permission denied');
      }
      final String outputDir = await _ensureOutputDir('recordings');
      final String filePath = path.join(
        outputDir,
        'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      _log('录音开始: $filePath');
      return filePath;
    } catch (e) {
      _log('录音开始失败: $e');
    }
    return null;
  }

  /// 停止录音
  Future<String?> stopAudioRecording() async {
    try {
      final String? path = await _audioRecorder.stop();
      if (path == null) return null;
      _log('录音停止: $path');
      return path;
    } catch (e) {
      _log('录音停止失败: $e');
    }
    return null;
  }

  /// 获取电池信息（仍为占位，可扩展到平台接口）
  Future<Map<String, dynamic>> getBatteryInfo() async {
    return <String, dynamic>{
      'level': 0,
      'isCharging': false,
      'state': 'unknown',
    };
  }

  /// 获取存储信息（占位）
  Future<Map<String, dynamic>> getStorageInfo() async {
    return <String, dynamic>{
      'freeGB': 0,
      'totalGB': 0,
      'free': 0,
      'total': 0,
    };
  }

  /// 获取网络信息（占位）
  Future<Map<String, dynamic>> getNetworkInfo() async {
    return <String, dynamic>{
      'type': 'unknown',
      'signalStrength': 0,
      'connected': false,
    };
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    return <String, dynamic>{
      'model': 'unknown',
      'brand': 'unknown',
      'manufacturer': 'unknown',
      'product': 'unknown',
      'androidVersion': 'unknown',
      'sdkInt': 0,
      'isPhysicalDevice': true,
    };
  }

  double getCpuTemp() => 0;

  double getMemoryUsage() => 0;

  /// 释放资源
  Future<void> dispose() async {
    await _cameraController?.dispose();
    _cameraController = null;
    await _audioRecorder.dispose();
    _recorderInitialized = false;
    _log('硬件服务已释放');
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[HardwareService] $message');
    }
  }
}
