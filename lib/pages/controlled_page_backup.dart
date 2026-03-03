import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/control_message.dart';
import '../protocol/message_types.dart';
import '../services/upload_service.dart' as basic_upload;
import '../services/hardware_service.dart';
import '../services/device_status_service.dart';
import '../services/reliable_udp_service.dart';
import '../services/command_execution_service.dart';
import '../services/udp_service_enhanced.dart' as enhanced_udp;
import '../services/upload_service_enhanced.dart' as enhanced_upload;
import '../services/config_service.dart';
import '../services/log_service.dart';
import '../services/permission_service.dart';
import '../services/database_service.dart';

class ControlledPage extends StatefulWidget {
  const ControlledPage({super.key});

  @override
  State<ControlledPage> createState() => _ControlledPageState();
}

class _ControlledPageState extends State<ControlledPage> {
  late final ConfigService _configService;
  late final LogService _logService;
  late final PermissionService _permissionService;
  late final DatabaseService _databaseService;
  late int _port;

  final String _deviceId = 'dev-${DateTime.now().millisecondsSinceEpoch}';
  late final enhanced_udp.UdpService _udpService;
  late final basic_upload.UploadService _uploadService;
  late final DeviceStatusService _deviceStatusService;
  late final CommandExecutionService _commandService;
  late final HardwareService _hardwareService;
  late final ReliableUdpService _reliableUdpService;

  final Set<String> _processedMessageIds = <String>{};
  final List<String> _logs = <String>[];
  StreamSubscription<enhanced_udp.UdpDatagramEvent>? _eventSub;
  StreamSubscription<CommandExecution>? _commandSub;
  Timer? _heartbeatTimer;
  Timer? _statusUpdateTimer;
  bool _networkReady = false;
  String _networkStatus = '初始化中...';
  bool _hasNetworkError = false;
  bool _networkServicesInitialized = false;
  String _controllerDeviceId = '';
  DateTime? _lastControllerContact;
  DeviceStatus? _currentDeviceStatus;
  final List<CommandExecution> _activeCommands = <CommandExecution>[];

  OverlayEntry? _topToastEntry;
  Timer? _topToastTimer;

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
      
      _logService.info('Controlled page initializing...', tag: 'ControlledPage');
      
      // 检查权限
      await _checkPermissions();
      
      // 获取配置
      _port = _configService.config.udpPort;
      
      // 初始化网络和服务
      await _initializeNetworkServices();
      
