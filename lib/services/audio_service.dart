import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AudioRecording {
  const AudioRecording({
    required this.filePath,
    required this.fileSize,
    required this.duration,
    required this.timestamp,
    this.sampleRate = 44100,
    this.bitRate = 128000,
    this.channels = 1,
  });

  final String filePath;
  final int fileSize;
  final int duration; // 录制时长（秒）
  final DateTime timestamp;
  final int sampleRate;
  final int bitRate;
  final int channels;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'filePath': filePath,
      'fileSize': fileSize,
      'duration': duration,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sampleRate': sampleRate,
      'bitRate': bitRate,
      'channels': channels,
    };
  }
}

class AudioService {
  AudioService._();
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;

  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingStartTime = 0;
  String? _currentRecordingPath;
  
  final StreamController<AudioRecording> _recordingController = 
      StreamController<AudioRecording>.broadcast();
  final StreamController<int> _recordingProgressController = 
      StreamController<int>.broadcast();
  
  Stream<AudioRecording> get recordingStream => _recordingController.stream;
  Stream<int> get recordingProgressStream => _recordingProgressController.stream;
  bool get isRecording => _isRecording;
  bool get isInitialized => true;

  Future<void> initialize() async {
    if (kIsWeb) {
      _log('Audio service: Web platform detected');
      return;
    }
    
    _log('Audio service initialized');
  }

  // 检查麦克风权限
  Future<bool> checkMicrophonePermission() async {
    if (kIsWeb) return true;
    
    final PermissionStatus status = await Permission.microphone.status;
    return status.isGranted;
  }

  // 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true;
    
