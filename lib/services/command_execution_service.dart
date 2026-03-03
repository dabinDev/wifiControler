import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/control_message.dart';
import '../protocol/message_types.dart';
import 'device_status_service.dart';
import 'upload_service.dart';

enum CommandStatus {
  pending,    // 待发送
  sent,       // 已发送
  received,   // 已接收
  executing,  // 执行中
  completed,  // 已完成
  failed,     // 执行失败
  timeout,    // 超时
}

enum CommandType {
  recording,  // 录像
  photo,      // 拍照
  upload,     // 上传
  rtc,        // 推流
  hardware,   // 硬件控制
  maintenance,// 维护
  unknown,    // 未知
}

class CommandExecution {
  const CommandExecution({
    required this.id,
    required this.type,
    required this.originalMessage,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.receivedAt,
    this.completedAt,
    this.result,
    this.error,
    this.progress = 0.0,
    this.retryCount = 0,
  });

  final String id;
  final CommandType type;
  final ControlMessage originalMessage;
  final CommandStatus status;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? receivedAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? result;
  final String? error;
  final double progress; // 0.0-1.0
  final int retryCount;

  Duration? get executionTime {
    if (completedAt == null) return null;
    return completedAt!.difference(createdAt);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'sentAt': sentAt?.millisecondsSinceEpoch,
    'receivedAt': receivedAt?.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'result': result,
    'error': error,
    'progress': progress,
    'retryCount': retryCount,
    'executionTime': executionTime?.inMilliseconds,
  };

