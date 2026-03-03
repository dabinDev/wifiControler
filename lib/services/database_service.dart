import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/control_message.dart';
import '../services/config_service.dart';
import '../services/log_service.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;

  Database? _database;
  final StreamController<String> _dbController = StreamController<String>.broadcast();
  
  Stream<String> get dbEvents => _dbController.stream;
  bool get isInitialized => _database != null;

  Future<void> initialize() async {
    if (kIsWeb) {
      _log('Database service: Web platform detected, using memory storage');
      return;
    }

    try {
      final String databasesPath = await getDatabasesPath();
      final String dbPath = path.join(databasesPath, 'udp_control.db');
      
      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createTables,
        onUpgrade: _upgradeTables,
      );
      
      _log('Database initialized at: $dbPath');
      _dbController.add('database_initialized');
      
      // 清理旧数据
      await _cleanupOldData();
    } catch (error) {
      _log('Failed to initialize database: $error');
      rethrow;
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // 创建消息历史表
    await db.execute('''
      CREATE TABLE message_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        from_device TEXT NOT NULL,
        to_device TEXT,
        payload TEXT,
        timestamp_ms INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        direction TEXT NOT NULL, -- 'sent' or 'received'
        status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    // 创建设备历史表
    await db.execute('''
      CREATE TABLE device_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        device_role TEXT,
        device_slot TEXT,
        last_seen INTEGER,
        first_seen INTEGER NOT NULL,
        ip_address TEXT,
        status TEXT DEFAULT 'offline',
        created_at INTEGER NOT NULL,
        UNIQUE(device_id)
      )
    ''');

    // 创建命令执行历史表
    await db.execute('''
      CREATE TABLE command_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        command_id TEXT UNIQUE NOT NULL,
        command_type TEXT NOT NULL,
        target_device TEXT,
        status TEXT NOT NULL,
        progress REAL DEFAULT 0.0,
        result TEXT,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        sent_at INTEGER,
        received_at INTEGER,
        completed_at INTEGER,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // 创建网络统计表
    await db.execute('''
      CREATE TABLE network_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp_ms INTEGER NOT NULL,
        latency_ms INTEGER,
        packet_loss_rate REAL,
        throughput_bps INTEGER,
        bytes_sent INTEGER DEFAULT 0,
        bytes_received INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // 创建配置历史表
    await db.execute('''
      CREATE TABLE config_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        config_key TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        changed_at INTEGER NOT NULL,
        reason TEXT
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_message_timestamp ON message_history(timestamp_ms)');
    await db.execute('CREATE INDEX idx_device_last_seen ON device_history(last_seen)');
    await db.execute('CREATE INDEX idx_command_status ON command_history(status)');
    await db.execute('CREATE INDEX idx_network_timestamp ON network_stats(timestamp_ms)');
    
    _log('Database tables created successfully');
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    _log('Upgrading database from version $oldVersion to $newVersion');
    // 未来版本升级逻辑
  }

  // 消息历史操作
  Future<void> saveMessage(ControlMessage message, {String direction = 'received'}) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        'message_history',
        <String, dynamic>{
          'message_id': message.messageId,
          'type': message.type,
          'from_device': message.from,
          'to_device': message.to,
          'payload': jsonEncode(message.payload),
          'timestamp_ms': message.timestampMs,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'direction': direction,
          'status': 'completed',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      _dbController.add('message_saved');
    } catch (error) {
      _log('Failed to save message: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getMessageHistory({
    int? limit,
    String? direction,
    String? type,
    DateTime? since,
  }) async {
    if (_database == null) return [];

    try {
      String query = 'SELECT * FROM message_history WHERE 1=1';
      final List<dynamic> args = <dynamic>[];

      if (direction != null) {
        query += ' AND direction = ?';
        args.add(direction);
      }

      if (type != null) {
        query += ' AND type = ?';
        args.add(type);
      }

      if (since != null) {
        query += ' AND timestamp_ms >= ?';
        args.add(since.millisecondsSinceEpoch);
      }

      query += ' ORDER BY timestamp_ms DESC';
      
      if (limit != null) {
        query += ' LIMIT ?';
        args.add(limit);
      }

      return await _database!.rawQuery(query, args);
    } catch (error) {
      _log('Failed to get message history: $error');
      return [];
    }
  }

  // 设备历史操作
  Future<void> updateDeviceStatus({
    required String deviceId,
    String? role,
    String? slot,
    String? ipAddress,
    String status = 'online',
  }) async {
    if (_database == null) return;

    try {
      final int now = DateTime.now().millisecondsSinceEpoch;
      
      await _database!.insert(
        'device_history',
        <String, dynamic>{
          'device_id': deviceId,
          'device_role': role,
          'device_slot': slot,
          'ip_address': ipAddress,
          'last_seen': now,
          'status': status,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      _dbController.add('device_updated');
    } catch (error) {
      _log('Failed to update device status: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getDeviceHistory({String? status}) async {
    if (_database == null) return [];

    try {
      String query = 'SELECT * FROM device_history';
      final List<dynamic> args = <dynamic>[];

      if (status != null) {
        query += ' WHERE status = ?';
        args.add(status);
      }

      query += ' ORDER BY last_seen DESC';
      return await _database!.rawQuery(query, args);
    } catch (error) {
      _log('Failed to get device history: $error');
      return [];
    }
  }

  // 命令历史操作
  Future<void> saveCommandExecution(Map<String, dynamic> commandData) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        'command_history',
        <String, dynamic>{
          'command_id': commandData['id'],
          'command_type': commandData['type'],
          'target_device': commandData['targetDevice'],
          'status': commandData['status'],
          'progress': commandData['progress'] ?? 0.0,
          'result': jsonEncode(commandData['result']),
          'error_message': commandData['error'],
          'created_at': commandData['createdAt'],
          'sent_at': commandData['sentAt'],
          'received_at': commandData['receivedAt'],
          'completed_at': commandData['completedAt'],
          'retry_count': commandData['retryCount'] ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      _dbController.add('command_saved');
    } catch (error) {
      _log('Failed to save command execution: $error');
    }
  }

  // 网络统计操作
  Future<void> saveNetworkStats(Map<String, dynamic> stats) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        'network_stats',
        <String, dynamic>{
          'timestamp_ms': stats['timestampMs'],
          'latency_ms': stats['latency'],
          'packet_loss_rate': stats['packetLossRate'],
          'throughput_bps': stats['throughput'],
          'bytes_sent': stats['bytesSent'],
          'bytes_received': stats['bytesReceived'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
      );
      
      _dbController.add('network_stats_saved');
    } catch (error) {
      _log('Failed to save network stats: $error');
    }
  }

  // 数据清理
  Future<void> _cleanupOldData() async {
    if (_database == null) return;

    try {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int weekAgo = now - (7 * 24 * 60 * 60 * 1000); // 7天前
      final int monthAgo = now - (30 * 24 * 60 * 60 * 1000); // 30天前

      // 清理7天前的消息历史
      final int messagesDeleted = await _database!.delete(
        'message_history',
        where: 'created_at < ?',
        whereArgs: <dynamic>[weekAgo],
      );

      // 清理30天前的网络统计
      final int statsDeleted = await _database!.delete(
        'network_stats',
        where: 'created_at < ?',
        whereArgs: <dynamic>[monthAgo],
      );

      // 清理已完成的命令历史（保留7天）
      final int commandsDeleted = await _database!.delete(
        'command_history',
        where: 'created_at < ? AND status IN (?, ?)',
        whereArgs: <dynamic>[weekAgo, 'completed', 'failed'],
      );

      _log('Cleanup completed: messages=$messagesDeleted, stats=$statsDeleted, commands=$commandsDeleted');
    } catch (error) {
      _log('Failed to cleanup old data: $error');
    }
  }

  // 新增：获取数据库统计
  Future<Map<String, dynamic>> getDatabaseStats() async {
    if (_database == null) return <String, dynamic>{};

    try {
      final int messageCount = Sqflite.firstIntValue(
        await _database!.rawQuery('SELECT COUNT(*) FROM message_history')
      ) ?? 0;
      
      final int deviceCount = Sqflite.firstIntValue(
        await _database!.rawQuery('SELECT COUNT(*) FROM device_history')
      ) ?? 0;
      
      final int commandCount = Sqflite.firstIntValue(
        await _database!.rawQuery('SELECT COUNT(*) FROM command_history')
      ) ?? 0;
      
      final int statsCount = Sqflite.firstIntValue(
        await _database!.rawQuery('SELECT COUNT(*) FROM network_stats')
      ) ?? 0;

      // 获取数据库文件大小
      final String databasesPath = await getDatabasesPath();
      final String dbPath = path.join(databasesPath, 'udp_control.db');
      final File dbFile = File(dbPath);
      final int fileSize = await dbFile.length();

      return <String, dynamic>{
        'messageCount': messageCount,
        'deviceCount': deviceCount,
        'commandCount': commandCount,
        'statsCount': statsCount,
        'fileSize': '${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB',
        'filePath': dbPath,
      };
    } catch (error) {
      _log('Failed to get database stats: $error');
      return <String, dynamic>{};
    }
  }

  // 新增：导出数据
  Future<Map<String, dynamic>> exportAllData() async {
    if (_database == null) return <String, dynamic>{};

    try {
      return <String, dynamic>{
        'messages': await getMessageHistory(limit: 1000),
        'devices': await getDeviceHistory(),
        'commands': await _database!.query('command_history', orderBy: 'created_at DESC', limit: 500),
        'networkStats': await _database!.query('network_stats', orderBy: 'timestamp_ms DESC', limit: 1000),
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      _log('Failed to export data: $error');
      return <String, dynamic>{};
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[DatabaseService] $message');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _log('Database closed');
    }
  }

  void dispose() {
    close();
    _dbController.close();
  }
}

// 全局数据库实例
final DatabaseService databaseService = DatabaseService();
