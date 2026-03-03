import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/control_message.dart';
import '../protocol/message_types.dart';
import '../services/udp_service_enhanced.dart' as enhanced_udp;

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> with TickerProviderStateMixin {
  final String _deviceId = 'ctrl-${DateTime.now().millisecondsSinceEpoch}';
  late final enhanced_udp.UdpService _udpService;

  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _payloadController = TextEditingController();
  final List<String> _logs = <String>[];
  final Set<String> _onlineDevices = <String>{};
  final Map<String, DateTime> _deviceLastSeen = <String, DateTime>{};
  final Set<String> _ackDevices = <String>{};

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
      _udpService = enhanced_udp.UdpService();
      await _udpService.startListening();
      
      _eventSub = _udpService.eventStream.listen(_handleUdpEvent);
      
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendHeartbeat());
      _deviceCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) => _cleanupOfflineDevices());
      
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
      final Map<String, dynamic> data = jsonDecode(event.data) as Map<String, dynamic>;
      final ControlMessage message = ControlMessage.fromJson(data);
      
      _addLog('收到消息: ${message.type} 来自 ${message.from}');
      
      if (message.from != _deviceId) {
        _onlineDevices.add(message.from);
        _deviceLastSeen[message.from] = DateTime.now();
        
        if (message.type == MessageTypes.ack) {
          _ackDevices.add(message.from);
        }
      }
      
      setState(() {});
    } catch (e) {
      _addLog('消息处理错误: $e');
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      final Map<String, dynamic> heartbeat = <String, dynamic>{
        'type': MessageTypes.heartbeat,
        'from': _deviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _udpService.sendBroadcast(jsonPayload: jsonEncode(heartbeat));
    } catch (e) {
      _addLog('心跳发送失败: $e');
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
    
    final Map<String, dynamic> command = <String, dynamic>{
      'type': typeOrCommand,
      'from': _deviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'messageId': '${DateTime.now().millisecondsSinceEpoch}-${_deviceId.hashCode}',
    };
    
    final String payload = _payloadController.text.trim();
    if (payload.isNotEmpty) {
      command['payload'] = payload;
    }
    
    try {
      await _udpService.sendBroadcast(jsonPayload: jsonEncode(command));
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
                      
                      return Card(
                        child: ListTile(
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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
