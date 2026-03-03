import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp.millisecondsSinceEpoch,
        'level': level.name,
        'message': message,
        'tag': tag,
        'error': error?.toString(),
        'stackTrace': stackTrace?.toString(),
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        level: LogLevel.values.firstWhere(
          (LogLevel e) => e.name == json['level'] as String,
          orElse: () => LogLevel.info,
        ),
        message: json['message'] as String,
        tag: json['tag'] as String?,
        error: json['error'],
        stackTrace: json['stackTrace'] != null ? StackTrace.fromString(json['stackTrace'] as String) : null,
      );

  @override
  String toString() {
    final String timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final String levelStr = level.name.toUpperCase().padRight(7);
    final String tagStr = tag != null ? '[$tag] ' : '';
    return '[$timeStr] $levelStr $tagStr$message';
  }
}

class LogService {
  LogService._();
  static final LogService _instance = LogService._();
  factory LogService() => _instance;

  final List<LogEntry> _logs = <LogEntry>[];
  final StreamController<List<LogEntry>> _logController = StreamController<List<LogEntry>>.broadcast();
  final StreamController<LogEntry> _newLogController = StreamController<LogEntry>.broadcast();
  
  Timer? _cleanupTimer;
  Timer? _saveTimer;
  File? _logFile;
  
  int _maxLogEntries = 1000;
  int _retentionDays = 7;
  bool _enableFileLogging = true;

  Stream<List<LogEntry>> get logsStream => _logController.stream;
  Stream<LogEntry> get newLogStream => _newLogController.stream;
  List<LogEntry> get logs => List<LogEntry>.unmodifiable(_logs);

