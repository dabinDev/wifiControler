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
        throw UploadException('Upload failed: ${response.statusCode} - ${response.reasonPhrase}');
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

  // 检查是否应该跳过上传
  bool _shouldSkipUpload() {
    if (_lastUploadTime == null) return false;
    
    final DateTime now = DateTime.now();
    final Duration timeSinceLastUpload = now.difference(_lastUploadTime!);
    
    // 如果距离上次上传不到5秒，跳过
    return timeSinceLastUpload.inSeconds < 5;
  }

  // 记录日志
  void _log(String message) {
    if (kDebugMode) {
      print('[UploadService] $message');
    }
  }

  // 丰富数据
  Map<String, dynamic> _enrichData(Map<String, dynamic> data, String deviceId) {
    return <String, dynamic>{
      'deviceId': deviceId,
      'deviceToken': deviceToken,
      'timestamp': DateTime.now().toIso8601String(),
      'sessionId': _sessionId ??= _generateSessionId(),
      'uploadCount': ++_uploadCount,
      ...data,
    };
  }

  // 加密数据
  String _encryptData(String data) {
    if (!enableEncryption) return data;
    
    final List<int> bytes = utf8.encode(data);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }

  // 构建请求头
  Map<String, String> _buildHeaders() {
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $deviceToken',
      'User-Agent': 'Flutter-UDP-Control/1.0',
      if (_sessionId != null) 'X-Session-ID': _sessionId!,
    };
  }

  // 更新上传统计
  void _updateUploadStats() {
    _lastUploadTime = DateTime.now();
  }

  // 生成会话ID
  String _generateSessionId() {
    final Random random = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(10000)}';
  }
}

class UploadException implements Exception {
  const UploadException(this.message);
  
  final String message;
  
  @override
  String toString() => 'UploadException: $message';
}