    final PermissionStatus status = await Permission.microphone.request();
    return status.isGranted;
  }

  // 检查存储权限
  Future<bool> checkStoragePermission() async {
    if (kIsWeb) return true;
    
    if (Platform.isAndroid) {
      if (Platform.version.startsWith('Android 13')) {
        final PermissionStatus status = await Permission.photos.status;
        return status.isGranted;
      } else {
        final PermissionStatus status = await Permission.storage.status;
        return status.isGranted;
      }
    } else {
      final PermissionStatus status = await Permission.photos.status;
      return status.isGranted;
    }
  }

  // 请求存储权限
  Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;
    
    if (Platform.isAndroid) {
      if (Platform.version.startsWith('Android 13')) {
        final PermissionStatus status = await Permission.photos.request();
        return status.isGranted;
      } else {
        final PermissionStatus status = await Permission.storage.request();
        return status.isGranted;
      }
    } else {
      final PermissionStatus status = await Permission.photos.request();
      return status.isGranted;
    }
  }

  // 检查所有必需权限
  Future<bool> checkAllPermissions() async {
    final bool micGranted = await checkMicrophonePermission();
    final bool storageGranted = await checkStoragePermission();
    return micGranted && storageGranted;
  }

  // 请求所有必需权限
  Future<bool> requestAllPermissions() async {
    final bool micGranted = await requestMicrophonePermission();
    final bool storageGranted = await requestStoragePermission();
    return micGranted && storageGranted;
  }

  // 开始录音
  Future<bool> startRecording({
    int maxDurationSeconds = 300, // 最大5分钟
    int sampleRate = 44100,
    int bitRate = 128000,
    int channels = 1,
  }) async {
    try {
      if (_isRecording) {
        _log('Recording already in progress');
        return false;
      }

      // 检查权限
      if (!await checkAllPermissions()) {
        if (!await requestAllPermissions()) {
          _log('Microphone or storage permission denied');
          return false;
        }
      }

      // 创建输出目录
      final String outputDir = await createOutputDirectory();
      final String fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      final String filePath = path.join(outputDir, fileName);

      // 模拟录音开始（实际应用中应该使用真实的音频录制库）
      _currentRecordingPath = filePath;
      _recordingStartTime = DateTime.now().millisecondsSinceEpoch;
      _isRecording = true;

      // 启动进度定时器
      _recordingTimer = Timer.periodic(
        const Duration(seconds: 1),
        (Timer timer) {
          final int elapsed = DateTime.now().millisecondsSinceEpoch - _recordingStartTime;
          final int elapsedSeconds = elapsed ~/ 1000;
          
          _recordingProgressController.add(elapsedSeconds);
          
          // 检查是否达到最大时长
          if (elapsedSeconds >= maxDurationSeconds) {
            stopRecording();
          }
        },
      );

      _log('Recording started: $filePath');
      return true;
    } catch (error) {
      _log('Failed to start recording: $error');
      return false;
    }
  }

  // 停止录音
  Future<AudioRecording?> stopRecording() async {
    try {
      if (!_isRecording) {
        _log('No recording in progress');
        return null;
      }

      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;

      final int recordingEndTime = DateTime.now().millisecondsSinceEpoch;
      final int duration = (recordingEndTime - _recordingStartTime) ~/ 1000;

      // 模拟创建音频文件（实际应用中应该保存真实的音频数据）
      final String? filePath = _currentRecordingPath;
      if (filePath == null) {
        _log('No recording file path');
        return null;
      }

      // 创建模拟的音频文件
      await _createMockAudioFile(filePath, duration);

      // 获取文件大小
      final File file = File(filePath);
      final int fileSize = await file.length();

      // 创建录音对象
      final AudioRecording recording = AudioRecording(
        filePath: filePath,
        fileSize: fileSize,
        duration: duration,
        timestamp: DateTime.fromMillisecondsSinceEpoch(_recordingStartTime),
      );

      _recordingController.add(recording);
      _log('Recording stopped: $filePath, duration: ${duration}s, size: ${fileSize}B');

      _currentRecordingPath = null;
      return recording;
    } catch (error) {
      _log('Failed to stop recording: $error');
      return null;
    }
  }

  // 取消录音
  Future<void> cancelRecording() async {
    try {
      if (!_isRecording) {
        return;
      }

      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;

      // 删除未完成的录音文件
      if (_currentRecordingPath != null) {
        final File file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _log('Recording cancelled');
      _currentRecordingPath = null;
    } catch (error) {
      _log('Failed to cancel recording: $error');
    }
  }

  // 创建模拟音频文件
  Future<void> _createMockAudioFile(String filePath, int duration) async {
    try {
      final File file = File(filePath);
      
      // 创建一个简单的WAV文件头
      final int sampleRate = 44100;
      final int channels = 1;
      final int bitsPerSample = 16;
      final int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
      final int blockAlign = channels * bitsPerSample ~/ 8;
      
      // WAV文件大小估算
      final int dataSize = duration * byteRate;
      final int fileSize = 36 + dataSize;
      
      final ByteData wavHeader = ByteData(44);
      
      // RIFF header
      wavHeader.setUint8(0, 0x52); // 'R'
      wavHeader.setUint8(1, 0x49); // 'I'
      wavHeader.setUint8(2, 0x46); // 'F'
      wavHeader.setUint8(3, 0x46); // 'F'
      wavHeader.setUint32(4, fileSize, Endian.little);
      
      // WAVE header
      wavHeader.setUint8(8, 0x57); // 'W'
      wavHeader.setUint8(9, 0x41); // 'A'
      wavHeader.setUint8(10, 0x56); // 'V'
      wavHeader.setUint8(11, 0x45); // 'E'
      
      // fmt chunk
      wavHeader.setUint8(12, 0x66); // 'f'
      wavHeader.setUint8(13, 0x6D); // 'm'
      wavHeader.setUint8(14, 0x74); // 't'
      wavHeader.setUint8(15, 0x20); // ' '
      wavHeader.setUint32(16, 16, Endian.little); // chunk size
      wavHeader.setUint16(20, 1, Endian.little); // audio format (PCM)
      wavHeader.setUint16(22, channels, Endian.little); // channels
      wavHeader.setUint32(24, sampleRate, Endian.little); // sample rate
      wavHeader.setUint32(28, byteRate, Endian.little); // byte rate
      wavHeader.setUint16(32, blockAlign, Endian.little); // block align
      wavHeader.setUint16(34, bitsPerSample, Endian.little); // bits per sample
      
      // data chunk
      wavHeader.setUint8(36, 0x64); // 'd'
      wavHeader.setUint8(37, 0x61); // 'a'
      wavHeader.setUint8(38, 0x74); // 't'
      wavHeader.setUint8(39, 0x61); // 'a'
      wavHeader.setUint32(40, dataSize, Endian.little); // data size
      
      // 写入文件
      await file.writeAsBytes(wavHeader.buffer.asUint8List());
      
      // 添加一些模拟的音频数据（静音）
      final Uint8List silenceData = Uint8List(dataSize);
      await file.writeAsBytes(silenceData, mode: FileMode.append);
      
    } catch (error) {
      _log('Failed to create mock audio file: $error');
    }
  }

  // 获取录音列表
  Future<List<AudioRecording>> getRecordings() async {
    try {
      final String outputDir = await createOutputDirectory();
      final Directory dir = Directory(outputDir);
      
      if (!await dir.exists()) {
        return <AudioRecording>[];
      }

      final List<FileSystemEntity> files = await dir.list().toList();
      final List<AudioRecording> recordings = <AudioRecording>[];

      for (final FileSystemEntity file in files) {
        if (file is File && path.extension(file.path).toLowerCase() == '.wav') {
          final int fileSize = await file.length();
          final DateTime lastModified = await file.lastModified();
          
          // 简化时长估算（基于文件大小）
          final int estimatedDuration = (fileSize / (44100 * 2)).round();
          
          recordings.add(AudioRecording(
            filePath: file.path,
            fileSize: fileSize,
            duration: estimatedDuration,
            timestamp: lastModified,
          ));
        }
      }

      // 按时间排序（最新的在前）
      recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return recordings;
    } catch (error) {
      _log('Failed to get recordings: $error');
      return <AudioRecording>[];
    }
  }

  // 删除录音
  Future<bool> deleteRecording(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _log('Recording deleted: $filePath');
        return true;
      }
      return false;
    } catch (error) {
      _log('Failed to delete recording: $error');
      return false;
    }
  }

  // 创建输出目录
  Future<String> createOutputDirectory() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory outputDir = Directory(path.join(appDocDir.path, 'recordings'));
      
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      _log('Audio output directory created: ${outputDir.path}');
      return outputDir.path;
    } catch (error) {
      _log('Failed to create audio output directory: $error');
      rethrow;
    }
  }

  // 清理旧录音
  Future<int> cleanupOldRecordings({int daysToKeep = 7}) async {
    try {
      final String outputDir = await createOutputDirectory();
      final Directory dir = Directory(outputDir);
      
      if (!await dir.exists()) {
        return 0;
      }

      final DateTime cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
      final List<FileSystemEntity> files = await dir.list().toList();
      int deletedCount = 0;

      for (final FileSystemEntity file in files) {
        if (file is File && path.extension(file.path).toLowerCase() == '.wav') {
          final DateTime lastModified = await file.lastModified();
          if (lastModified.isBefore(cutoff)) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      _log('Cleaned up $deletedCount old recordings');
      return deletedCount;
    } catch (error) {
      _log('Failed to cleanup old recordings: $error');
      return 0;
    }
  }

  // 获取存储统计
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final String outputDir = await createOutputDirectory();
      final Directory dir = Directory(outputDir);
      
      if (!await dir.exists()) {
        return <String, dynamic>{
          'totalRecordings': 0,
          'totalSize': 0,
          'totalSizeMB': '0.00',
          'totalDuration': 0,
          'oldestRecording': null,
          'newestRecording': null,
        };
      }

      final List<AudioRecording> recordings = await getRecordings();
      int totalSize = 0;
      int totalDuration = 0;
      
      for (final AudioRecording recording in recordings) {
        totalSize += recording.fileSize;
        totalDuration += recording.duration;
      }

      return <String, dynamic>{
        'totalRecordings': recordings.length,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'totalDuration': totalDuration,
        'oldestRecording': recordings.isNotEmpty ? recordings.last.timestamp.millisecondsSinceEpoch : null,
        'newestRecording': recordings.isNotEmpty ? recordings.first.timestamp.millisecondsSinceEpoch : null,
      };
    } catch (error) {
      _log('Failed to get audio storage stats: $error');
      return <String, dynamic>{};
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[AudioService] $message');
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recordingController.close();
    _recordingProgressController.close();
  }
}

// 全局音频服务实例
final AudioService audioService = AudioService();
