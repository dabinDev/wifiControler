import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

enum CameraMode {
  photo,
  video,
}

class CameraCapture {
  const CameraCapture({
    required this.filePath,
    required this.fileSize,
    required this.timestamp,
    required this.mode,
    this.duration,
    this.width,
    this.height,
  });

  final String filePath;
  final int fileSize;
  final DateTime timestamp;
  final CameraMode mode;
  final int? duration; // 视频时长（秒）
  final int? width;
  final int? height;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'filePath': filePath,
      'fileSize': fileSize,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'mode': mode.name,
      'duration': duration,
      'width': width,
      'height': height,
    };
  }
}

class CameraService {
  CameraService._();
  static final CameraService _instance = CameraService._();
  factory CameraService() => _instance;

  final ImagePicker _imagePicker = ImagePicker();
  final StreamController<CameraCapture> _captureController = 
      StreamController<CameraCapture>.broadcast();
  
  Stream<CameraCapture> get captureStream => _captureController.stream;
  bool get isInitialized => true;

  Future<void> initialize() async {
    if (kIsWeb) {
      _log('Camera service: Web platform detected');
      return;
    }
    
    _log('Camera service initialized');
  }

  // 检查相机权限
  Future<bool> checkCameraPermission() async {
    if (kIsWeb) return true;
    
    final PermissionStatus status = await Permission.camera.status;
    return status.isGranted;
  }

  // 请求相机权限
  Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;
    
