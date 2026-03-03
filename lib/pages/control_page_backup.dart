import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/control_message.dart';
import '../protocol/message_types.dart';
import '../services/udp_service_enhanced.dart' as enhanced_udp;
import '../services/upload_service.dart';
import '../services/config_service.dart';
import '../services/log_service.dart';
import '../services/permission_service.dart';
import '../services/database_service.dart';
import '../services/reliable_udp_service.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  late final ConfigService _configService;
  late final LogService _logService;
  late final PermissionService _permissionService;
  late final DatabaseService _databaseService;
  late int _port;

  final String _deviceId = 'ctrl-${DateTime.now().millisecondsSinceEpoch}';
  late final enhanced_udp.UdpService _udpService;
  late final UploadService _uploadService;
  late final CommandExecutionService _commandService;
  late final ReliableUdpService _reliableUdpService;

  final Map<String, int> _onlineDevices = <String, int>{};
  final Map<String, String> _deviceRoles = <String, String>{};
  final Map<String, int> _deviceSlots = <String, int>{};
  final Set<String> _ackDevices = <String>{};
  final List<String> _logs = <String>[];
  final Map<String, List<String>> _messageBuckets = <String, List<String>>{};
  
  StreamSubscription<enhanced_udp.UdpDatagramEvent>? _eventSub;
  Timer? _deviceCleanupTimer;
  Timer? _networkStatsTimer;
  Timer? _heartbeatTimer;
  bool _networkServicesInitialized = false;
  
  bool _networkReady = false;
  String _networkStatus = '初始化中...';
  bool _hasNetworkError = false;
  bool _isScanning = false;
  
  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _payloadController = TextEditingController();
  final TextEditingController _targetDeviceController = TextEditingController();
  
  final List<CommandExecution> _commandHistory = <CommandExecution>[];
  enhanced_udp.NetworkStats? _networkStats;
  final Map<String, int> _devicePingResults = <String, int>{};

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // 初始化配置和日志服务
      _configService = ConfigService();
      _logService = LogService();
      _permissionService = PermissionService();
      _databaseService = DatabaseService();
      
      await _configService.initialize();
      await _logService.initialize();
      await _permissionService.initialize();
      await _databaseService.initialize();
      
      _logService.info('Control page initializing...', tag: 'ControlPage');
      
      // 检查权限
      await _checkPermissions();
      
      // 获取配置
      _port = _configService.config.udpPort;
      
      // 初始化网络和服务
      await _initializeNetworkServices();
      
      _logService.info('Control page initialized successfully', tag: 'ControlPage');
    } catch (error) {
      _logService.error('Failed to initialize control page', error: error, tag: 'ControlPage');
      if (mounted) {
        setState(() {
          _hasNetworkError = true;
          _networkStatus = '初始化失败: $error';
        });
      }
    }
  }

  Future<void> _checkPermissions() async {
    try {
      if (!_permissionService.areAllPermissionsGranted()) {
        _logService.warning('Some permissions are not granted', tag: 'Permission');
        
        // 请求所有必需权限
        final bool allGranted = await _permissionService.requestAllPermissions();
        
        if (!allGranted) {
          final List<PermissionType> denied = _permissionService.getDeniedPermissions();
          _logService.warning('Denied permissions: ${denied.map((type) => type.name).join(', ')}', tag: 'Permission');
          
          // 显示权限提示
          if (mounted) {
            _showPermissionDialog(denied);
          }
        } else {
          _logService.info('All permissions granted', tag: 'Permission');
        }
      } else {
        _logService.info('All permissions already granted', tag: 'Permission');
      }
    } catch (error) {
      _logService.error('Permission check failed', error: error, tag: 'Permission');
    }
  }

  void _showPermissionDialog(List<PermissionType> deniedPermissions) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('权限需要'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('应用需要以下权限才能正常工作：'),
              const SizedBox(height: 8),
              ...deniedPermissions.map((PermissionType type) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${_getPermissionDisplayName(type)}'),
              )),
              const SizedBox(height: 8),
              const Text('请在设置中手动开启这些权限。'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _permissionService.openAppSettings();
              },
              child: const Text('打开设置'),
            ),
          ],
        );
      },
    );
  }

  String _getPermissionDisplayName(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return '相机权限';
      case PermissionType.microphone:
        return '麦克风权限';
      case PermissionType.storage:
        return '存储权限';
      case PermissionType.notifications:
        return '通知权限';
      case PermissionType.location:
        return '位置权限';
      case PermissionType.phone:
        return '电话权限';
    }
  }

  Future<void> _initializeNetworkServices() async {
    _udpService = enhanced_udp.UdpService(
      listenPort: _port,
      enableEncryption: _configService.config.enableEncryption,
      encryptionKey: _configService.config.encryptionKey,
      enableStats: _configService.config.enableNetworkStats,
    );

    // 初始化增强的上传服务
    _uploadService = UploadService(
      baseUrl: _configService.config.serverUrl,
      deviceToken: _configService.config.deviceToken,
      enableEncryption: _configService.config.enableEncryption,
    );

    // 初始化命令执行服务
    _commandService = CommandExecutionService(
      deviceStatusService: _createDummyDeviceStatusService(),
      uploadService: _uploadService,
      commandTimeout: Duration(seconds: _configService.config.commandTimeout),
      maxRetries: _configService.config.maxRetries,
    );

    // 初始化可靠UDP服务
    _reliableUdpService = ReliableUdpService(udpService: _udpService);
    _reliableUdpService.initialize();

    await _startNetwork();
    _networkServicesInitialized = true;
  }

  DeviceStatusService _createDummyDeviceStatusService() {
    // 创建一个虚拟的设备状态服务用于控制端
    return DeviceStatusService(enableRealMonitoring: false);
  }

  Future<void> _startNetwork() async {
    try {
      setState(() {
        _networkStatus = '正在启动UDP服务...';
        _hasNetworkError = false;
      });
      
      await _udpService.startListening();
      _eventSub = _udpService.events.listen(_onUdpEvent, onError: (Object error) {
        _handleNetworkError(error);
      });
      
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _broadcastHello(),
      );
      
      // 添加设备清理定时器
      _deviceCleanupTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _cleanupOfflineDevices(),
      );

      // 启动网络统计定时器
      _networkStatsTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _updateNetworkStats(),
      );
      
      setState(() {
        _networkReady = true;
        _networkStatus = 'UDP服务已启动 (端口:$_port)';
        _hasNetworkError = false;
      });
      
      _logService.info('UDP listener started on :$_port as $_deviceId', tag: 'Network');
    } catch (error) {
      _handleNetworkError(error);
    }
  }

  void _handleNetworkError(Object error) {
    _logService.error('Network error occurred', error: error, tag: 'Network');
    if (!mounted) return;
    setState(() {
      _hasNetworkError = true;
      _networkStatus = '网络错误: $error';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('网络启动失败: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '重试',
          textColor: Colors.white,
          onPressed: _retryNetworkStart,
        ),
      ),
    );
  }

  Future<void> _retryNetworkStart() async {
    _log('正在重试网络启动...');
    await _startNetwork();
  }

  void _cleanupOfflineDevices() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<String> offlineDevices = <String>[];
    
    _onlineDevices.forEach((String deviceId, int lastSeen) {
      if (now - lastSeen > 15000) { // 15秒无心跳视为离线
        offlineDevices.add(deviceId);
      }
    });
    
    if (offlineDevices.isNotEmpty) {
      setState(() {
        for (String deviceId in offlineDevices) {
          _onlineDevices.remove(deviceId);
          _deviceRoles.remove(deviceId);
          _deviceSlots.remove(deviceId);
        }
      });
      _logService.info('Cleaning up offline devices: ${offlineDevices.join(', ')}', tag: 'DeviceManager');
    }
  }

  void _updateNetworkStats() {
    final enhanced_udp.NetworkStats? stats = _udpService.getNetworkStats();
    if (stats != null) {
      setState(() {
        _networkStats = stats;
      });
    }
  }

  // 新增：ping指定设备
  Future<void> _pingDevice(String deviceId) async {
    final String? deviceIp = _getDeviceIp(deviceId);
    if (deviceIp == null) {
      _logService.warning('Cannot find IP for device: $deviceId', tag: 'Network');
      return;
    }

    _logService.info('Pinging device $deviceId...', tag: 'Network');
    
    final int? rtt = await _udpService.pingDevice(deviceIp, port: _port);
    
    if (rtt != null) {
      setState(() {
        _devicePingResults[deviceId] = rtt;
      });
      _logService.info('Device $deviceId ping: ${rtt}ms', tag: 'Network');
    } else {
      _logService.warning('Device $deviceId ping failed', tag: 'Network');
    }
  }

  // 新增：获取设备IP（简化实现）
  String? _getDeviceIp(String deviceId) {
    // 在实际应用中，应该维护设备IP映射表
    // 这里返回一个模拟的IP地址
    if (deviceId.startsWith('dev-')) {
      return '192.168.1.${(deviceId.hashCode % 254) + 1}';
    }
    return null;
  }

  void _onUdpEvent(enhanced_udp.UdpDatagramEvent event) async {
    if (!_networkReady) return;
    
    try {
      final Map<String, dynamic> data = jsonDecode(event.data) as Map<String, dynamic>;
      final ControlMessage msg = ControlMessage.fromJson(data);
      
      // 使用可靠UDP服务处理去重
      if (!_reliableUdpService.processIncomingMessage(data)) {
        return; // 重复消息，忽略
      }
      
      // 发送ACK确认
      if (msg.from != _deviceId) {
        await _reliableUdpService.sendAck(
          originalMessageId: msg.messageId,
          targetIp: event.remoteAddress.host,
          targetPort: event.remoteAddress.port,
          fromDeviceId: _deviceId,
        );
      }
      
      final ControlMessage message = event.message;
      if (message.from == _deviceId) {
        return;
      }

      _pushMessageAbbr(message.type);
      _logService.info(
        'Broadcast: ${message.type} to ${message.to ?? 'all'}',
        tag: 'Message',
      );
      _logService.info(
        'RX ${message.type} from ${message.from} payload=${message.payload ?? <String, dynamic>{}}',
        tag: 'Message',
      );
      'RX ${message.type} from ${message.from} payload=${message.payload ?? <String, dynamic>{}}',
      tag: 'Message',
    );

    switch (message.type) {
      case 'DISCOVER':
        _onDiscoverMessage(message);
        break;
      case 'REG_REQ':
        _onRegRequest(message, event.senderAddress, event.senderPort);
        break;
      case 'HELLO':
        _onHelloMessage(message);
        break;
      case 'ACK':
        setState(() {
          _ackDevices.add(message.from);
        });
        _logService.info('ACK from ${message.from} for ${message.messageId}', tag: 'Message');
        break;
      case 'STATUS':
        _logService.info('STATUS from ${message.from}: ${message.payload?['text'] ?? '-'}', tag: 'Message');
        break;
    }
  }

  String _categoryByType(String type) {
    if (<String>{'REG_REQ', 'REG_ACK', 'HEARTBEAT', 'DISCONNECT', 'DISCOVER', 'HELLO', 'ACK'}
        .contains(type)) {
      return '连接';
    }
    if (<String>{'STATUS_SYNC', 'STATUS'}.contains(type)) {
      return '遥测';
    }
    if (<String>{'CMD_RTC_START', 'RTC_OFFER', 'RTC_ANSWER', 'RTC_ICE_CANDIDATE', 'CMD_RTC_STOP'}
        .contains(type)) {
      return '直播';
    }
    if (<String>{'CMD_RECORD_START', 'CMD_RECORD_STOP', 'EVENT_RECORD_STARTED', 'CMD_TAKE_PHOTO', 'EVENT_PHOTO_TAKEN'}
        .contains(type)) {
      return '采集';
    }
    if (<String>{'CMD_FILE_UPLOAD', 'EVENT_UPLOAD_PROGRESS', 'EVENT_UPLOAD_SUCCESS', 'EVENT_UPLOAD_FAILED', 'CMD_UPLOAD_CANCEL'}
        .contains(type)) {
      return '上传';
    }
    if (<String>{'CMD_CAM_SWITCH', 'CMD_ZOOM_SET', 'CMD_TORCH_SET', 'CMD_FOCUS_SET'}
        .contains(type)) {
      return '硬件';
    }
    if (type.startsWith('NOTIFY_') || type == 'EVENT_ERROR') {
      return '告警';
    }
    if (<String>{'CMD_CLEAN_FILES', 'CMD_APP_RESTART', 'CMD_LOG_QUERY'}.contains(type)) {
      return '维护';
    }
    if (<String>{'WEB_CLIENT_JOIN', 'WEB_CLIENT_LEAVE'}.contains(type)) {
      return '网页';
    }
    return '其他';
  }

  String _abbrByType(String type) {
    return _abbrByTypeMap[type] ?? type;
  }

  void _pushMessageAbbr(String type) {
    final String category = _categoryByType(type);
    final String item = _abbrByType(type);
    setState(() {
      final List<String> list = _messageBuckets[category] ?? <String>[];
      list.insert(0, item);
      if (list.length > 120) {
        list.removeLast();
      }
      _messageBuckets[category] = list;
    });
  }

  String _timeAgoLabel(int timestampMs) {
    final int seconds = ((DateTime.now().millisecondsSinceEpoch - timestampMs) / 1000).floor();
    if (seconds < 2) {
      return '刚刚';
    }
    return '${seconds}s前';
  }

  void _showDeviceDetails(String deviceId) {
    final int? lastSeen = _onlineDevices[deviceId];
    final String role = _deviceRoles[deviceId] ?? 'unknown';
    final int? slot = _deviceSlots[deviceId];
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('设备详情', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _onlineDevices.remove(deviceId);
                        _deviceRoles.remove(deviceId);
                        _deviceSlots.remove(deviceId);
                      });
                      Navigator.of(context).pop();
                      _logService.info('Manually removed device: $deviceId', tag: 'DeviceManager');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('设备已移除')),
                      );
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: '移除设备',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('设备ID: $deviceId'),
              Text('角色: $role'),
              Text('机位: ${slot ?? '-'}'),
              Text('最后心跳: ${lastSeen == null ? '-' : _timeAgoLabel(lastSeen)}'),
              const SizedBox(height: 8),
              // Ping结果显示
              Builder(
                builder: (BuildContext context) {
                  final int? ping = _devicePingResults[deviceId];
                  if (ping != null) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getPingColor(ping).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _getPingColor(ping).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.speed,
                            size: 16,
                            color: _getPingColor(ping),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ping: ${ping}ms',
                            style: TextStyle(
                              color: _getPingColor(ping),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _getPingQualityText(ping),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getPingColor(ping),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.speed, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '未测试网络延迟',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _sendDirectCommand(deviceId);
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('发送命令'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _pingDevice(deviceId);
                      },
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Ping设备'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pingDevice(deviceId);
                      // 延迟重新打开弹窗以显示更新的ping结果
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        if (mounted) {
                          _showDeviceDetails(deviceId);
                        }
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendDirectCommand(String deviceId) async {
    if (!_networkReady) {
      _logService.warning('Network not ready', tag: 'Network');
      return;
    }

    // 这里需要获取设备的IP地址，暂时使用广播
    await _sendCommand();
    _logService.info('Sending command to device $deviceId', tag: 'Command');
  }

  Widget _buildCommandTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 命令选择区域
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.send, size: 18),
                    const SizedBox(width: 8),
                    Text('命令发送', style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: MessageTypes.controllerQuickCommands.contains(
                    _commandController.text,
                  )
                      ? _commandController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: '快速命令',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: MessageTypes.controllerQuickCommands
                      .map(
                        (String type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _commandController.text = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commandController,
                  decoration: const InputDecoration(
                    labelText: '命令类型',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _payloadController,
                  decoration: const InputDecoration(
                    labelText: 'Payload (JSON)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // 发送按钮和状态
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sendCommand,
                        icon: const Icon(Icons.send),
                        label: Text('发送命令 (${_ackDevices.length} ACK)'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () {
                        setState(() {
                          _commandController.clear();
                          _payloadController.clear();
                          _ackDevices.clear();
                        });
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: '清空',
                    ),
                  ],
                ),
                // ACK状态显示
                if (_ackDevices.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '响应设备: ${_ackDevices.join(', ')}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 快捷操作区域
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.flash_on, size: 18),
                    const SizedBox(width: 8),
                    Text('快捷操作', style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ActionChip(
                      avatar: const Icon(Icons.videocam, size: 16),
                      label: const Text('开始录像'),
                      onPressed: () {
                        setState(() {
                          _commandController.text = MessageTypes.cmdRecordStart;
                          _payloadController.text = '{"durationSec": 60}';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.videocam_off, size: 16),
                      label: const Text('停止录像'),
                      onPressed: () {
                        setState(() {
                          _commandController.text = MessageTypes.cmdRecordStop;
                          _payloadController.clear();
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.photo_camera, size: 16),
                      label: const Text('拍照'),
                      onPressed: () {
                        setState(() {
                          _commandController.text = MessageTypes.cmdTakePhoto;
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
        runSpacing: 8,
        children: items
            .take(80)
            .map(
              (String item) => ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(item),
                onPressed: () async {
                  // Find the message type by abbreviation
                  final String? messageType = _findMessageTypeByAbbr(item);
                  if (messageType != null) {
                    setState(() {
                      _commandController.text = messageType;
                    });
                    _logService.debug('Quick send: $messageType ($item)', tag: 'UI');
                    await _sendQuickType(messageType, abbr: item);
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }

  String? _findMessageTypeByAbbr(String abbr) {
    for (MapEntry<String, String> entry in _abbrByTypeMap.entries) {
      if (entry.value == abbr) {
        return entry.key;
      }
    }
    return null;
  }

  static const Map<String, String> _abbrByTypeMap = <String, String>{
    'REG_REQ': '注册请求',
    'REG_ACK': '注册确认',
    'HEARTBEAT': '心跳',
    'DISCONNECT': '断开',
    'STATUS_SYNC': '状态同步',
    'CMD_RTC_START': '开推流',
    'RTC_OFFER': 'Offer',
    'RTC_ANSWER': 'Answer',
    'RTC_ICE_CANDIDATE': 'ICE',
    'CMD_RTC_STOP': '停推流',
    'CMD_RECORD_START': '开录像',
    'CMD_RECORD_STOP': '停录像',
    'EVENT_RECORD_STARTED': '录制回执',
    'CMD_TAKE_PHOTO': '拍照',
    'EVENT_PHOTO_TAKEN': '拍照回执',
    'CMD_FILE_UPLOAD': '触发上传',
    'EVENT_UPLOAD_PROGRESS': '上传进度',
    'EVENT_UPLOAD_SUCCESS': '上传成功',
    'EVENT_UPLOAD_FAILED': '上传失败',
    'CMD_UPLOAD_CANCEL': '取消上传',
    'CMD_CAM_SWITCH': '切镜头',
    'CMD_ZOOM_SET': '变焦',
    'CMD_TORCH_SET': '补光',
    'CMD_FOCUS_SET': '对焦',
    'NOTIFY_PHONE_CALL_INCOMING': '来电',
    'NOTIFY_PHONE_CALL_ENDED': '通话结束',
    'NOTIFY_LOW_BATTERY': '低电量',
    'NOTIFY_STORAGE_FULL': '存储满',
    'NOTIFY_OVERHEAT': '过热',
    'EVENT_ERROR': '错误',
    'CMD_CLEAN_FILES': '清文件',
    'CMD_APP_RESTART': '重启App',
    'CMD_LOG_QUERY': '查日志',
    'WEB_CLIENT_JOIN': '网页加入',
    'WEB_CLIENT_LEAVE': '网页离开',
    'DISCOVER': '扫描',
    'HELLO': '上线',
    'ACK': '确认',
    'CMD': '通用命令',
    'STATUS': '状态',
  };

  List<String> _templateTypesByCategory(String category) {
    switch (category) {
      case '连接':
        return <String>[
          MessageTypes.regReq,
          MessageTypes.regAck,
          MessageTypes.heartbeat,
          MessageTypes.disconnect,
        ];
      case '遥测':
        return <String>[MessageTypes.statusSync, MessageTypes.status];
      case '直播':
        return <String>[
          MessageTypes.cmdRtcStart,
          MessageTypes.rtcOffer,
          MessageTypes.rtcAnswer,
          MessageTypes.rtcIceCandidate,
          MessageTypes.cmdRtcStop,
        ];
      case '采集':
        return <String>[
          MessageTypes.cmdRecordStart,
          MessageTypes.cmdRecordStop,
          MessageTypes.eventRecordStarted,
          MessageTypes.cmdTakePhoto,
          MessageTypes.eventPhotoTaken,
        ];
      case '上传':
        return <String>[
          MessageTypes.cmdFileUpload,
          MessageTypes.eventUploadProgress,
          MessageTypes.eventUploadSuccess,
          MessageTypes.eventUploadFailed,
          MessageTypes.cmdUploadCancel,
        ];
      case '硬件':
        return <String>[
          MessageTypes.cmdCamSwitch,
          MessageTypes.cmdZoomSet,
          MessageTypes.cmdTorchSet,
          MessageTypes.cmdFocusSet,
        ];
      case '告警':
        return <String>[
          MessageTypes.notifyPhoneCallIncoming,
          MessageTypes.notifyPhoneCallEnded,
          MessageTypes.notifyLowBattery,
          MessageTypes.notifyStorageFull,
          MessageTypes.notifyOverheat,
          MessageTypes.eventError,
        ];
      case '维护':
        return <String>[
          MessageTypes.cmdCleanFiles,
          MessageTypes.cmdAppRestart,
          MessageTypes.cmdLogQuery,
        ];
      case '网页':
        return <String>[MessageTypes.webClientJoin, MessageTypes.webClientLeave];
      default:
        return <String>[];
    }
  }

  Widget _buildTemplateWaterfall(String category) {
    final List<String> types = _templateTypesByCategory(category);
    if (types.isEmpty) {
      return const Text('暂无模板');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types
          .map(
            (String type) => ActionChip(
              label: Text(_abbrByType(type)),
              onPressed: () async {
                setState(() {
                  _commandController.text = type;
                });
                await _sendQuickType(type, abbr: _abbrByType(type));
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildCategoryTab(String category) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('快捷模板'),
          const SizedBox(height: 6),
          _buildTemplateWaterfall(category),
          const SizedBox(height: 10),
          const Text('消息缩写流'),
          const SizedBox(height: 6),
          SizedBox(
            height: 180,
            child: _buildWaterfall(_messageBuckets[category] ?? <String>[]),
          ),
        ],
      ),
    );
  }

  void _onRegRequest(ControlMessage message, String senderIp, int senderPort) {
    final int assignedSlot = _deviceSlots[message.from] ?? (_deviceSlots.length + 1);
    setState(() {
      _deviceSlots[message.from] = assignedSlot;
      _onlineDevices[message.from] = DateTime.now().millisecondsSinceEpoch;
    });

    final ControlMessage ack = ControlMessage(
      type: MessageTypes.regAck,
      messageId: 'regack-${DateTime.now().millisecondsSinceEpoch}',
      from: _deviceId,
      to: message.from,
      slot: assignedSlot,
      payload: <String, dynamic>{
        'serverTs': DateTime.now().millisecondsSinceEpoch,
      },
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    _udpService.sendUnicast(
      jsonPayload: ack.toJson(),
      ip: senderIp,
      port: senderPort,
    );
    _log('REG_REQ from ${message.from}, assigned slot=$assignedSlot');
  }

  void _onHelloMessage(ControlMessage hello) {
    setState(() {
      _onlineDevices[hello.from] = DateTime.now().millisecondsSinceEpoch;
      _deviceRoles[hello.from] = hello.payload?['role']?.toString() ?? 'unknown';
      _onlineDevices.removeWhere(
        (_, lastSeen) => DateTime.now().millisecondsSinceEpoch - lastSeen > 10000,
      );
      _deviceRoles.removeWhere((String deviceId, _) => !_onlineDevices.containsKey(deviceId));
    });
  }

  void _onDiscoverMessage(ControlMessage discover) {
    if (discover.from == _deviceId) {
      return;
    }
    _broadcastHello();
  }

  void _broadcastHello() {
    if (!_networkReady) {
      return;
    }
    final ControlMessage hello = ControlMessage(
      type: 'HELLO',
      messageId: 'hello-${DateTime.now().millisecondsSinceEpoch}',
      from: _deviceId,
      payload: <String, dynamic>{'role': 'controller'},
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    _udpService.sendBroadcast(jsonPayload: hello.toJson());
  }

  Future<void> _scanDevices() async {
    if (!_networkReady) {
      _log('Network not ready (status=$_networkStatus, port=$_port)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('网络未就绪：$_networkStatus'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (_isScanning) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在扫描中...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    setState(() {
      _isScanning = true;
      _onlineDevices.clear();
    });

    final ControlMessage discover = ControlMessage(
      type: 'DISCOVER',
      messageId: 'discover-${DateTime.now().millisecondsSinceEpoch}',
      from: _deviceId,
      payload: <String, dynamic>{'role': 'controller'},
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    for (int i = 0; i < 3; i++) {
      _udpService.sendBroadcast(jsonPayload: discover.toJson());
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    _log('DISCOVER broadcast sent on port=$_port');

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }
    setState(() {
      _isScanning = false;
    });
    _log('Scan completed, online devices: ${_onlineDevices.length}');
  }

  Future<void> _sendCommand() async {
    if (!_networkReady) {
      _log('Network not ready yet');
      return;
    }

    final String typeOrCommand = _commandController.text.trim();
    if (typeOrCommand.isEmpty) {
      return;
    }

    Map<String, dynamic>? payload;
    final String payloadText = _payloadController.text.trim();
    if (payloadText.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(payloadText);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } catch (_) {
        _log('Payload 不是有效 JSON，已忽略');
      }
    }

    final String msgId =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final ControlMessage packet = ControlMessage(
      type: typeOrCommand.startsWith('CMD_') ? typeOrCommand : MessageTypes.cmd,
      messageId: msgId,
      from: _deviceId,
      command: typeOrCommand.startsWith('CMD_') ? null : typeOrCommand,
      payload: payload ?? <String, dynamic>{'requestedBy': _deviceId},
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _ackDevices.clear();
    });

    for (int i = 0; i < 3; i++) {
      _udpService.sendBroadcast(jsonPayload: packet.toJson());
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    _log('Broadcast type=${packet.type}, cmd=${packet.command ?? '-'}, msgId=$msgId');
  }

  Future<void> _sendQuickType(String messageType, {String? abbr}) async {
    if (!_networkReady) {
      _log('Network not ready yet');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('网络未就绪：$_networkStatus'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final String msgId = 'quick-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final ControlMessage packet = ControlMessage(
      type: messageType,
      messageId: msgId,
      from: _deviceId,
      payload: <String, dynamic>{
        'requestedBy': _deviceId,
        if (abbr != null) 'abbr': abbr,
      },
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    for (int i = 0; i < 2; i++) {
      _udpService.sendBroadcast(jsonPayload: packet.toJson());
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    _log('Quick sent type=${packet.type}, msgId=$msgId');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已发送：${abbr ?? messageType}'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }

  void _log(String line) {
    setState(() {
      _logs.insert(0, '[${TimeOfDay.now().format(context)}] $line');
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
  }

  Color _getNetworkQualityColor(int latency) {
    if (latency < 50) return Colors.green;
    if (latency < 100) return Colors.orange;
    return Colors.red;
  }

  Color _getPingColor(int ping) {
    if (ping < 50) return Colors.green;
    if (ping < 100) return Colors.orange;
    return Colors.red;
  }

  String _getPingQualityText(int ping) {
    if (ping < 50) return '优秀';
    if (ping < 100) return '良好';
    if (ping < 200) return '一般';
    return '较差';
  }

  @override
  void dispose() {
    _deviceCleanupTimer?.cancel();
    _networkStatsTimer?.cancel();
    _eventSub?.cancel();
    _heartbeatTimer?.cancel();
    _networkReady = false;
    if (_networkServicesInitialized) {
      _deviceCleanupTimer?.cancel();
      _eventSub?.cancel();
      _commandService.dispose();
      _udpService.dispose();
      _reliableUdpService.dispose();
    }
    _commandController.dispose();
    _payloadController.dispose();
    _targetDeviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('控制端')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          _hasNetworkError ? Icons.error : _networkReady ? Icons.wifi : Icons.wifi_off,
                          color: _hasNetworkError ? Colors.red : _networkReady ? Colors.green : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Device ID: $_deviceId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _hasNetworkError ? Colors.red : null,
                              fontWeight: _hasNetworkError ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _hasNetworkError ? Colors.red.shade50 : _networkReady ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _hasNetworkError ? Colors.red.shade200 : _networkReady ? Colors.green.shade200 : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            _hasNetworkError ? Icons.error_outline : _networkReady ? Icons.check_circle : Icons.hourglass_empty,
                            color: _hasNetworkError ? Colors.red : _networkReady ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _networkStatus,
                              style: TextStyle(
                                color: _hasNetworkError ? Colors.red.shade700 : _networkReady ? Colors.green.shade700 : Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_hasNetworkError) ...<Widget>[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _retryNetworkStart,
                              icon: const Icon(Icons.refresh, size: 20),
                              tooltip: '重试',
                              color: Colors.red,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isScanning ? null : _scanDevices,
                            icon: const Icon(Icons.wifi_tethering),
                            label: Text(_isScanning ? '扫描中...' : '扫描在线设备'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(label: Text('在线 ${_onlineDevices.length}')),
                        if (_networkStats != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Chip(
                            avatar: Icon(
                              Icons.network_check,
                              size: 16,
                              color: _getNetworkQualityColor(_networkStats!.latency),
                            ),
                            label: Text(
                              '${_networkStats!.latency}ms',
                              style: TextStyle(
                                color: _getNetworkQualityColor(_networkStats!.latency),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: _getNetworkQualityColor(_networkStats!.latency).withOpacity(0.1),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _onlineDevices.isEmpty
                          ? '设备列表: 暂无'
                          : '设备列表: ${_onlineDevices.keys.join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_onlineDevices.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _onlineDevices.entries.map((MapEntry<String, int> entry) {
                          final String deviceId = entry.key;
                          final String role = _deviceRoles[deviceId] ?? 'unknown';
                          final int? slot = _deviceSlots[deviceId];
                          final int? ping = _devicePingResults[deviceId];
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ActionChip(
                                onPressed: () => _showDeviceDetails(deviceId),
                                avatar: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.phone_android, size: 16),
                                    if (ping != null) ...<Widget>[
                                      const SizedBox(width: 2),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _getPingColor(ping),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                label: Text(
                                  '${slot == null ? '-' : slot}号 $role · ${_timeAgoLabel(entry.value)}${ping != null ? ' · ${ping}ms' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // 发送按钮
                              OutlinedButton.icon(
                                onPressed: () => _showSendToDeviceDialog(deviceId),
                                icon: const Icon(Icons.send, size: 14),
                                label: const Text('发送'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  minimumSize: const Size(0, 28),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DefaultTabController(
                length: 11,
                child: Card(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: Column(
                      children: <Widget>[
                        // 优化的TabBar
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: TabBar(
                            isScrollable: true,
                            tabAlignment: TabAlignment.center,
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            unselectedLabelStyle: const TextStyle(fontSize: 11),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tabs: const <Tab>[
                              Tab(text: '指令', icon: Icon(Icons.send, size: 16)),
                              Tab(text: '连接', icon: Icon(Icons.link, size: 16)),
                              Tab(text: '遥测', icon: Icon(Icons.sensors, size: 16)),
                              Tab(text: '直播', icon: Icon(Icons.live_tv, size: 16)),
                              Tab(text: '采集', icon: Icon(Icons.camera_alt, size: 16)),
                              Tab(text: '上传', icon: Icon(Icons.upload, size: 16)),
                              Tab(text: '硬件', icon: Icon(Icons.settings, size: 16)),
                              Tab(text: '告警', icon: Icon(Icons.warning, size: 16)),
                              Tab(text: '维护', icon: Icon(Icons.build, size: 16)),
                              Tab(text: '网页', icon: Icon(Icons.language, size: 16)),
                              Tab(text: '日志', icon: Icon(Icons.list_alt, size: 16)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: TabBarView(
                            children: <Widget>[
                              _buildCommandTab(),
                              _buildCategoryTab('连接'),
                              _buildCategoryTab('遥测'),
                              _buildCategoryTab('直播'),
                              _buildCategoryTab('采集'),
                              _buildCategoryTab('上传'),
                              _buildCategoryTab('硬件'),
                              _buildCategoryTab('告警'),
                              _buildCategoryTab('维护'),
                              _buildCategoryTab('网页'),
                              _buildLogTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

  /// 显示发送到指定设备对话框
  void _showSendToDeviceDialog(String deviceId) {
    final TextEditingController ipController = TextEditingController();
    final TextEditingController portController = TextEditingController(text: '$_port');
    
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('发送到设备: ${deviceId.length > 15 ? '${deviceId.substring(0, 15)}...' : deviceId}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('请输入目标设备的IP和端口（留空使用广播）'),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'IP地址',
                  hintText: '例如: 192.168.1.100',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: '端口',
                  hintText: '默认: 50001',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final String ip = ipController.text.trim();
                final int port = int.tryParse(portController.text) ?? _port;
                Navigator.of(context).pop();
                _sendToDevice(deviceId, ip.isEmpty ? null : ip, port);
              },
              child: const Text('发送'),
            ),
          ],
        );
      },
    );
  }

  /// 发送到指定设备
  Future<void> _sendToDevice(String deviceId, String? ip, int port) async {
    if (!_networkReady) {
      _log('Network not ready yet');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('网络未就绪：$_networkStatus'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final String typeOrCommand = _commandController.text.trim();
    if (typeOrCommand.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先输入命令或选择快捷操作'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final String msgId = 'unicast-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final ControlMessage packet = ControlMessage(
      type: typeOrCommand,
      messageId: msgId,
      from: _deviceId,
      to: deviceId,
      command: _payloadController.text.trim().isEmpty ? null : _payloadController.text.trim(),
      payload: <String, dynamic>{
        'requestedBy': _deviceId,
        if (ip != null) 'targetIp': ip,
        'targetPort': port,
      },
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      if (ip != null && ip.isNotEmpty) {
        // 单播
        await _reliableUdpService.sendUnicast(
          jsonPayload: packet.toJson(),
          ip: ip,
          port: port,
        );
        _log('Unicast sent to $deviceId ($ip:$port), type=${packet.type}, msgId=$msgId');
      } else {
        // 广播但指定目标设备
        await _reliableUdpService.sendBroadcast(
          jsonPayload: packet.toJson(),
          retries: 2,
        );
        _log('Broadcast sent targeting $deviceId, type=${packet.type}, msgId=$msgId');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ip != null ? '已单发到 $ip:$port' : '已广播发送（目标：$deviceId）'),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
    } catch (e) {
      _log('Send to device failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