  Future<void> initialize({
    int maxLogEntries = 1000,
    int retentionDays = 7,
    bool enableFileLogging = true,
  }) async {
    _maxLogEntries = maxLogEntries;
    _retentionDays = retentionDays;
    _enableFileLogging = enableFileLogging;

    try {
      if (_enableFileLogging) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        _logFile = File('${appDocDir.path}/app_logs.jsonl');
        await _loadLogsFromFile();
      }
      
      // 启动清理定时器（每小时清理一次过期日志）
      _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) => _cleanupOldLogs());
      
      // 启动保存定时器（每分钟保存一次）
      if (_enableFileLogging) {
        _saveTimer = Timer.periodic(const Duration(minutes: 1), (_) => _saveLogsToFile());
      }
      
      _logController.add(_logs);
      _log('Log service initialized', tag: 'LogService');
    } catch (error) {
      _log('Failed to initialize log service: $error', level: LogLevel.error, tag: 'LogService');
    }
  }

  void log(String message, {
    LogLevel level = LogLevel.info,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final LogEntry entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.insert(0, entry);
    
    // 保持日志数量在限制内
    if (_logs.length > _maxLogEntries) {
      _logs.removeRange(_maxLogEntries, _logs.length);
    }

    // 输出到控制台
    if (kDebugMode) {
      if (level == LogLevel.error && error != null) {
        debugPrint('$entry\nError: $error\nStackTrace: $stackTrace');
      } else {
        debugPrint(entry.toString());
      }
    }

    // 通知监听器
    _newLogController.add(entry);
    _logController.add(_logs);
  }

  void debug(String message, {String? tag}) => log(message, level: LogLevel.debug, tag: tag);
  void info(String message, {String? tag}) => log(message, level: LogLevel.info, tag: tag);
  void warning(String message, {String? tag}) => log(message, level: LogLevel.warning, tag: tag);
  void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) => 
      log(message, level: LogLevel.error, error: error, stackTrace: stackTrace, tag: tag);

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((LogEntry entry) => entry.level == level).toList();
  }

  List<LogEntry> getLogsByTag(String tag) {
    return _logs.where((LogEntry entry) => entry.tag == tag).toList();
  }

  List<LogEntry> getLogsSince(DateTime since) {
    return _logs.where((LogEntry entry) => entry.timestamp.isAfter(since)).toList();
  }

  List<LogEntry> searchLogs(String query) {
    final String lowerQuery = query.toLowerCase();
    return _logs.where((LogEntry entry) => 
      entry.message.toLowerCase().contains(lowerQuery) ||
      (entry.tag?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  Future<void> clearLogs() async {
    _logs.clear();
    _logController.add(_logs);
    
    if (_enableFileLogging && _logFile != null) {
      try {
        await _logFile!.writeAsString('');
        _log('Logs cleared', tag: 'LogService');
      } catch (error) {
        _log('Failed to clear log file: $error', level: LogLevel.error, tag: 'LogService');
      }
    }
  }

  Future<void> exportLogs(String filePath, {LogLevel? minLevel}) async {
    try {
      final File exportFile = File(filePath);
      final List<LogEntry> logsToExport = minLevel != null 
          ? _logs.where((LogEntry entry) => entry.level.index >= minLevel.index).toList()
          : _logs;
      
      final String content = logsToExport
          .map((LogEntry entry) => '${entry.toJson()}\n')
          .join('');
      
      await exportFile.writeAsString(content);
      _log('Logs exported to: $filePath (${logsToExport.length} entries)', tag: 'LogService');
    } catch (error) {
      _log('Failed to export logs: $error', level: LogLevel.error, tag: 'LogService');
      rethrow;
    }
  }

  Future<void> exportLogsAsText(String filePath, {LogLevel? minLevel}) async {
    try {
      final File exportFile = File(filePath);
      final List<LogEntry> logsToExport = minLevel != null 
          ? _logs.where((LogEntry entry) => entry.level.index >= minLevel.index).toList()
          : _logs;
      
      final String content = logsToExport
          .map((LogEntry entry) => entry.toString())
          .join('\n');
      
      await exportFile.writeAsString(content);
      _log('Logs exported as text to: $filePath (${logsToExport.length} entries)', tag: 'LogService');
    } catch (error) {
      _log('Failed to export logs as text: $error', level: LogLevel.error, tag: 'LogService');
      rethrow;
    }
  }

  // 新增：获取日志统计
  Map<String, dynamic> getLogStats() {
    final Map<LogLevel, int> levelCounts = <LogLevel, int>{};
    final Map<String, int> tagCounts = <String, int>{};
    
    for (final LogEntry entry in _logs) {
      levelCounts[entry.level] = (levelCounts[entry.level] ?? 0) + 1;
      if (entry.tag != null) {
        tagCounts[entry.tag!] = (tagCounts[entry.tag!] ?? 0) + 1;
      }
    }
    
    final DateTime? firstLog = _logs.isNotEmpty ? _logs.last.timestamp : null;
    final DateTime? lastLog = _logs.isNotEmpty ? _logs.first.timestamp : null;
    
    return <String, dynamic>{
      'totalLogs': _logs.length,
      'levelCounts': levelCounts.map((k, v) => MapEntry(k.name, v)),
      'topTags': (() {
          final List<MapEntry<String, int>> entries = tagCounts.entries.toList();
          entries.sort((a, b) => b.value.compareTo(a.value));
          return entries.take(10).map((e) => MapEntry(e.key, e.value)).toList();
        })(),
      'firstLogTime': firstLog?.toIso8601String(),
      'lastLogTime': lastLog?.toIso8601String(),
      'memoryUsage': '${_getMemoryUsage()}MB',
    };
  }

  // 新增：获取内存使用情况
  double _getMemoryUsage() {
    try {
      final int totalSize = _logs.fold<int>(0, (int sum, LogEntry entry) => 
          sum + entry.toString().length);
      return totalSize / (1024 * 1024); // 转换为MB
    } catch (error) {
      return 0.0;
    }
  }

  Future<void> _loadLogsFromFile() async {
    if (_logFile == null || !await _logFile!.exists()) return;
    
    try {
      final List<String> lines = await _logFile!.readAsLines();
      final List<LogEntry> loadedLogs = <LogEntry>[];
      
      for (final String line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          final Map<String, dynamic> json = jsonDecode(line) as Map<String, dynamic>;
          final LogEntry entry = LogEntry.fromJson(json);
          
          // 只加载保留期内的日志
          if (DateTime.now().difference(entry.timestamp).inDays <= _retentionDays) {
            loadedLogs.add(entry);
          }
        } catch (error) {
          // 忽略解析错误的行
        }
      }
      
      _logs.clear();
      _logs.addAll(loadedLogs.reversed); // 最新的在前面
      _log('Loaded ${_logs.length} logs from file', tag: 'LogService');
    } catch (error) {
      _log('Failed to load logs from file: $error', level: LogLevel.error, tag: 'LogService');
    }
  }

  Future<void> _saveLogsToFile() async {
    if (_logFile == null || _logs.isEmpty) return;
    
    try {
      final String content = _logs
          .map((LogEntry entry) => jsonEncode(entry.toJson()))
          .join('\n');
      
      await _logFile!.writeAsString(content);
    } catch (error) {
      _log('Failed to save logs to file: $error', level: LogLevel.error, tag: 'LogService');
    }
  }

  void _cleanupOldLogs() {
    final DateTime cutoff = DateTime.now().subtract(Duration(days: _retentionDays));
    final int initialCount = _logs.length;
    
    _logs.removeWhere((LogEntry entry) => entry.timestamp.isBefore(cutoff));
    
    if (_logs.length != initialCount) {
      _logController.add(_logs);
      _log('Cleaned up ${initialCount - _logs.length} old logs', tag: 'LogService');
    }
  }

  void _log(String message, {LogLevel level = LogLevel.info, String? tag}) {
    // 避免递归调用
    if (tag != 'LogService') {
      final LogEntry entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        tag: 'LogService',
      );
      
      if (kDebugMode) {
        debugPrint(entry.toString());
      }
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _saveTimer?.cancel();
    _logController.close();
    _newLogController.close();
  }
}

// 全局日志实例
final LogService logger = LogService();
