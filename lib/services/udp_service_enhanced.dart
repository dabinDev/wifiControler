import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/control_message.dart';

class UdpDatagramEvent {
  const UdpDatagramEvent({
    required this.message,
    required this.senderAddress,
    required this.senderPort,
    this.rtt,
    this.packetLoss,
  });

  final ControlMessage message;
  final String senderAddress;
  final int senderPort;
  final int? rtt; // 往返时间（毫秒）
  final double? packetLoss; // 丢包率
}

class NetworkStats {
  const NetworkStats({
    required this.latency,
    required this.packetLoss,
    required this.throughput,
    required this.lastUpdate,
  });

  final int latency; // 延迟（毫秒）
  final double packetLoss; // 丢包率（0-1）
  final int throughput; // 吞吐量（bytes/s）
  final DateTime lastUpdate;

  @override
  String toString() => 'NetworkStats(latency: ${latency}ms, loss: ${(packetLoss * 100).toStringAsFixed(1)}%, throughput: ${throughput}B/s)';
}

class UdpService {
  UdpService({
    required this.listenPort,
    this.enableEncryption = false,
    this.encryptionKey = 'default-key',
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 500),
    this.enableStats = true,
  });

  final int listenPort;
  final bool enableEncryption;
  final String encryptionKey;
  final int maxRetries;
  final Duration retryDelay;
  final bool enableStats;

  RawDatagramSocket? _socket;
  final StreamController<UdpDatagramEvent> _eventsController =
      StreamController<UdpDatagramEvent>.broadcast();
  
  // 网络统计
  final Map<String, DateTime> _sentMessages = <String, DateTime>{};
  final Map<String, int> _retryCount = <String, int>{};
  final List<int> _latencyHistory = <int>[];
  int _totalSent = 0;
  int _totalReceived = 0;
  DateTime? _lastStatsUpdate;
  Timer? _statsTimer;
  
  // 消息去重
  final Set<String> _processedMessageIds = <String>{};
  Timer? _cleanupTimer;

  Stream<UdpDatagramEvent> get events => _eventsController.stream;

  Future<void> startListening() async {
    if (_socket != null) {
      return;
    }
    
    try {
      final RawDatagramSocket socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort);
      socket.broadcastEnabled = true;
      _socket = socket;

      socket.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final Datagram? datagram = socket.receive();
        if (datagram == null) {
          return;
        }

        _handleIncomingDatagram(datagram, socket);
      });
      
      // 启动统计定时器
      if (enableStats) {
        _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) => _updateStats());
        _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanupOldData());
      }
      
      _log('UDP listening on port $listenPort');
    } catch (error) {
      _log('Failed to start UDP listener: $error');
      rethrow;
    }
  }

  void _handleIncomingDatagram(Datagram datagram, RawDatagramSocket socket) {
    try {
      final String payload = utf8.decode(datagram.data, allowMalformed: true);
      _log('Received raw datagram: $payload from ${datagram.address.address}:${datagram.port}');
      
      // 解密数据（如果启用加密）
      final String decryptedPayload = enableEncryption 
          ? _decryptData(payload)
          : payload;
      
      final ControlMessage? message = ControlMessage.tryParse(decryptedPayload);
      if (message == null) {
        _log('Failed to parse ControlMessage from payload');
        return;
      }
      
      if (message.type.isEmpty || message.messageId.isEmpty) {
        _log('Message missing required fields. Type: ${message.type}, ID: ${message.messageId}');
        return;
      }

      // 消息去重
      if (_processedMessageIds.contains(message.messageId)) {
        _log('Duplicate message ignored: ${message.messageId}');
        return;
      }
      _processedMessageIds.add(message.messageId);

      // 计算RTT
      final int? rtt = _calculateRTT(message.messageId);
      
      // 更新接收统计
      _totalReceived++;

      _eventsController.add(
        UdpDatagramEvent(
          message: message,
          senderAddress: datagram.address.address,
          senderPort: datagram.port,
          rtt: rtt,
          packetLoss: _getPacketLoss(),
        ),
      );
    } catch (error) {
      _log('Error handling datagram: $error');
    }
  }

  Future<void> sendBroadcast({
    required String jsonPayload, 
    int? port,
    bool retry = true,
  }) async {
    port ??= listenPort;
    
    // Android在某些情况下不允许发送到 255.255.255.255
    // 先尝试获取本地IP并推断广播地址，如果失败则回退到多个常见广播地址
    final List<InternetAddress> broadcastAddresses = await _getBroadcastAddresses();
    
    bool sentToAtLeastOne = false;
    for (final address in broadcastAddresses) {
      try {
        if (retry) {
          await _sendWithRetry(jsonPayload, address, port);
        } else {
          _sendSingle(jsonPayload, address, port);
        }
        sentToAtLeastOne = true;
      } catch (e) {
        _log('Failed to broadcast to ${address.address}: $e');
      }
    }
    
    // 如果所有特定广播地址都失败了，最后尝试一次 255.255.255.255 作为后备
    if (!sentToAtLeastOne) {
      try {
         if (retry) {
          await _sendWithRetry(jsonPayload, InternetAddress('255.255.255.255'), port);
        } else {
          _sendSingle(jsonPayload, InternetAddress('255.255.255.255'), port);
        }
      } catch (e) {
         _log('Failed to broadcast to 255.255.255.255: $e');
      }
    }
  }

  Future<List<InternetAddress>> _getBroadcastAddresses() async {
    final List<InternetAddress> addresses = <InternetAddress>[];
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // 简单的将最后一段替换为 255 来推断广播地址，更严谨的做法需要子网掩码
            final List<String> parts = addr.address.split('.');
            if (parts.length == 4) {
              parts[3] = '255';
              addresses.add(InternetAddress(parts.join('.')));
            }
          }
        }
      }
    } catch (e) {
      _log('Error getting network interfaces: $e');
    }
    
    // 如果获取不到，返回几个常见的广播地址
    if (addresses.isEmpty) {
      addresses.addAll([
        InternetAddress('192.168.0.255'),
        InternetAddress('192.168.1.255'),
        InternetAddress('192.168.3.255'),
        InternetAddress('192.168.43.255'),
        InternetAddress('10.0.0.255'),
      ]);
    }
    return addresses;
  }

  Future<void> sendUnicast({
    required String jsonPayload,
    required String ip,
    required int port,
    bool retry = true,
  }) async {
    if (retry) {
      await _sendWithRetry(jsonPayload, InternetAddress(ip), port);
    } else {
      _sendSingle(jsonPayload, InternetAddress(ip), port);
    }
  }

  Future<void> _sendWithRetry(String jsonPayload, InternetAddress address, int port) async {
    final String messageId = _extractMessageId(jsonPayload);
    _sentMessages[messageId] = DateTime.now();
    _retryCount[messageId] = 0;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        _sendSingle(jsonPayload, address, port);
        
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * (attempt + 1)); // 指数退避
        }
        
        _retryCount[messageId] = attempt + 1;
      } catch (error) {
        _log('Send attempt ${attempt + 1} failed: $error');
        
        if (attempt == maxRetries) {
          _log('All retry attempts failed for message $messageId');
          rethrow;
        }
      }
    }
  }

  void _sendSingle(String jsonPayload, InternetAddress address, int port) {
    final RawDatagramSocket? socket = _socket;
    if (socket == null) {
      throw StateError('Socket not initialized');
    }
    
    // 加密数据（如果启用）
    final String encryptedPayload = enableEncryption 
        ? _encryptData(jsonPayload)
        : jsonPayload;
    
    final List<int> bytes = utf8.encode(encryptedPayload);
    final int sent = socket.send(bytes, address, port);
    
    if (sent > 0) {
      _totalSent++;
    }
  }

  // 新增：网络质量监控
  NetworkStats? getNetworkStats() {
    if (!enableStats || _latencyHistory.isEmpty) {
      return null;
    }
    
    final int avgLatency = _latencyHistory.reduce((a, b) => a + b) ~/ _latencyHistory.length;
    final double packetLoss = _getPacketLoss();
    final int throughput = _calculateThroughput();
    
    return NetworkStats(
      latency: avgLatency,
      packetLoss: packetLoss,
      throughput: throughput,
      lastUpdate: _lastStatsUpdate ?? DateTime.now(),
    );
  }

  // 新增：获取连接的设备列表
  List<String> getConnectedDevices() {
    return _processedMessageIds
        .map((id) => id.split('-')[0]) // 提取设备ID部分
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  // 新增：ping指定设备
  Future<int?> pingDevice(String ip, {int port = 50001}) async {
    final String pingId = 'ping-${DateTime.now().millisecondsSinceEpoch}';
    final ControlMessage ping = ControlMessage(
      type: 'PING',
      messageId: pingId,
      from: 'controller',
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    
    _sentMessages[pingId] = DateTime.now();
    
    try {
      await sendUnicast(
        jsonPayload: ping.toJson(),
        ip: ip,
        port: port,
        retry: false,
      );
      
      // 等待PONG响应（简化实现）
      await for (final UdpDatagramEvent event in events) {
        if (event.message.type == 'PONG' && event.message.messageId == pingId) {
          return _calculateRTT(pingId);
        }
      }
    } catch (error) {
      _log('Ping failed: $error');
    }
    
    return null;
  }

  // 私有方法：加密数据
  String _encryptData(String data) {
    if (!enableEncryption) return data;
    
    final List<int> encrypted = <int>[];
    for (int i = 0; i < data.length; i++) {
      encrypted.add(data.codeUnitAt(i) ^ encryptionKey.codeUnitAt(i % encryptionKey.length));
    }
    return base64Encode(encrypted);
  }

  // 私有方法：解密数据
  String _decryptData(String encryptedData) {
    if (!enableEncryption) return encryptedData;
    
    try {
      final List<int> encrypted = base64Decode(encryptedData);
      final List<int> decrypted = <int>[];
      
      for (int i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ encryptionKey.codeUnitAt(i % encryptionKey.length));
      }
      
      return utf8.decode(decrypted);
    } catch (error) {
      _log('Decryption failed: $error');
      return encryptedData; // 返回原始数据以防解密失败
    }
  }

  // 私有方法：计算RTT
  int? _calculateRTT(String messageId) {
    final DateTime? sentTime = _sentMessages[messageId];
    if (sentTime == null) return null;
    
    final int rtt = DateTime.now().difference(sentTime).inMilliseconds;
    _latencyHistory.add(rtt);
    
    // 保持最近100个记录
    if (_latencyHistory.length > 100) {
      _latencyHistory.removeAt(0);
    }
    
    return rtt;
  }

  // 私有方法：获取丢包率
  double _getPacketLoss() {
    if (_totalSent == 0) return 0.0;
    return (_totalSent - _totalReceived) / _totalSent;
  }

  // 私有方法：计算吞吐量
  int _calculateThroughput() {
    // 简化实现，基于最近的数据量
    return (_totalReceived * 1024) ~/ 10; // 假设平均1KB每条消息
  }

  // 私有方法：提取消息ID
  String _extractMessageId(String jsonPayload) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonPayload) as Map<String, dynamic>;
      return data['msgId']?.toString() ?? 'unknown-${DateTime.now().millisecondsSinceEpoch}';
    } catch (error) {
      return 'unknown-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // 私有方法：更新统计信息
  void _updateStats() {
    _lastStatsUpdate = DateTime.now();
    _log('Network stats updated: ${getNetworkStats()}');
  }

  // 私有方法：清理旧数据
  void _cleanupOldData() {
    final DateTime cutoff = DateTime.now().subtract(const Duration(minutes: 30));
    
    _sentMessages.removeWhere((_, timestamp) => timestamp.isBefore(cutoff));
    _processedMessageIds.removeWhere((id) {
      final parts = id.split('-');
      if (parts.length >= 2) {
        try {
          final int timestamp = int.parse(parts.last);
          return DateTime.fromMillisecondsSinceEpoch(timestamp).isBefore(cutoff);
        } catch (error) {
          return true;
        }
      }
      return true;
    });
    
    if (_latencyHistory.length > 100) {
      _latencyHistory.removeRange(0, _latencyHistory.length - 100);
    }
    
    _log('Cleaned up old data');
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[UdpService] $message');
    }
  }

  Future<void> dispose() async {
    _statsTimer?.cancel();
    _cleanupTimer?.cancel();
    await _eventsController.close();
    _socket?.close();
    _socket = null;
    _log('UDP service disposed');
  }
}
