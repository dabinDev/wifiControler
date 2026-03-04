import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/control_message.dart';
import '../protocol/message_types.dart';
import '../services/udp_service_enhanced.dart' as enhanced_udp;
import 'sync_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> with TickerProviderStateMixin {
  final String _deviceId = 'ctrl-${DateTime.now().millisecondsSinceEpoch}';
  static const int _port = 8889; // 控制端监听端口
  static const int _targetPort = 8888; // 目标(被控制端)端口
  late final enhanced_udp.UdpService _udpService;

  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _payloadController = TextEditingController();
  final List<String> _logs = <String>[];
  final Set<String> _onlineDevices = <String>{};
  final Map<String, DateTime> _deviceLastSeen = <String, DateTime>{};
  final Set<String> _ackDevices = <String>{};
  final Map<String, ControlMessage> _deviceLastMessage = <String, ControlMessage>{};
  final Set<String> _expandedDevices = <String>{};
  final Map<String, Map<String, dynamic>> _deviceStatus =
      <String, Map<String, dynamic>>{};
  final Map<String, String> _deviceIps = <String, String>{};
  
  // 录制状态跟踪
  final Map<String, Map<String, dynamic>> _deviceRecordingStatus = <String, Map<String, dynamic>>{};

  StreamSubscription<enhanced_udp.UdpDatagramEvent>? _eventSub;
  Timer? _heartbeatTimer;
  Timer? _deviceCleanupTimer;
  TabController? _tabController;

  bool _networkReady = false;
  String _networkStatus = '初始化中...';
  bool _hasNetworkError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _udpService = enhanced_udp.UdpService(listenPort: _port);
      await _udpService.startListening();
      
      _eventSub = _udpService.events.listen(_handleUdpEvent);
      
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendHeartbeat());
      _deviceCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) => _cleanupOfflineDevices());
      _sendDiscover();
      
      setState(() {
        _networkReady = true;
        _networkStatus = '网络已连接';
      });
      
      _addLog('控制端初始化完成: $_deviceId');
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
      
      // 只记录重要消息，减少日志噪音
      if (message.type != MessageTypes.heartbeat) {
        _addLog('收到消息: ${message.type} 来自 ${message.from}');
      }
      
      if (message.from != _deviceId) {
        _onlineDevices.add(message.from);
        _deviceLastSeen[message.from] = DateTime.now();
        _deviceLastMessage[message.from] = message;
        _deviceIps[message.from] = event.senderAddress;
        if (message.type == MessageTypes.heartbeat && message.payload != null) {
          _deviceStatus[message.from] = message.payload!;
          
          // 提取录制状态
          if (message.payload!.containsKey('recordingStatus')) {
            final Map<String, dynamic> recordingStatus = message.payload!['recordingStatus'];
            _deviceRecordingStatus[message.from] = recordingStatus;
          }
        }
        
        // 处理录制状态更新
        if (message.type == MessageTypes.cmdRecordStart || 
            message.type == MessageTypes.cmdRecordStop ||
            message.type == MessageTypes.cmdAudioStart || 
            message.type == MessageTypes.cmdAudioStop) {
          if (message.payload != null) {
            _deviceRecordingStatus[message.from] = message.payload!;
            _addLog('设备 ${message.from} 录制状态更新');
          }
        }
        
        // 收到任何消息都认为是设备在线的标志
        _ackDevices.add(message.from);
      }
      
      setState(() {});
    } catch (e) {
      // 只记录关键错误
      if (e.toString().contains('FormatException') == false) {
        _addLog('消息处理错误: $e');
      }
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final ControlMessage heartbeat = ControlMessage(
        type: MessageTypes.heartbeat,
        messageId: 'hb-$now',
        from: _deviceId,
        timestampMs: now,
      );

      await _udpService.sendBroadcast(
        jsonPayload: heartbeat.toJson(),
        port: _targetPort,
      );
    } catch (e) {
      _addLog('心跳发送失败: $e');
    }
  }

  Future<void> _sendDiscover() async {
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final ControlMessage discover = ControlMessage(
        type: MessageTypes.discover,
        messageId: 'discover-$now',
        from: _deviceId,
        timestampMs: now,
      );
      await _udpService.sendBroadcast(
        jsonPayload: discover.toJson(),
        port: _targetPort,
      );
      _addLog('发送设备发现请求');
    } catch (e) {
      _addLog('设备发现请求失败: $e');
    }
  }

  void _cleanupOfflineDevices() {
    final DateTime now = DateTime.now();
    final List<String> offlineDevices = <String>[];
    
    _deviceLastSeen.forEach((deviceId, lastSeen) {
      if (now.difference(lastSeen).inSeconds > 15) {
        offlineDevices.add(deviceId);
      }
    });
    
    if (offlineDevices.isNotEmpty) {
      setState(() {
        for (final String deviceId in offlineDevices) {
          _onlineDevices.remove(deviceId);
          _deviceLastSeen.remove(deviceId);
          _ackDevices.remove(deviceId);
          _deviceIps.remove(deviceId);
        }
      });
      _addLog('清理离线设备: ${offlineDevices.join(', ')}');
    }
  }

  Future<void> _sendCommand() async {
    if (!_networkReady) {
      _showError('网络未就绪');
      return;
    }
    
    final String typeOrCommand = _commandController.text.trim();
    if (typeOrCommand.isEmpty) {
      _showError('请输入命令类型');
      return;
    }
    
    final String payload = _payloadController.text.trim();
    Map<String, dynamic>? payloadMap;
    if (payload.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          payloadMap = decoded;
        } else {
          payloadMap = <String, dynamic>{'value': decoded};
        }
      } catch (_) {
        payloadMap = <String, dynamic>{'raw': payload};
      }
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    final ControlMessage command = ControlMessage(
      type: typeOrCommand,
      messageId: 'cmd-$now-${_deviceId.hashCode}',
      from: _deviceId,
      timestampMs: now,
      payload: payloadMap,
    );
    
    try {
      await _udpService.sendBroadcast(
        jsonPayload: command.toJson(),
        port: _targetPort,
      );
      _addLog('发送命令: $typeOrCommand');
      setState(() {
        _ackDevices.clear();
      });
    } catch (e) {
      _addLog('命令发送失败: $e');
      _showError('命令发送失败');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
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
    _deviceCleanupTimer?.cancel();
    _eventSub?.cancel();
    _udpService.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('控制端'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '同步',
            onPressed: () {
              _sendDiscover();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SyncPage(
                    udpService: _udpService,
                    getDevices: () => _onlineDevices.toList(),
                    getDeviceIps: () => Map<String, String>.from(_deviceIps),
                    controllerId: _deviceId,
                    targetPort: _targetPort,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '命令', icon: Icon(Icons.send)),
            Tab(text: '设备', icon: Icon(Icons.devices)),
            Tab(text: '日志', icon: Icon(Icons.list)),
          ],
        ),
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
                Text('在线设备: ${_onlineDevices.length}'),
              ],
            ),
          ),
          
          // 标签页内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCommandTab(),
                _buildDeviceTab(),
                _buildLogTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBattery(dynamic value) {
    if (value == null) return '-';
    final num? battery = value is num ? value : num.tryParse(value.toString());
    return battery != null ? '${battery.toStringAsFixed(1)}%' : value.toString();
  }

  String _formatCharging(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? '是' : '否';
    return value.toString();
  }

  String _formatStorage(dynamic value) {
    if (value == null) return '-';
    final num? storage = value is num ? value : num.tryParse(value.toString());
    return storage != null ? '${storage.toStringAsFixed(2)} GB' : value.toString();
  }

  String _formatTemperature(dynamic value) {
    if (value == null) return '-';
    final num? temp = value is num ? value : num.tryParse(value.toString());
    return temp != null ? '${temp.toStringAsFixed(1)} °C' : value.toString();
  }

  String _formatWifi(dynamic value) {
    if (value == null) return '-';
    final num? signal = value is num ? value : num.tryParse(value.toString());
    return signal != null ? '${signal.toStringAsFixed(0)} dBm' : value.toString();
  }

  Widget _buildCommandTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 快捷命令
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCommandChip('拍照', MessageTypes.cmdTakePhoto),
              _buildCommandChip('录像', MessageTypes.cmdRecordStart),
              _buildCommandChip('停止录像', MessageTypes.cmdRecordStop),
              _buildCommandChip('录音', MessageTypes.cmdAudioStart),
              _buildCommandChip('停止录音', MessageTypes.cmdAudioStop),
              _buildCommandChip('HELLO', MessageTypes.hello),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 命令输入
          TextField(
            controller: _commandController,
            decoration: const InputDecoration(
              labelText: '命令类型',
              border: OutlineInputBorder(),
              hintText: '例如: TAKE_PHOTO',
            ),
          ),
          
          const SizedBox(height: 8),
          
          TextField(
            controller: _payloadController,
            decoration: const InputDecoration(
              labelText: '载荷 (可选)',
              border: OutlineInputBorder(),
              hintText: 'JSON格式的载荷数据',
            ),
            maxLines: 3,
          ),
          
          const SizedBox(height: 16),
          
          // 发送按钮和ACK状态
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _networkReady ? _sendCommand : null,
                  icon: const Icon(Icons.send),
                  label: const Text('发送命令'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_ackDevices.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    '响应: ${_ackDevices.length}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommandChip(String label, String command) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setState(() {
          _commandController.text = command;
          _payloadController.clear();
        });
        _addLog('选择命令: $label');
      },
    );
  }

  Widget _buildDeviceTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '在线设备 (${_onlineDevices.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _onlineDevices.clear();
                    _deviceLastSeen.clear();
                    _ackDevices.clear();
                    _deviceLastMessage.clear();
                    _expandedDevices.clear();
                    _deviceStatus.clear();
                  });
                },
                child: const Text('清空'),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: _onlineDevices.isEmpty
                ? const Center(child: Text('暂无在线设备'))
                : ListView.builder(
                    itemCount: _onlineDevices.length,
                    itemBuilder: (context, index) {
                      final String deviceId = _onlineDevices.elementAt(index);
                      final DateTime? lastSeen = _deviceLastSeen[deviceId];
                      final bool hasAck = _ackDevices.contains(deviceId);
                      final ControlMessage? lastMessage = _deviceLastMessage[deviceId];
                      final bool isExpanded = _expandedDevices.contains(deviceId);
                      final Map<String, dynamic>? status = _deviceStatus[deviceId];
                      
                      return Card(
                        child: ExpansionTile(
                          key: PageStorageKey<String>('device-$deviceId'),
                          initiallyExpanded: isExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              if (expanded) {
                                _expandedDevices.add(deviceId);
                              } else {
                                _expandedDevices.remove(deviceId);
                              }
                            });
                          },
                          leading: Icon(
                            Icons.smartphone,
                            color: hasAck ? Colors.green : Colors.blue,
                          ),
                          title: Text(deviceId),
                          subtitle: Text(
                            lastSeen != null
                                ? '最后 seen: ${lastSeen.toIso8601String().substring(11, 19)}'
                                : 'Unknown',
                          ),
                          trailing: hasAck
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDeviceDetailRow('最近消息', lastMessage?.type ?? '-'),
                                  _buildDeviceDetailRow(
                                    '消息ID',
                                    lastMessage?.messageId ?? '-',
                                  ),
                                  _buildDeviceDetailRow(
                                    '时间戳',
                                    lastMessage != null
                                        ? lastMessage.timestampMs.toString()
                                        : '-',
                                  ),
                                  if (status != null) ...[
                                    const SizedBox(height: 4),
                                    _buildDeviceDetailRow(
                                      '电池',
                                      _formatBattery(status['battery']),
                                    ),
                                    _buildDeviceDetailRow(
                                      '充电',
                                      _formatCharging(status['charging']),
                                    ),
                                    _buildDeviceDetailRow(
                                      '存储',
                                      _formatStorage(status['storage']),
                                    ),
                                    _buildDeviceDetailRow(
                                      'CPU温度',
                                      _formatTemperature(status['cpuTemp']),
                                    ),
                                    _buildDeviceDetailRow(
                                      'WiFi',
                                      _formatWifi(status['wifiSignal']),
                                    ),
                                  ],
                                  // 添加录制状态显示
                                  if (_deviceRecordingStatus.containsKey(deviceId)) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.fiber_manual_record, 
                                                   color: Colors.red, size: 12),
                                              SizedBox(width: 4),
                                              Text('录制状态', 
                                                   style: TextStyle(
                                                     fontWeight: FontWeight.bold,
                                                     color: Colors.blue.shade700,
                                                   )),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          _buildRecordingStatusRows(deviceId),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (lastMessage?.payload != null)
                                    _buildDeviceDetailRow(
                                      'Payload',
                                      jsonEncode(lastMessage!.payload),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingStatusRows(String deviceId) {
    final Map<String, dynamic>? status = _deviceRecordingStatus[deviceId];
    if (status == null) return const SizedBox.shrink();

    final List<Widget> rows = [];
    
    // 显示状态
    if (status.containsKey('status')) {
      final String statusText = status['status'] == 'recording' ? '录制中' : '已停止';
      final Color statusColor = status['status'] == 'recording' ? Colors.red : Colors.green;
      
      rows.add(_buildDeviceDetailRow(
        '状态',
        statusText,
      ));
      
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 72),
              Icon(Icons.fiber_manual_record, color: statusColor, size: 8),
              SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 显示类型
    if (status.containsKey('type')) {
      final String type = status['type'] == 'video' ? '视频' : '音频';
      rows.add(_buildDeviceDetailRow('类型', type));
    }
    
    // 显示文件路径
    if (status.containsKey('filePath')) {
      rows.add(_buildDeviceDetailRow('文件', status['filePath'].toString().split('/').last));
    }
    
    // 显示文件大小
    if (status.containsKey('fileSize')) {
      final int size = status['fileSize'];
      final String sizeText = size > 1024 * 1024 
          ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
          : '${(size / 1024).toStringAsFixed(1)} KB';
      rows.add(_buildDeviceDetailRow('大小', sizeText));
    }
    
    return Column(children: rows);
  }

  Widget _buildLogTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '日志 (${_logs.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
          
          const SizedBox(height: 8),
          
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
    );
  }
}