    final PermissionStatus status = await Permission.camera.request();
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
    final bool cameraGranted = await checkCameraPermission();
    final bool storageGranted = await checkStoragePermission();
    return cameraGranted && storageGranted;
  }

  // 请求所有必需权限
  Future<bool> requestAllPermissions() async {
    final bool cameraGranted = await requestCameraPermission();
    final bool storageGranted = await requestStoragePermission();
    return cameraGranted && storageGranted;
  }

  // 拍照
  Future<CameraCapture?> takePhoto({
    ImageSource source = ImageSource.camera,
    bool useFrontCamera = false,
    double? quality,
  }) async {
    try {
      // 检查权限
      if (!await checkAllPermissions()) {
        if (!await requestAllPermissions()) {
          _log('Camera or storage permission denied');
          return null;
        }
      }

      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: useFrontCamera ? CameraDevice.front : CameraDevice.rear,
        imageQuality: quality?.toInt() ?? 80,
      );

      if (photo == null) {
        _log('Photo capture cancelled');
        return null;
      }

      // 获取文件信息
      final File file = File(photo.path);
      final int fileSize = await file.length();
      
      // 创建捕获对象
      final CameraCapture capture = CameraCapture(
        filePath: photo.path,
        fileSize: fileSize,
        timestamp: DateTime.now(),
        mode: CameraMode.photo,
      );

      _captureController.add(capture);
      _log('Photo captured: ${photo.path}, size: ${fileSize}B');
      
      return capture;
    } catch (error) {
      _log('Failed to take photo: $error');
      return null;
    }
  }

  // 录制视频
  Future<CameraCapture?> recordVideo({
    ImageSource source = ImageSource.camera,
    bool useFrontCamera = false,
    Duration? maxDuration,
  }) async {
    try {
      // 检查权限（视频需要相机和麦克风权限）
      final bool cameraGranted = await checkCameraPermission();
      final bool micGranted = await Permission.microphone.status.isGranted;
      final bool storageGranted = await checkStoragePermission();
      
      if (!cameraGranted || !micGranted || !storageGranted) {
        _log('Required permissions for video recording not granted');
        return null;
      }

      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        preferredCameraDevice: useFrontCamera ? CameraDevice.front : CameraDevice.rear,
        maxDuration: maxDuration ?? const Duration(seconds: 60),
      );

      if (video == null) {
        _log('Video recording cancelled');
        return null;
      }

      // 获取文件信息
      final File file = File(video.path);
      final int fileSize = await file.length();
      
      // 获取视频时长（简化实现）
      final int duration = await _getVideoDuration(video.path);
      
      // 创建捕获对象
      final CameraCapture capture = CameraCapture(
        filePath: video.path,
        fileSize: fileSize,
        timestamp: DateTime.now(),
        mode: CameraMode.video,
        duration: duration,
      );

      _captureController.add(capture);
      _log('Video recorded: ${video.path}, size: ${fileSize}B, duration: ${duration}s');
      
      return capture;
    } catch (error) {
      _log('Failed to record video: $error');
      return null;
    }
  }

  // 从相册选择图片
  Future<CameraCapture?> pickImageFromGallery({
    double? quality,
  }) async {
    return await takePhoto(
      source: ImageSource.gallery,
      quality: quality,
    );
  }

  // 从相册选择视频
  Future<CameraCapture?> pickVideoFromGallery() async {
    return await recordVideo(
      source: ImageSource.gallery,
    );
  }

  // 获取视频时长（简化实现）
  Future<int> _getVideoDuration(String videoPath) async {
    try {
      final File file = File(videoPath);
      final int fileSize = await file.length();
      
      // 简化估算：假设视频码率为2Mbps
      final int estimatedDuration = fileSize ~/ (2 * 1024 * 1024 / 8);
      return estimatedDuration.clamp(1, 3600); // 限制在1秒到1小时之间
    } catch (error) {
      _log('Failed to get video duration: $error');
      return 30; // 默认30秒
    }
  }

  // 删除文件
  Future<bool> deleteFile(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _log('File deleted: $filePath');
        return true;
      }
      return false;
    } catch (error) {
      _log('Failed to delete file: $error');
      return false;
    }
  }

  // 获取文件信息
  Future<Map<String, dynamic>?> getFileInfo(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final int fileSize = await file.length();
      final DateTime lastModified = await file.lastModified();
      final String fileName = path.basename(filePath);
      final String extension = path.extension(filePath);

      return <String, dynamic>{
        'fileName': fileName,
        'filePath': filePath,
        'fileSize': fileSize,
        'lastModified': lastModified.millisecondsSinceEpoch,
        'extension': extension,
        'isImage': <String>['.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(extension.toLowerCase()),
        'isVideo': <String>['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(extension.toLowerCase()),
      };
    } catch (error) {
      _log('Failed to get file info: $error');
      return null;
    }
  }

  // 创建输出目录
  Future<String> createOutputDirectory() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory outputDir = Directory(path.join(appDocDir.path, 'captures'));
      
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      _log('Output directory created: ${outputDir.path}');
      return outputDir.path;
    } catch (error) {
      _log('Failed to create output directory: $error');
      rethrow;
    }
  }

  // 复制文件到输出目录
  Future<String?> copyToOutputDirectory(String sourcePath) async {
    try {
      final String outputDir = await createOutputDirectory();
      final String fileName = path.basename(sourcePath);
      final String destPath = path.join(outputDir, fileName);
      
      final File sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);
      
      _log('File copied to: $destPath');
      return destPath;
    } catch (error) {
      _log('Failed to copy file: $error');
      return null;
    }
  }

  // 清理旧文件
  Future<int> cleanupOldFiles({int daysToKeep = 7}) async {
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
        if (file is File) {
          final DateTime lastModified = await file.lastModified();
          if (lastModified.isBefore(cutoff)) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      _log('Cleaned up $deletedCount old files');
      return deletedCount;
    } catch (error) {
      _log('Failed to cleanup old files: $error');
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
          'totalFiles': 0,
          'totalSize': 0,
          'totalSizeMB': '0.00',
          'oldestFile': null,
          'newestFile': null,
        };
      }

      final List<FileSystemEntity> files = await dir.list().toList();
      int totalSize = 0;
      int fileCount = 0;
      DateTime? oldestTime;
      DateTime? newestTime;
      String? oldestFile;
      String? newestFile;

      for (final FileSystemEntity file in files) {
        if (file is File) {
          final int fileSize = await file.length();
          final DateTime lastModified = await file.lastModified();
          
          totalSize += fileSize;
          fileCount++;
          
          if (oldestTime == null || lastModified.isBefore(oldestTime)) {
            oldestTime = lastModified;
            oldestFile = path.basename(file.path);
          }
          
          if (newestTime == null || lastModified.isAfter(newestTime)) {
            newestTime = lastModified;
            newestFile = path.basename(file.path);
          }
        }
      }

      return <String, dynamic>{
        'totalFiles': fileCount,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'oldestFile': oldestFile,
        'newestFile': newestFile,
        'oldestTime': oldestTime?.millisecondsSinceEpoch,
        'newestTime': newestTime?.millisecondsSinceEpoch,
      };
    } catch (error) {
      _log('Failed to get storage stats: $error');
      return <String, dynamic>{};
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[CameraService] $message');
    }
  }

  void dispose() {
    _captureController.close();
  }
}

// 全局相机服务实例
final CameraService cameraService = CameraService();
