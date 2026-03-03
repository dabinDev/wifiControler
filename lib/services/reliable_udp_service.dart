import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:webrtc/models/control_message.dart';
import 'package:webrtc/services/udp_service_enhanced.dart' as enhanced_udp;

/// 可靠UDP服务：提供消息去重、重传机制和状态追踪
class ReliableUdpService {
  ReliableUdpService({
    required this.udpService,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 500),
    this.duplicateWindow = const Duration(seconds: 30),
    this.ackTimeout = const Duration(seconds: 2),
  });

  final enhanced_udp.UdpService udpService;
  final int maxRetries;
  final Duration retryDelay;
  final Duration duplicateWindow;
  final Duration ackTimeout;

  // 消息去重窗口
  final Map<String, DateTime> _messageIds = <String, DateTime>{};
  Timer? _cleanupTimer;

  // 重传管理
  final Map<String, _PendingMessage> _pendingMessages = <String, _PendingMessage>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};

  // 统计信息
  int _sentCount = 0;
  int _retryCount = 0;
  int _duplicateCount = 0;
  int _ackCount = 0;

  /// 初始化服务
  void initialize() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) => _cleanupExpiredMessages());
  }

  /// 发送广播消息（带重传）
  Future<void> sendBroadcast({
    required Map<String, dynamic> jsonPayload,
    int retries = 3,
    Duration? retryDelay,
  }) async {
    final String messageId = jsonPayload['messageId'] as String? ?? _generateMessageId();
    jsonPayload['messageId'] = messageId;

    if (_isDuplicate(messageId)) {
      _duplicateCount++;
      _log('Duplicate message ignored: $messageId');
      return;
    }

    final _PendingMessage pending = _PendingMessage(
      messageId: messageId,
      payload: jsonPayload,
      retries: retries,
      retryDelay: retryDelay ?? this.retryDelay,
      isBroadcast: true,
      timestamp: DateTime.now(),
    );

    _pendingMessages[messageId] = pending;
    _messageIds[messageId] = DateTime.now();

    await _sendMessageWithRetry(pending);
  }

  /// 发送单播消息（带重传）
  Future<void> sendUnicast({
    required Map<String, dynamic> jsonPayload,
    required String ip,
    required int port,
    int retries = 3,
    Duration? retryDelay,
  }) async {
    final String messageId = jsonPayload['messageId'] as String? ?? _generateMessageId();
    jsonPayload['messageId'] = messageId;

    if (_isDuplicate(messageId)) {
      _duplicateCount++;
      _log('Duplicate message ignored: $messageId');
      return;
    }

    final _PendingMessage pending = _PendingMessage(
      messageId: messageId,
      payload: jsonPayload,
      targetIp: ip,
      targetPort: port,
      retries: retries,
      retryDelay: retryDelay ?? this.retryDelay,
      isBroadcast: false,
      timestamp: DateTime.now(),
    );

    _pendingMessages[messageId] = pending;
    _messageIds[messageId] = DateTime.now();

    await _sendMessageWithRetry(pending);
  }

  /// 处理收到的消息（去重检查）
  bool processIncomingMessage(Map<String, dynamic> jsonPayload) {
    final String? messageId = jsonPayload['messageId'] as String?;
    if (messageId == null) return true; // 没有ID的消息直接处理

    if (_isDuplicate(messageId)) {
      _duplicateCount++;
      _log('Duplicate incoming message ignored: $messageId');
      return false;
    }

    _messageIds[messageId] = DateTime.now();

    // 如果是ACK消息，处理对应的待确认消息
    if (jsonPayload['type'] == 'ACK') {
      _handleAck(jsonPayload);
    }

    return true;
  }

  /// 发送ACK确认
  Future<void> sendAck({
    required String originalMessageId,
    required String targetIp,
    required int targetPort,
    required String fromDeviceId,
  }) async {
    final Map<String, dynamic> ack = <String, dynamic>{
      'type': 'ACK',
      'messageId': _generateMessageId(),
      'originalMessageId': originalMessageId,
      'from': fromDeviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await sendUnicast(
      jsonPayload: ack,
      ip: targetIp,
      port: targetPort,
      retries: 1, // ACK只发一次
    );
  }

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    return <String, dynamic>{
      'sentCount': _sentCount,
      'retryCount': _retryCount,
      'duplicateCount': _duplicateCount,
      'ackCount': _ackCount,
      'pendingCount': _pendingMessages.length,
      'duplicateWindowMessages': _messageIds.length,
    };
  }

  /// 释放资源
  void dispose() {
    _cleanupTimer?.cancel();
    for (final Timer timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _pendingMessages.clear();
    _messageIds.clear();
  }

  // 私有方法

  bool _isDuplicate(String messageId) {
    final DateTime? timestamp = _messageIds[messageId];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < duplicateWindow;
  }

  String _generateMessageId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';
  }

  Future<void> _sendMessageWithRetry(_PendingMessage pending) async {
    try {
      if (pending.isBroadcast) {
        await udpService.sendBroadcast(jsonPayload: jsonEncode(pending.payload));
      } else {
        await udpService.sendUnicast(
          jsonPayload: jsonEncode(pending.payload),
          ip: pending.targetIp!,
          port: pending.targetPort!,
        );
      }
      
      _sentCount++;
      _log('Message sent: ${pending.messageId} (${pending.isBroadcast ? 'broadcast' : 'unicast to ${pending.targetIp}:${pending.targetPort}'})');

      // 设置ACK超时
      _retryTimers[pending.messageId] = Timer(ackTimeout, () {
        _retryMessage(pending);
      });

    } catch (e) {
      _log('Send message failed: ${pending.messageId} - $e');
      await _retryMessage(pending);
    }
  }

  Future<void> _retryMessage(_PendingMessage pending) async {
    final Timer? timer = _retryTimers.remove(pending.messageId);
    timer?.cancel();

    if (pending.retriesLeft <= 0) {
      _pendingMessages.remove(pending.messageId);
      _log('Message failed after max retries: ${pending.messageId}');
      return;
    }

    pending.retriesLeft--;
    _retryCount++;
    _log('Retrying message: ${pending.messageId} (${pending.retriesLeft} retries left)');

    await Future<void>.delayed(pending.retryDelay);
    await _sendMessageWithRetry(pending);
  }

  void _handleAck(Map<String, dynamic> ack) {
    final String? originalMessageId = ack['originalMessageId'] as String?;
    if (originalMessageId == null) return;

    final _PendingMessage? pending = _pendingMessages.remove(originalMessageId);
    if (pending != null) {
      final Timer? timer = _retryTimers.remove(originalMessageId);
      timer?.cancel();
      
      _ackCount++;
      _log('Message acknowledged: $originalMessageId');
    }
  }

  void _cleanupExpiredMessages() {
    final DateTime now = DateTime.now();
    final List<String> expired = <String>[];

    // 清理去重窗口中的过期消息
    for (final MapEntry<String, DateTime> entry in _messageIds.entries) {
      if (now.difference(entry.value) > duplicateWindow) {
        expired.add(entry.key);
      }
    }
    for (final String key in expired) {
      _messageIds.remove(key);
    }

    // 清理超时的待确认消息
    final List<String> timeoutMessages = <String>[];
    for (final _PendingMessage pending in _pendingMessages.values) {
      if (now.difference(pending.timestamp) > ackTimeout * 2) {
        timeoutMessages.add(pending.messageId);
      }
    }
    for (final String messageId in timeoutMessages) {
      final Timer? timer = _retryTimers.remove(messageId);
      timer?.cancel();
      _pendingMessages.remove(messageId);
      _log('Message timeout: $messageId');
    }

    if (expired.isNotEmpty || timeoutMessages.isNotEmpty) {
      _log('Cleanup: ${expired.length} duplicates, ${timeoutMessages.length} timeouts');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[ReliableUdpService] $message');
    }
  }
}

class _PendingMessage {
  _PendingMessage({
    required this.messageId,
    required this.payload,
    this.targetIp,
    this.targetPort,
    required this.retries,
    required this.retryDelay,
    required this.isBroadcast,
    required this.timestamp,
  }) : retriesLeft = retries;

  final String messageId;
  final Map<String, dynamic> payload;
  final String? targetIp;
  final int? targetPort;
  final int retries;
  final Duration retryDelay;
  final bool isBroadcast;
  final DateTime timestamp;
  int retriesLeft;
}
