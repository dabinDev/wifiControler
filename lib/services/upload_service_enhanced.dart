import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class UploadService {
  UploadService({
    required this.baseUrl, 
    required this.deviceToken,
    this.enableEncryption = true,
    this.timeout = const Duration(seconds: 30),
  });

  final String baseUrl;
  final String deviceToken;
  final bool enableEncryption;
  final Duration timeout;
  
  String? _sessionId;
  DateTime? _lastUploadTime;
  int _uploadCount = 0;
  final Map<String, dynamic> _uploadCache = <String, dynamic>{};

  Future<void> uploadDeviceSnapshot({
    required String deviceId,
    required Map<String, dynamic> data,
    bool forceUpload = false,
  }) async {
    try {
      // 检查是否需要上传（避免频繁上传）
      if (!forceUpload && _shouldSkipUpload()) {
        _log('Skipping upload - too frequent');
        return;
      }

      // 添加元数据
      final Map<String, dynamic> enrichedData = _enrichData(data, deviceId);
      
      // 加密数据（如果启用）
      final String payload = enableEncryption 
          ? _encryptData(jsonEncode(enrichedData))
          : jsonEncode(enrichedData);

      final Uri uri = Uri.parse('$baseUrl/device/upload');
      
      final http.Response response = await http.post(
        uri,
        headers: _buildHeaders(),
        body: payload,
      ).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UploadException(
          'Upload failed: ${response.statusCode} ${response.body}',
          response.statusCode,
        );
      }

      _updateUploadStats();
      _log('Upload successful: ${response.statusCode}');
      
      // 缓存上传结果
      _uploadCache['lastSuccess'] = DateTime.now().toIso8601String();
      
    } catch (error) {
      _log('Upload failed: $error');
      _uploadCache['lastError'] = <String, dynamic>{
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      rethrow;
    }
  }
  
  // 新增：批量上传文件
  Future<List<UploadResult>> uploadFiles(
    List<File> files, {
    Map<String, String>? metadata,
    ProgressCallback? onProgress,
  }) async {
    final List<UploadResult> results = <UploadResult>[];
    
    for (int i = 0; i < files.length; i++) {
      final File file = files[i];
      try {
        _log('Uploading file ${i + 1}/${files.length}: ${file.path}');
        
        final UploadResult result = await uploadSingleFile(
          file,
          metadata: metadata,
        );
        results.add(result);
        
        onProgress?.call(i + 1, files.length);
        
      } catch (error) {
        results.add(UploadResult.failure(file.path, error.toString()));
        _log('File upload failed: ${file.path} - $error');
      }
    }
    
    return results;
  }
  
  // 新增：单个文件上传
  Future<UploadResult> uploadSingleFile(
    File file, {
    Map<String, String>? metadata,
  }) async {
    try {
      final String fileName = file.path.split('/').last;
      final int fileSize = await file.length();
      
      final Uri uri = Uri.parse('$baseUrl/files/upload');
      final http.MultipartRequest request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_buildHeaders())
        ..fields['deviceId'] = _sessionId ?? 'unknown'
        ..fields['uploadedAt'] = DateTime.now().toUtc().toIso8601String();
      
      // 添加元数据
      if (metadata != null) {
        request.fields.addAll(metadata);
      }
      
      // 添加文件
      final http.MultipartFile multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName,
      );
      request.files.add(multipartFile);
      
      final http.StreamedResponse streamedResponse = await request.send().timeout(timeout);
      final http.Response response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UploadException(
          'File upload failed: ${response.statusCode} ${response.body}',
          response.statusCode,
        );
      }
      
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      
      return UploadResult.success(
        fileName,
        responseData['fileId'] as String,
        responseData['url'] as String?,
        fileSize,
      );
      
    } catch (error) {
      return UploadResult.failure(file.path, error.toString());
    }
  }
  
  // 新增：获取上传状态
  Map<String, dynamic> getUploadStatus() {
    return <String, dynamic>{
      'sessionId': _sessionId,
      'lastUploadTime': _lastUploadTime?.toIso8601String(),
      'uploadCount': _uploadCount,
      'cache': _uploadCache,
      'encryptionEnabled': enableEncryption,
    };
  }
  
  // 新增：清理缓存
  void clearCache() {
    _uploadCache.clear();
    _log('Upload cache cleared');
  }
  
  // 私有方法：构建请求头
  Map<String, String> _buildHeaders() {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $deviceToken',
      'User-Agent': 'Flutter-Device/1.0',
    };
    
    if (_sessionId != null) {
      headers['X-Session-ID'] = _sessionId!;
    }
    
    return headers;
  }
  
  // 私有方法：数据加密
  String _encryptData(String data) {
    if (!enableEncryption) return data;
    
    // 简单的XOR加密（生产环境应使用更强的加密）
    final String key = deviceToken.substring(0, 8);
    final List<int> encrypted = <int>[];
    
    for (int i = 0; i < data.length; i++) {
      encrypted.add(data.codeUnitAt(i) ^ key.codeUnitAt(i % key.length));
    }
    
    return base64Encode(encrypted);
  }
  
  // 私有方法：丰富数据
  Map<String, dynamic> _enrichData(Map<String, dynamic> data, String deviceId) {
    _sessionId ??= 'session-${DateTime.now().millisecondsSinceEpoch}';
    
    return <String, dynamic>{
      'deviceId': deviceId,
      'sessionId': _sessionId,
      'uploadedAt': DateTime.now().toUtc().toIso8601String(),
      'uploadCount': ++_uploadCount,
      'payload': data,
      'metadata': <String, dynamic>{
        'platform': Platform.operatingSystem,
        'version': '1.0.0',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    };
  }
  
  // 私有方法：检查是否应跳过上传
  bool _shouldSkipUpload() {
    if (_lastUploadTime == null) return false;
    
    final Duration timeSinceLastUpload = DateTime.now().difference(_lastUploadTime!);
    return timeSinceLastUpload.inSeconds < 30; // 30秒内只允许一次上传
  }
  
  // 私有方法：更新上传统计
  void _updateUploadStats() {
    _lastUploadTime = DateTime.now();
    _uploadCount++;
  }
  
  // 私有方法：日志记录
  void _log(String message) {
    if (kDebugMode) {
      print('[UploadService] $message');
    }
  }
}

// 新增：上传结果类
class UploadResult {
  const UploadResult._({
    required this.success,
    required this.fileName,
    this.fileId,
    this.url,
    this.fileSize,
    this.error,
  });
  
  factory UploadResult.success(
    String fileName,
    String fileId, [
    String? url,
    int? fileSize,
  ]) => UploadResult._(
    success: true,
    fileName: fileName,
    fileId: fileId,
    url: url,
    fileSize: fileSize,
  );
  
  factory UploadResult.failure(String fileName, String error) => UploadResult._(
    success: false,
    fileName: fileName,
    error: error,
  );
  
  final bool success;
  final String fileName;
  final String? fileId;
  final String? url;
  final int? fileSize;
  final String? error;
}

// 新增：上传异常类
class UploadException implements Exception {
  const UploadException(this.message, [this.statusCode]);
  
  final String message;
  final int? statusCode;
  
  @override
  String toString() => 'UploadException: $message';
}

// 新增：进度回调类型定义
typedef ProgressCallback = void Function(int completed, int total);