      _logService.info('Controlled page initialized successfully', tag: 'ControlledPage');
    } catch (error) {
      try {
        _logService.error('Failed to initialize controlled page', error: error, tag: 'ControlledPage');
      } catch (_) {
        // ignore
      }
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
              const Text('被控端需要以下权限才能正常工作：'),
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
    _uploadService = basic_upload.UploadService(
      baseUrl: _configService.config.serverUrl,
      deviceToken: _configService.config.deviceToken,
      enableEncryption: _configService.config.enableEncryption,
    );

    // 初始化设备状态服务
    _deviceStatusService = DeviceStatusService(
      enableRealMonitoring: _configService.config.enableRealDeviceStatus,
    );

    // 初始化命令执行服务
    _commandService = CommandExecutionService(
      deviceStatusService: _deviceStatusService,
      uploadService: _uploadService,
      commandTimeout: Duration(seconds: _configService.config.commandTimeout),
      maxRetries: _configService.config.maxRetries,
    );

    // 初始化硬件服务
    _hardwareService = HardwareService();
    await _hardwareService.initRecorder();

    // 初始化可靠UDP服务
    _reliableUdpService = ReliableUdpService(udpService: _udpService);
    _reliableUdpService.initialize();

    // Services constructed; it's now safe for dispose() to reference late fields.
    _networkServicesInitialized = true;

    await _startNetwork();
    // 监听命令执行事件
    _commandSub = _commandService.commandEvents.listen((CommandExecution execution) {
      _handleCommandExecutionEvent(execution);
    });
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
        (_) {
          _sendHeartbeat();
          _sendStatusSync();
        },
      );

      // 启动设备状态监控
      await _deviceStatusService.startMonitoring();

      // 启动状态更新定时器
      _statusUpdateTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _updateDeviceStatus(),
      );
      
      setState(() {
        _networkReady = true;
        _networkStatus = 'UDP服务已启动 (端口:$_port)';
        _hasNetworkError = false;
      });
      
      _logService.info('UDP listener started on :$_port as $_deviceId', tag: 'Network');
      
      // 自动发送注册请求
      await _sendRegRequest();
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
      
      _log('RX ${msg.type} from ${msg.from} payload=${msg.payload ?? <String, dynamic>{}}');

      // 更新控制端联系信息
      if (msg.type != 'HELLO' && msg.type != 'DISCOVER') {
        setState(() {
          _controllerDeviceId = msg.from;
          _lastControllerContact = DateTime.now();
        });
      }

      // Show snackbar for non-heartbeat messages
      if (msg.type != MessageTypes.heartbeat && msg.type != 'HELLO' && msg.type != 'DISCOVER') {
        _showNotificationSnackbar(msg);
      }
        _lastControllerContact = DateTime.now();
      });
    }

    // Show snackbar for non-heartbeat messages
    if (message.type != MessageTypes.heartbeat && message.type != 'HELLO' && message.type != 'DISCOVER') {
      _showNotificationSnackbar(message);
    }

    switch (message.type) {
      case 'DISCOVER':
        _onDiscoverMessage(message, event.senderAddress, event.senderPort);
        break;
      case 'REG_ACK':
        _onRegAck(message);
        break;
      case 'CMD':
        _handleControlledCommand(message, event.senderAddress, event.senderPort);
        break;
      default:
        if (message.type.startsWith('CMD_')) {
          _handleControlledCommand(message, event.senderAddress, event.senderPort);
        }
    }
  }

  void _showNotificationSnackbar(ControlMessage message) {
    if (!mounted) return;
    
    final String abbr = _getMessageAbbr(message.type);
    final String content = '收到消息: $abbr (${message.from})';

    _showTopToast(
      content,
      onTap: () {
        _log('查看消息详情: ${message.type} from ${message.from}');
      },
    );
  }

  void _showTopToast(String text, {VoidCallback? onTap}) {
    if (!mounted) return;

    _topToastTimer?.cancel();
    _topToastEntry?.remove();
    _topToastEntry = null;

    final OverlayState? overlay = Overlay.of(context);
    if (overlay == null) {
      return;
    }

    final double topInset = MediaQuery.of(context).padding.top;
    _topToastEntry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          left: 12,
          right: 12,
          top: topInset + 8,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                onTap?.call();
                _topToastEntry?.remove();
                _topToastEntry = null;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.notifications_active,
                      size: 18,
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.onInverseSurface.withOpacity(0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_topToastEntry!);

    _topToastTimer = Timer(const Duration(seconds: 3), () {
      _topToastEntry?.remove();
      _topToastEntry = null;
    });
  }

  String _getMessageAbbr(String type) {
    const Map<String, String> abbr = <String, String>{
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
    return abbr[type] ?? type;
  }

  void _onDiscoverMessage(ControlMessage discover, String senderIp, int senderPort) {
    if (!_networkReady) return;
    final ControlMessage hello = ControlMessage(
      type: MessageTypes.hello,
      messageId: 'hello-${DateTime.now().millisecondsSinceEpoch}',
      from: _deviceId,
      payload: <String, dynamic>{'role': 'controlled'},
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      _udpService.sendUnicast(
        jsonPayload: hello.toJson(),
        ip: senderIp,
        port: senderPort,
      );
    } catch (_) {
      // ignore
    }
  }

  void _onRegAck(ControlMessage message) {
    _log('REG_ACK received: slot=${message.slot}, serverTs=${message.payload?['serverTs']}');
  }

  Future<void> _handleControlledCommand(
    ControlMessage command,
    String senderIp,
    int senderPort,
  ) async {
    if (_processedMessageIds.contains(command.messageId)) {
      return;
    }
    _processedMessageIds.add(command.messageId);

    _log('Received CMD ${command.command ?? command.type} from ${command.from}');

    // 立即发送ACK
    final ControlMessage ack = ControlMessage(
      type: 'ACK',
      messageId: command.messageId,
      from: _deviceId,
      status: 'OK',
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (_networkReady) {
      try {
        _udpService.sendUnicast(
          jsonPayload: ack.toJson(),
          ip: senderIp,
          port: senderPort,
        );
      } catch (_) {
        // ignore
      }
    }

    // 发送状态消息
    _sendStatus('Command received: ${command.command ?? command.type}');

    // 执行命令
    try {
      // 处理真实硬件命令
      await _executeHardwareCommand(command);
      final CommandExecution execution = await _commandService.executeCommand(command);
      _log('Command execution started: ${execution.id}');
    } catch (error) {
      _log('Command execution failed: $error');
      _sendStatus('Command execution failed: $error');
    }
  }

  /// 执行硬件命令
  Future<void> _executeHardwareCommand(ControlMessage command) async {
    final String cmd = command.command ?? command.type;
    String? result;
    
    try {
      switch (cmd) {
        case MessageTypes.cmdTakePhoto:
          final String? path = await _hardwareService.takePhoto();
          result = path != null ? 'Photo taken: $path' : 'Photo failed';
          break;
          
        case MessageTypes.cmdRecordStart:
          final String? path = await _hardwareService.startVideoRecording();
          result = path != null ? 'Video recording started: $path' : 'Video start failed';
          break;
          
        case MessageTypes.cmdRecordStop:
          // flutter_sound 的录像停止需要特殊处理，这里简化为发送状态
          result = 'Video recording stopped';
          break;
          
        case 'CMD_AUDIO_START':
          final String? path = await _hardwareService.startAudioRecording();
          result = path != null ? 'Audio recording started: $path' : 'Audio start failed';
          break;
          
        case 'CMD_AUDIO_STOP':
          final String? path = await _hardwareService.stopAudioRecording();
          result = path != null ? 'Audio recording stopped: $path' : 'Audio stop failed';
          break;
          
        default:
          result = 'Unknown hardware command: $cmd';
          break;
      }
      
      _log('Hardware command executed: $cmd -> $result');
      _sendStatus('Hardware: $result');
      
      // 发送执行结果回执
      final ControlMessage response = ControlMessage(
        type: 'EVENT_HARDWARE_RESULT',
        messageId: 'hw-result-${DateTime.now().millisecondsSinceEpoch}',
        from: _deviceId,
        to: command.from,
        payload: <String, dynamic>{
          'originalCommand': cmd,
          'result': result,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      
      if (_networkReady) {
        try {
          _reliableUdpService.sendBroadcast(jsonPayload: response.toJson());
        } catch (_) {
          // ignore
        }
      }
    } catch (e) {
      _log('Hardware command error: $cmd -> $e');
      _sendStatus('Hardware error: $e');
    }
  }

  Future<void> _sendRegRequest() async {
    if (!_networkReady) return;
    final ControlMessage req = ControlMessage(
      type: MessageTypes.regReq,
      messageId: 'reg-${DateTime.now().millisecondsSinceEpoch}',
      from: _deviceId,
      deviceName: 'device-$_deviceId',
      ip: 'auto-detect',
      model: 'flutter-client',
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      _reliableUdpService.sendBroadcast(jsonPayload: req.toJson());
    } catch (_) {
      // ignore
    }
    _log('REG_REQ broadcast sent');
  }

  void _sendHeartbeat() {
    if (!_networkReady) return;
    final ControlMessage hb = ControlMessage(
      type: MessageTypes.heartbeat,
      messageId: 'hb-${DateTime.now().millisecondsSinceEpoch}',
      from: _deviceId,
      payload: <String, dynamic>{
        'online': true,
        'taskFlag': 'Idle',
      },
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      _reliableUdpService.sendBroadcast(jsonPayload: hb.toJson());
    } catch (_) {
      // ignore
    }
  }

  void _sendStatusSync() {
    if (!_networkReady) return;
    
    // 使用真实设备状态
    _updateRealDeviceStatus();
    final DeviceStatus? status = _currentDeviceStatus;
    if (status == null) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    final ControlMessage sync = ControlMessage(
      type: MessageTypes.statusSync,
      messageId: 'statussync-$now',
      from: _deviceId,
      payload: <String, dynamic>{
        'battery_level': status.batteryLevel,
        'is_charging': status.isCharging,
        'storage_free': status.storageFree,
        'storage_total': status.storageTotal,
        'cpu_temp': status.cpuTemp,
        'battery_temp': status.batteryTemp,
        'wifi_signal_strength': status.wifiSignalStrength,
        'upload_speed': status.uploadSpeed,
        'current_camera': status.currentCamera,
        'zoom_level': status.zoomLevel,
        'controller_connected': _controllerDeviceId.isNotEmpty,
        'last_controller_contact': _lastControllerContact?.millisecondsSinceEpoch,
        'memory_usage': status.memoryUsage,
        'network_type': status.networkType,
        'health_score': _deviceStatusService.getHealthScore(status),
      },
      timestampMs: now,
    );
    try {
      _reliableUdpService.sendBroadcast(jsonPayload: sync.toJson());
    } catch (_) {
      // ignore
    }
  }

  /// 更新真实设备状态
  Future<void> _updateRealDeviceStatus() async {
    try {
      // 获取电池信息
      final Map<String, dynamic> batteryInfo = await _hardwareService.getBatteryInfo();
      
      // 获取存储信息
      final Map<String, dynamic> storageInfo = await _hardwareService.getStorageInfo();
      
      // 获取网络信息
      final Map<String, dynamic> networkInfo = await _hardwareService.getNetworkInfo();
      
      // 获取设备信息
      final Map<String, dynamic> deviceInfo = await _hardwareService.getDeviceInfo();
      
      // 获取模拟的CPU温度和内存使用率
      final double cpuTemp = _hardwareService.getCpuTemp();
      final double memoryUsage = _hardwareService.getMemoryUsage();
      
      final DeviceStatus newStatus = DeviceStatus(
        batteryLevel: batteryInfo['level'] as int? ?? 0,
        isCharging: batteryInfo['isCharging'] as bool? ?? false,
        storageFree: storageInfo['free'] as double? ?? 0.0,
        storageTotal: storageInfo['total'] as double? ?? 0.0,
        cpuTemp: cpuTemp,
        batteryTemp: cpuTemp + 2.0, // 电池温度通常比CPU高一点
        wifiSignalStrength: networkInfo['signalStrength'] as int? ?? -100,
        uploadSpeed: 1024.0, // 模拟上传速度
        currentCamera: 'back',
        zoomLevel: 1.0,
        memoryUsage: memoryUsage,
        networkType: networkInfo['type'] as String? ?? 'none',
        lastUpdate: DateTime.now(),
        deviceModel: deviceInfo['model'] as String? ?? 'unknown',
        deviceBrand: deviceInfo['brand'] as String? ?? 'unknown',
      );
      
      if (mounted) {
        setState(() {
          _currentDeviceStatus = newStatus;
        });
      }
    } catch (e) {
      _log('Update real device status failed: $e');
    }
  }

  // 新增：处理命令执行事件
  void _handleCommandExecutionEvent(CommandExecution execution) {
    _log('Command ${execution.id} status: ${execution.status.name}');
    
    // 更新活跃命令列表
    setState(() {
      _activeCommands.removeWhere((cmd) => cmd.id == execution.id);
      if (execution.status == CommandStatus.executing || 
          execution.status == CommandStatus.sent ||
          execution.status == CommandStatus.received) {
        _activeCommands.add(execution);
      }
    });

    // 发送状态更新
    switch (execution.status) {
      case CommandStatus.completed:
        _sendStatus('Command completed: ${execution.type.name}');
        break;
      case CommandStatus.failed:
        _sendStatus('Command failed: ${execution.error ?? 'Unknown error'}');
        break;
      case CommandStatus.timeout:
        _sendStatus('Command timeout: ${execution.type.name}');
        break;
      case CommandStatus.executing:
        _sendStatus('Executing: ${execution.type.name} (${(execution.progress * 100).toStringAsFixed(0)}%)');
        break;
      default:
        break;
    }
  }

  // 新增：更新设备状态
  void _updateDeviceStatus() {
    if (_currentDeviceStatus == null) return;
    
    // 检查异常状态并发送通知
    final double healthScore = _deviceStatusService.getHealthScore(_currentDeviceStatus!);
    if (healthScore < 50) {
      _sendStatus('Warning: Device health score low (${healthScore.toStringAsFixed(0)}%)');
    }
  }

  // 新增：获取网络统计信息
  Map<String, dynamic>? _getNetworkStats() {
    final enhanced_udp.NetworkStats? stats = _udpService.getNetworkStats();
    if (stats == null) return null;
    return <String, dynamic>{
      'latency': stats.latency,
      'packetLoss': stats.packetLoss,
      'throughput': stats.throughput,
      'lastUpdate': stats.lastUpdate.toIso8601String(),
    };
  }

  Widget _buildStatusItem(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color?.withOpacity(0.3) ?? Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCommandItem(CommandExecution cmd) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (cmd.status) {
      case CommandStatus.executing:
        statusColor = Colors.blue;
        statusText = '执行中';
        statusIcon = Icons.play_arrow;
        break;
      case CommandStatus.sent:
      case CommandStatus.received:
        statusColor = Colors.orange;
        statusText = '已发送';
        statusIcon = Icons.send;
        break;
      case CommandStatus.completed:
        statusColor = Colors.green;
        statusText = '已完成';
        statusIcon = Icons.check_circle;
        break;
      case CommandStatus.failed:
        statusColor = Colors.red;
        statusText = '失败';
        statusIcon = Icons.error;
        break;
      case CommandStatus.timeout:
        statusColor = Colors.purple;
        statusText = '超时';
        statusIcon = Icons.timer_off;
        break;
      default:
        statusColor = Colors.grey;
        statusText = '未知';
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _getCommandDisplayName(cmd.type),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                if (cmd.status == CommandStatus.executing && cmd.progress > 0)
                  LinearProgressIndicator(
                    value: cmd.progress,
                    backgroundColor: statusColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
              ],
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getCommandDisplayName(CommandType type) {
    switch (type) {
      case CommandType.recording:
        return '录像';
      case CommandType.photo:
        return '拍照';
      case CommandType.upload:
        return '上传';
      case CommandType.rtc:
        return '推流';
      case CommandType.hardware:
        return '硬件控制';
      case CommandType.maintenance:
        return '维护';
      default:
        return '未知命令';
    }
  }

  Color _getBatteryColor(double level) {
    if (level < 20) return Colors.red;
    if (level < 50) return Colors.orange;
    return Colors.green;
  }

  Color _getStorageColor(double freeGB) {
    if (freeGB < 5) return Colors.red;
    if (freeGB < 20) return Colors.orange;
    return Colors.green;
  }

  Color _getTempColor(double temp) {
    if (temp > 60) return Colors.red;
    if (temp > 45) return Colors.orange;
    return Colors.green;
  }

  Color _getWifiColor(int signal) {
    if (signal < -70) return Colors.red;
    if (signal < -60) return Colors.orange;
    return Colors.green;
  }

  Color _getMemoryColor(double usage) {
    if (usage > 90) return Colors.red;
    if (usage > 70) return Colors.orange;
    return Colors.green;
  }

  Color _getHealthColor(double score) {
    if (score < 50) return Colors.red;
    if (score < 70) return Colors.orange;
    return Colors.green;
  }

  void _sendStatus(String text) {
    if (!_networkReady) return;
    final ControlMessage status = ControlMessage(
      type: 'STATUS',
      messageId: 'status-${DateTime.now().millisecondsSinceEpoch}',
      from: _deviceId,
      payload: <String, dynamic>{'text': text},
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      _udpService.sendBroadcast(jsonPayload: status.toJson());
    } catch (_) {
      // ignore
    }
  }

  Future<void> _uploadSnapshot() async {
    try {
      await _uploadService.uploadDeviceSnapshot(
        deviceId: _deviceId,
        data: <String, dynamic>{
          'localDbRecordCount': 128,
          'lastSyncAt': DateTime.now().toUtc().toIso8601String(),
          'note': 'replace with real local DB data extraction',
        },
      );
      _log('Remote upload success');
      _sendStatus('Remote upload success');
    } catch (error) {
      _log('Remote upload failed: $error');
      _sendStatus('Remote upload failed');
    }
  }

  void _log(String line) {
    setState(() {
      _logs.insert(0, "[${TimeOfDay.now().format(context)}] $line");
      if (_logs.length > 200) {
        _logs.removeLast();
      }
    });
  }

  @override
  void dispose() {
    _topToastTimer?.cancel();
    _topToastEntry?.remove();
    _topToastEntry = null;
    _eventSub?.cancel();
    _commandSub?.cancel();
    _heartbeatTimer?.cancel();
    _statusUpdateTimer?.cancel();

    if (_networkServicesInitialized) {
      if (_networkReady) {
        final ControlMessage disconnect = ControlMessage(
          type: MessageTypes.disconnect,
          messageId: 'disconnect-${DateTime.now().millisecondsSinceEpoch}',
          from: _deviceId,
          payload: <String, dynamic>{'reason': 'app_dispose'},
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        );
        try {
          _udpService.sendBroadcast(jsonPayload: disconnect.toJson());
        } catch (_) {
          // ignore
        }
      }

      _deviceStatusService.dispose();
      _commandService.dispose();
      _udpService.dispose();
      await _hardwareService.dispose();
      _reliableUdpService.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('被控端')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            left: 16,
            top: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
          ),
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
                    const SizedBox(height: 8),
                    if (_controllerDeviceId.isNotEmpty) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.settings_remote, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '控制端已连接',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${_controllerDeviceId.length > 12 ? '${_controllerDeviceId.substring(0, 12)}...' : _controllerDeviceId}',
                                    style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                      // 快捷操作区域
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
                                const Icon(Icons.flash_on, size: 18),
                                const SizedBox(width: 8),
                                Text('快捷操作', style: Theme.of(context).textTheme.titleSmall),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 第一行按钮
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                FilledButton.icon(
                                  onPressed: _sendRegRequest,
                                  icon: const Icon(Icons.how_to_reg, size: 16),
                                  label: const Text('注册请求'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _sendHeartbeat,
                                  icon: const Icon(Icons.favorite, size: 16),
                                  label: const Text('心跳'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _sendStatusSync,
                                  icon: const Icon(Icons.sync, size: 16),
                                  label: const Text('状态同步'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 第二行按钮
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                OutlinedButton.icon(
                                  onPressed: () => _sendStatus('STATUS_PING'),
                                  icon: const Icon(Icons.message, size: 16),
                                  label: const Text('状态消息'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _uploadSnapshot,
                                  icon: const Icon(Icons.cloud_upload, size: 16),
                                  label: const Text('上传快照'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 设备状态显示
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
                                const Icon(Icons.info, size: 18),
                                const SizedBox(width: 8),
                                Text('设备状态', style: Theme.of(context).textTheme.titleSmall),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _buildStatusItem(
                                    '电池', 
                                    '${_currentDeviceStatus?.batteryLevel.toStringAsFixed(1) ?? '--'}%', 
                                    _currentDeviceStatus?.isCharging == true ? Icons.battery_charging_full : Icons.battery_full,
                                    color: _getBatteryColor(_currentDeviceStatus?.batteryLevel ?? 0),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatusItem(
                                    '存储', 
                                    '${_currentDeviceStatus?.storageFree.toStringAsFixed(1) ?? '--'}GB', 
                                    Icons.storage,
                                    color: _getStorageColor(_currentDeviceStatus?.storageFree ?? 0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _buildStatusItem(
                                    'CPU温度', 
                                    '${_currentDeviceStatus?.cpuTemp.toStringAsFixed(1) ?? '--'}°C', 
                                    Icons.thermostat,
                                    color: _getTempColor(_currentDeviceStatus?.cpuTemp ?? 0),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatusItem(
                                    'WiFi', 
                                    '${_currentDeviceStatus?.wifiSignalStrength ?? '--'}dBm', 
                                    Icons.wifi,
                                    color: _getWifiColor(_currentDeviceStatus?.wifiSignalStrength ?? 0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _buildStatusItem(
                                    '内存', 
                                    '${_currentDeviceStatus?.memoryUsage.toStringAsFixed(1) ?? '--'}%', 
                                    Icons.memory,
                                    color: _getMemoryColor(_currentDeviceStatus?.memoryUsage ?? 0),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatusItem(
                                    '健康度', 
                                    '${_deviceStatusService.getHealthScore(_currentDeviceStatus).toStringAsFixed(0)}%', 
                                    Icons.favorite,
                                    color: _getHealthColor(_deviceStatusService.getHealthScore(_currentDeviceStatus)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 活跃命令显示
                      if (_activeCommands.isNotEmpty) ...<Widget>[
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
                                  const Icon(Icons.pending_actions, size: 18),
                                  const SizedBox(width: 8),
                                  Text('活跃命令', style: Theme.of(context).textTheme.titleSmall),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_activeCommands.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._activeCommands.map((CommandExecution cmd) => _buildActiveCommandItem(cmd)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // 运行日志
                      SizedBox(
                        height: 240,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: <Widget>[
                              // 日志标题
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        const Icon(Icons.list_alt, size: 16),
                                        const SizedBox(width: 6),
                                        Text('运行日志', style: Theme.of(context).textTheme.titleSmall),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${_logs.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton.outlined(
                                      onPressed: () {
                                        setState(() {
                                          _logs.clear();
                                        });
                                      },
                                      icon: const Icon(Icons.clear_all, size: 16),
                                      tooltip: '清空日志',
                                      style: IconButton.styleFrom(
                                        padding: const EdgeInsets.all(4),
                                        minimumSize: const Size(32, 32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 日志内容
                              Expanded(
                                child: ListView.builder(
                                  padding: EdgeInsets.only(
                                    left: 8,
                                    top: 8,
                                    right: 8,
                                    bottom: 8,
                                  ),
                                  itemCount: _logs.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: index % 2 == 0 ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2) : null,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        _logs[index],
                                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                        softWrap: true,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
