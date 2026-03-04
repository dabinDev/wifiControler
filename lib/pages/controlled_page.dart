import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/control_message.dart';
import '../protocol/message_types.dart';
import '../services/hardware_service.dart';
import '../services/udp_service_enhanced.dart' as enhanced_udp;

class ControlledPage extends StatefulWidget {
  const ControlledPage({super.key});

  @override
  State<ControlledPage> createState() => _ControlledPageState();
}

class _ControlledPageState extends State<ControlledPage> {
  final String _deviceId = 'dev-${DateTime.now().millisecondsSinceEpoch}';
  late final enhanced_udp.UdpService _udpService;
  late final HardwareService _hardwareService;
  static const int _port = 8888; // 被控制端监听端口
  static const int _targetPort = 8889; // 目标(控制端)端口

  final List<String> _logs = <String>[];
  StreamSubscription<enhanced_udp.UdpDatagramEvent>? _eventSub;
  Timer? _heartbeatTimer;
  Timer? _statusUpdateTimer;
  bool _networkReady = false;
  String _networkStatus = '初始化中...';
  bool _hasNetworkError = false;
  String _controllerDeviceId = '';
  DateTime? _lastControllerContact;

  // Device status
  double _batteryLevel = 85.0;
  bool _isCharging = false;
  double _storageFree = 32.5;
  double _cpuTemp = 42.0;
  int _wifiSignalStrength = -45;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _hardwareService = HardwareService();
      await _hardwareService.initRecorder();
      
      _udpService = enhanced_udp.UdpService(listenPort: _port);
      await _udpService.startListening();
      