  CommandExecution copyWith({
    CommandStatus? status,
    DateTime? sentAt,
    DateTime? receivedAt,
    DateTime? completedAt,
    Map<String, dynamic>? result,
    String? error,
    double? progress,
    int? retryCount,
  }) {
    return CommandExecution(
      id: id,
      type: type,
      originalMessage: originalMessage,
      status: status ?? this.status,
      createdAt: createdAt,
      sentAt: sentAt ?? this.sentAt,
      receivedAt: receivedAt ?? this.receivedAt,
      completedAt: completedAt ?? this.completedAt,
      result: result ?? this.result,
      error: error ?? this.error,
      progress: progress ?? this.progress,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

class CommandExecutionService {
  CommandExecutionService({
    required this.deviceStatusService,
    required this.uploadService,
    this.commandTimeout = const Duration(seconds: 30),
    this.maxRetries = 3,
  });

  final DeviceStatusService deviceStatusService;
  final UploadService uploadService;
  final Duration commandTimeout;
  final int maxRetries;

  final Map<String, CommandExecution> _activeCommands = <String, CommandExecution>{};
  final StreamController<CommandExecution> _commandEventsController = 
      StreamController<CommandExecution>.broadcast();
  final List<CommandExecution> _commandHistory = <CommandExecution>[];
  
  Timer? _timeoutTimer;

  Stream<CommandExecution> get commandEvents => _commandEventsController.stream;
  
  List<CommandExecution> get commandHistory => List<CommandExecution>.unmodifiable(_commandHistory);
  List<CommandExecution> get activeCommands => _activeCommands.values.toList();

  Future<CommandExecution> executeCommand(ControlMessage command) async {
    final String executionId = 'exec-${DateTime.now().millisecondsSinceEpoch}';
    final CommandType commandType = _getCommandType(command.type);
    
    final CommandExecution execution = CommandExecution(
      id: executionId,
      type: commandType,
      originalMessage: command,
      status: CommandStatus.pending,
      createdAt: DateTime.now(),
    );
    
    _activeCommands[executionId] = execution;
    _addToHistory(execution);
    _commandEventsController.add(execution);
    
    // 开始执行
    unawaited(_performExecution(execution));
    
    return execution;
  }

  Future<void> _performExecution(CommandExecution execution) async {
    try {
      // 1. 标记为已发送
      final CommandExecution sentExecution = execution.copyWith(
        status: CommandStatus.sent,
        sentAt: DateTime.now(),
      );
      _updateExecution(sentExecution);
      
      // 模拟网络延迟
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 2. 标记为已接收
      final CommandExecution receivedExecution = sentExecution.copyWith(
        status: CommandStatus.received,
        receivedAt: DateTime.now(),
      );
      _updateExecution(receivedExecution);
      
      // 3. 执行具体命令
      final CommandExecution executingExecution = receivedExecution.copyWith(
        status: CommandStatus.executing,
      );
      _updateExecution(executingExecution);
      
      final Map<String, dynamic> result = await _executeSpecificCommand(executingExecution);
      
      // 4. 标记为完成
      final CommandExecution completedExecution = executingExecution.copyWith(
        status: CommandStatus.completed,
        completedAt: DateTime.now(),
        result: result,
        progress: 1.0,
      );
      _updateExecution(completedExecution);
      
    } catch (error) {
      // 执行失败
      final CommandExecution failedExecution = execution.copyWith(
        status: CommandStatus.failed,
        completedAt: DateTime.now(),
        error: error.toString(),
      );
      _updateExecution(failedExecution);
    }
  }

  Future<Map<String, dynamic>> _executeSpecificCommand(CommandExecution execution) async {
    final String commandType = execution.originalMessage.type;
    final Map<String, dynamic>? payload = execution.originalMessage.payload;
    
    switch (commandType) {
      case MessageTypes.cmdRecordStart:
        return await _executeRecordStart(payload);
        
      case MessageTypes.cmdRecordStop:
        return await _executeRecordStop();
        
      case MessageTypes.cmdTakePhoto:
        return await _executeTakePhoto(payload);
        
      case MessageTypes.cmdFileUpload:
        return await _executeFileUpload(payload);
        
      case MessageTypes.cmdRtcStart:
        return await _executeRtcStart(payload);
        
      case MessageTypes.cmdRtcStop:
        return await _executeRtcStop();
        
      case MessageTypes.cmdCamSwitch:
        return await _executeCameraSwitch(payload);
        
      case MessageTypes.cmdZoomSet:
        return await _executeZoomSet(payload);
        
      case MessageTypes.cmdTorchSet:
        return await _executeTorchSet(payload);
        
      case MessageTypes.cmdFocusSet:
        return await _executeFocusSet(payload);
        
      case MessageTypes.cmdCleanFiles:
        return await _executeCleanFiles(payload);
        
      case MessageTypes.cmdAppRestart:
        return await _executeAppRestart();
        
      case MessageTypes.cmdLogQuery:
        return await _executeLogQuery(payload);
        
      default:
        throw UnsupportedError('Unsupported command type: $commandType');
    }
  }

  Future<Map<String, dynamic>> _executeRecordStart(Map<String, dynamic>? payload) async {
    final int duration = payload?['durationSec'] as int? ?? 60;
    
    _log('Starting recording for ${duration}s');
    
    // 模拟录像过程
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(Duration(milliseconds: duration * 10));
      _updateProgress(_activeCommands.values.last, i / 100.0);
    }
    
    final String fileName = 'record_${DateTime.now().millisecondsSinceEpoch}.mp4';
    
    return <String, dynamic>{
      'action': 'record_start',
      'fileName': fileName,
      'duration': duration,
      'fileSize': '${(duration * 1024 * 1024 / 8).toStringAsFixed(1)}MB', // 模拟文件大小
      'resolution': '1920x1080',
      'fps': 30,
      'completedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeRecordStop() async {
    _log('Stopping recording');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    return <String, dynamic>{
      'action': 'record_stop',
      'stoppedAt': DateTime.now().toIso8601String(),
      'fileSaved': true,
    };
  }

  Future<Map<String, dynamic>> _executeTakePhoto(Map<String, dynamic>? payload) async {
    final String quality = payload?['quality'] as String? ?? 'high';
    
    _log('Taking photo with quality: $quality');
    
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final String fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    return <String, dynamic>{
      'action': 'take_photo',
      'fileName': fileName,
      'fileSize': quality == 'high' ? '3.2MB' : '1.8MB',
      'resolution': quality == 'high' ? '4032x3024' : '1920x1080',
      'flashUsed': payload?['flash'] as bool? ?? false,
      'takenAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeFileUpload(Map<String, dynamic>? payload) async {
    final String path = payload?['path'] as String? ?? '/sdcard/DCIM';
    
    _log('Uploading files from: $path');
    
    // 模拟文件扫描
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final List<String> files = <String>[
      'video_001.mp4', 'video_002.mp4', 'photo_001.jpg'
    ];
    
    // 模拟上传过程
    for (int i = 0; i < files.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      _updateProgress(_activeCommands.values.last, (i + 1) / files.length);
    }
    
    return <String, dynamic>{
      'action': 'file_upload',
      'path': path,
      'filesCount': files.length,
      'totalSize': '125.6MB',
      'uploadedFiles': files,
      'completedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeRtcStart(Map<String, dynamic>? payload) async {
    final String serverUrl = payload?['serverUrl'] as String? ?? 'wss://rtc.example.com';
    
    _log('Starting RTC stream to: $serverUrl');
    
    // 模拟WebRTC连接过程
    await Future.delayed(const Duration(milliseconds: 2000));
    
    return <String, dynamic>{
      'action': 'rtc_start',
      'serverUrl': serverUrl,
      'streamId': 'stream_${DateTime.now().millisecondsSinceEpoch}',
      'resolution': '1280x720',
      'bitrate': '2000kbps',
      'startedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeRtcStop() async {
    _log('Stopping RTC stream');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    return <String, dynamic>{
      'action': 'rtc_stop',
      'stoppedAt': DateTime.now().toIso8601String(),
      'duration': '00:05:23',
    };
  }

  Future<Map<String, dynamic>> _executeCameraSwitch(Map<String, dynamic>? payload) async {
    final String camera = payload?['camera'] as String? ?? 'front';
    
    _log('Switching to camera: $camera');
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    return <String, dynamic>{
      'action': 'camera_switch',
      'currentCamera': camera,
      'availableCameras': ['front', 'back', 'wide', 'tele'],
      'switchedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeZoomSet(Map<String, dynamic>? payload) async {
    final double zoom = payload?['level'] as double? ?? 1.0;
    
    _log('Setting zoom level: ${zoom}x');
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    return <String, dynamic>{
      'action': 'zoom_set',
      'zoomLevel': zoom,
      'maxZoom': 10.0,
      'minZoom': 1.0,
      'setAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeTorchSet(Map<String, dynamic>? payload) async {
    final bool enabled = payload?['enabled'] as bool? ?? true;
    
    _log('Setting torch: ${enabled ? 'ON' : 'OFF'}');
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    return <String, dynamic>{
      'action': 'torch_set',
      'enabled': enabled,
      'setAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeFocusSet(Map<String, dynamic>? payload) async {
    final String mode = payload?['mode'] as String? ?? 'auto';
    
    _log('Setting focus mode: $mode');
    
    await Future.delayed(const Duration(milliseconds: 400));
    
    return <String, dynamic>{
      'action': 'focus_set',
      'focusMode': mode,
      'currentFocus': 0.8,
      'setAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeCleanFiles(Map<String, dynamic>? payload) async {
    final String path = payload?['path'] as String? ?? '/sdcard/DCIM';
    final int olderThanDays = payload?['olderThanDays'] as int? ?? 7;
    
    _log('Cleaning files in: $path (older than ${olderThanDays} days)');
    
    await Future.delayed(const Duration(milliseconds: 2000));
    
    return <String, dynamic>{
      'action': 'clean_files',
      'path': path,
      'olderThanDays': olderThanDays,
      'filesDeleted': 23,
      'spaceFreed': '1.2GB',
      'completedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeAppRestart() async {
    _log('Restarting application');
    
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // 在实际应用中，这里会触发应用重启
    return <String, dynamic>{
      'action': 'app_restart',
      'restartScheduled': true,
      'restartDelay': 3, // seconds
      'scheduledAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeLogQuery(Map<String, dynamic>? payload) async {
    final String level = payload?['level'] as String? ?? 'all';
    final int limit = payload?['limit'] as int? ?? 100;
    
    _log('Querying logs: level=$level, limit=$limit');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 模拟日志数据
    final List<Map<String, dynamic>> logs = <Map<String, dynamic>>[];
    for (int i = 0; i < limit.clamp(0, 50); i++) {
      logs.add(<String, dynamic>{
        'timestamp': DateTime.now().subtract(Duration(minutes: i * 5)).toIso8601String(),
        'level': ['INFO', 'WARN', 'ERROR'][i % 3],
        'message': 'Sample log message $i',
      });
    }
    
    return <String, dynamic>{
      'action': 'log_query',
      'level': level,
      'limit': limit,
      'logs': logs,
      'totalLogs': logs.length,
      'queriedAt': DateTime.now().toIso8601String(),
    };
  }

  void _updateExecution(CommandExecution execution) {
    _activeCommands[execution.id] = execution;
    _commandEventsController.add(execution);
    
    // 更新历史记录
    final int index = _commandHistory.indexWhere((e) => e.id == execution.id);
    if (index >= 0) {
      _commandHistory[index] = execution;
    }
    
    // 如果完成或失败，从活跃命令中移除
    if (execution.status == CommandStatus.completed || 
        execution.status == CommandStatus.failed ||
        execution.status == CommandStatus.timeout) {
      Future.delayed(const Duration(seconds: 5), () {
        _activeCommands.remove(execution.id);
      });
    }
  }

  void _updateProgress(CommandExecution execution, double progress) {
    final CommandExecution updatedExecution = execution.copyWith(progress: progress);
    _updateExecution(updatedExecution);
  }

  void _addToHistory(CommandExecution execution) {
    _commandHistory.insert(0, execution);
    
    // 保持历史记录在合理范围内
    if (_commandHistory.length > 200) {
      _commandHistory.removeRange(200, _commandHistory.length);
    }
  }

  CommandType _getCommandType(String messageType) {
    if (<String>[MessageTypes.cmdRecordStart, MessageTypes.cmdRecordStop].contains(messageType)) {
      return CommandType.recording;
    }
    if (<String>[MessageTypes.cmdTakePhoto].contains(messageType)) {
      return CommandType.photo;
    }
    if (<String>[MessageTypes.cmdFileUpload].contains(messageType)) {
      return CommandType.upload;
    }
    if (<String>[MessageTypes.cmdRtcStart, MessageTypes.cmdRtcStop].contains(messageType)) {
      return CommandType.rtc;
    }
    if (<String>[MessageTypes.cmdCamSwitch, MessageTypes.cmdZoomSet, 
              MessageTypes.cmdTorchSet, MessageTypes.cmdFocusSet].contains(messageType)) {
      return CommandType.hardware;
    }
    if (<String>[MessageTypes.cmdCleanFiles, MessageTypes.cmdAppRestart, 
              MessageTypes.cmdLogQuery].contains(messageType)) {
      return CommandType.maintenance;
    }
    return CommandType.unknown;
  }

  // 新增：获取命令统计
  Map<String, dynamic> getCommandStats() {
    final Map<CommandStatus, int> statusCounts = <CommandStatus, int>{};
    final Map<CommandType, int> typeCounts = <CommandType, int>{};
    
    for (final CommandExecution execution in _commandHistory) {
      statusCounts[execution.status] = (statusCounts[execution.status] ?? 0) + 1;
      typeCounts[execution.type] = (typeCounts[execution.type] ?? 0) + 1;
    }
    
    final List<CommandExecution> recentCommands = _commandHistory
        .where((e) => DateTime.now().difference(e.createdAt).inHours < 24)
        .toList();
    
    final int successCount = recentCommands
        .where((e) => e.status == CommandStatus.completed)
        .length;
    
    return <String, dynamic>{
      'totalCommands': _commandHistory.length,
      'activeCommands': _activeCommands.length,
      'statusCounts': statusCounts.map((k, v) => MapEntry(k.name, v)),
      'typeCounts': typeCounts.map((k, v) => MapEntry(k.name, v)),
      'successRate24h': recentCommands.isEmpty ? 0.0 : successCount / recentCommands.length,
      'lastCommand': _commandHistory.isNotEmpty 
          ? _commandHistory.first.createdAt.toIso8601String() 
          : null,
    };
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[CommandExecutionService] $message');
    }
  }

  void dispose() {
    _timeoutTimer?.cancel();
    _commandEventsController.close();
  }
}

// 辅助函数
void unawaited(Future<void> future) {
  // 故意不等待future完成
}