      _eventSub = _udpService.events.listen(_handleUdpEvent);
      
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendHeartbeat());
      _statusUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) => _updateStatus());
      
      setState(() {
        _networkReady = true;
        _networkStatus = '网络已连接';
      });
      
      _addLog('设备初始化完成: $_deviceId');
    } catch (error) {
      setState(() {
        _hasNetworkError = true;
        _networkStatus = '初始化失败: $error';
      });
      _addLog('初始化失败: $error');
    }
  }

  void _handleUdpEvent(enhanced_udp.UdpDatagramEvent event) {
    try {
      final ControlMessage message = event.message;
      
      _addLog('收到消息: ${message.type} 来自 ${message.from}');
      
      if (message.type != MessageTypes.heartbeat) {
        _lastControllerContact = DateTime.now();
        _controllerDeviceId = message.from;
      }
      
      _processMessage(message);
    } catch (e) {
      _addLog('消息处理错误: $e');
    }
  }

  void _processMessage(ControlMessage message) {
    switch (message.type) {
      case MessageTypes.hello:
        _sendAck(message);
        break;
      case MessageTypes.cmdTakePhoto:
        _executeTakePhoto(message);
        break;
      case MessageTypes.cmdRecordStart:
        _executeRecordStart(message);
        break;
      case MessageTypes.cmdRecordStop:
        _executeRecordStop(message);
        break;
      case MessageTypes.cmdAudioStart:
        _executeAudioStart(message);
        break;
      case MessageTypes.cmdAudioStop:
        _executeAudioStop(message);
        break;
      default:
        _addLog('未知命令类型: ${message.type}');
    }
  }

  Future<void> _sendAck(ControlMessage originalMessage) async {
    try {
      final Map<String, dynamic> ack = <String, dynamic>{
        'type': MessageTypes.ack,
        'from': _deviceId,
        'to': originalMessage.from,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'originalMessageId': originalMessage.messageId,
      };
      
      await _udpService.sendBroadcast(
        jsonPayload: jsonEncode(ack),
        port: _targetPort,
      );
      _addLog('发送ACK: ${originalMessage.type}');
    } catch (e) {
      _addLog('ACK发送失败: $e');
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      final Map<String, dynamic> heartbeat = <String, dynamic>{
        'type': MessageTypes.heartbeat,
        'from': _deviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': <String, dynamic>{
          'battery': _batteryLevel,
          'charging': _isCharging,
          'storage': _storageFree,
          'cpuTemp': _cpuTemp,
          'wifiSignal': _wifiSignalStrength,
        },
      };
      
      await _udpService.sendBroadcast(
        jsonPayload: jsonEncode(heartbeat),
        port: _targetPort,
      );
    } catch (e) {
      _addLog('心跳发送失败: $e');
    }
  }

  Future<void> _updateStatus() async {
    try {
      final Map<String, dynamic> batteryInfo = await _hardwareService.getBatteryInfo();
      final Map<String, dynamic> storageInfo = await _hardwareService.getStorageInfo();
      final Map<String, dynamic> networkInfo = await _hardwareService.getNetworkInfo();
      
      setState(() {
        _batteryLevel = (batteryInfo['level'] as int).toDouble();
        _isCharging = batteryInfo['isCharging'] as bool;
        _storageFree = storageInfo['freeGB'] as double;
        _cpuTemp = _hardwareService.getCpuTemp();
        _wifiSignalStrength = networkInfo['signalStrength'] as int;
      });
    } catch (e) {
      _addLog('状态更新失败: $e');
    }
  }

  Future<void> _executeTakePhoto(ControlMessage message) async {
    _addLog('执行拍照命令...');
    _sendAck(message);
    
    try {
      final String? photoPath = await _hardwareService.takePhoto();
      if (photoPath != null) {
        _addLog('拍照成功: $photoPath');
      } else {
        _addLog('拍照失败');
      }
    } catch (e) {
      _addLog('拍照错误: $e');
    }
  }

  Future<void> _executeRecordStart(ControlMessage message) async {
    _addLog('开始录像...');
    _sendAck(message);
    
    try {
      final String? videoPath = await _hardwareService.startVideoRecording();
      if (videoPath != null) {
        _addLog('录像开始: $videoPath');
      } else {
        _addLog('录像开始失败');
      }
    } catch (e) {
      _addLog('录像错误: $e');
    }
  }

  Future<void> _executeRecordStop(ControlMessage message) async {
    _addLog('停止录像...');
    _sendAck(message);
    _addLog('录像已停止');
  }

  Future<void> _executeAudioStart(ControlMessage message) async {
    _addLog('开始录音...');
    _sendAck(message);
    
    try {
      final String? audioPath = await _hardwareService.startAudioRecording();
      if (audioPath != null) {
        _addLog('录音开始: $audioPath');
      } else {
        _addLog('录音开始失败');
      }
    } catch (e) {
      _addLog('录音错误: $e');
    }
  }

  Future<void> _executeAudioStop(ControlMessage message) async {
    _addLog('停止录音...');
    _sendAck(message);
    
    try {
      final String? audioPath = await _hardwareService.stopAudioRecording();
      if (audioPath != null) {
        _addLog('录音停止: $audioPath');
      } else {
        _addLog('录音停止失败');
      }
    } catch (e) {
      _addLog('录音停止错误: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String().substring(11, 19)}: $message');
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _statusUpdateTimer?.cancel();
    _eventSub?.cancel();
    _udpService.dispose();
    _hardwareService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('被控制端'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 网络状态
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hasNetworkError ? Colors.red.shade100 : Colors.green.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(
                  _hasNetworkError ? Icons.error : Icons.check_circle,
                  color: _hasNetworkError ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _networkStatus,
                    style: TextStyle(
                      color: _hasNetworkError ? Colors.red.shade700 : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 设备状态
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('设备状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusCard('电池', '${_batteryLevel.toInt()}%', Icons.battery_full, _batteryLevel > 20 ? Colors.green : Colors.orange),
                    const SizedBox(width: 8),
                    _buildStatusCard('存储', '${_storageFree.toStringAsFixed(1)}GB', Icons.storage, Colors.blue),
                    const SizedBox(width: 8),
                    _buildStatusCard('CPU', '${_cpuTemp.toStringAsFixed(1)}°C', Icons.memory, _cpuTemp < 60 ? Colors.green : Colors.orange),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusCard('WiFi', '${_wifiSignalStrength}dBm', Icons.wifi, Colors.green),
                    const SizedBox(width: 8),
                    _buildStatusCard('充电', _isCharging ? '是' : '否', Icons.power, _isCharging ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    if (_controllerDeviceId.isNotEmpty)
                  _buildStatusCard('控制端', _controllerDeviceId.substring(0, 8), Icons.settings_remote, Colors.purple),
                  ],
                ),
              ],
            ),
          ),
          
          // 操作按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _networkReady ? () => _executeTakePhoto(ControlMessage(
                    type: MessageTypes.cmdTakePhoto, 
                    from: _deviceId,
                    messageId: '${DateTime.now().millisecondsSinceEpoch}-photo',
                    timestampMs: DateTime.now().millisecondsSinceEpoch,
                  )) : null,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('拍照'),
                ),
                ElevatedButton.icon(
                  onPressed: _networkReady ? () => _executeRecordStart(ControlMessage(
                    type: MessageTypes.cmdRecordStart, 
                    from: _deviceId,
                    messageId: '${DateTime.now().millisecondsSinceEpoch}-video',
                    timestampMs: DateTime.now().millisecondsSinceEpoch,
                  )) : null,
                  icon: const Icon(Icons.videocam),
                  label: const Text('录像'),
                ),
                ElevatedButton.icon(
                  onPressed: _networkReady ? () => _executeAudioStart(ControlMessage(
                    type: MessageTypes.cmdAudioStart, 
                    from: _deviceId,
                    messageId: '${DateTime.now().millisecondsSinceEpoch}-audio',
                    timestampMs: DateTime.now().millisecondsSinceEpoch,
                  )) : null,
                  icon: const Icon(Icons.mic),
                  label: const Text('录音'),
                ),
              ],
            ),
          ),
          
          // 日志
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('日志 (${_logs.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _logs.clear();
                            });
                          },
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final String log = _logs[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                          child: Text(
                            log,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
