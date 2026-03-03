import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/config_service.dart';
import '../services/log_service.dart';
import '../services/permission_service.dart';
import '../services/database_service.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/authentication_service.dart';

/// 服务状态枚举
enum ServiceState {
  uninitialized,
  initializing,
  initialized,
  error,
}

/// 服务基类
abstract class BaseService {
  ServiceState _state = ServiceState.uninitialized;
  String? _lastError;
  
  ServiceState get state => _state;
  String? get lastError => _lastError;
  bool get isInitialized => _state == ServiceState.initialized;
  
  Future<void> initialize() async {
    try {
      _setState(ServiceState.initializing);
      await onInitialize();
      _setState(ServiceState.initialized);
    } catch (error) {
      _setError(error.toString());
      rethrow;
    }
  }
  
  Future<void> dispose() async {
    try {
      await onDispose();
      _setState(ServiceState.uninitialized);
    } catch (error) {
      _setError(error.toString());
      rethrow;
    }
  }
  
  /// 子类实现具体的初始化逻辑
  Future<void> onInitialize();
  
  /// 子类实现具体的清理逻辑
  Future<void> onDispose();
  
  void _setState(ServiceState state) {
    _state = state;
    onStateChanged?.call(state);
  }
  
  void _setError(String error) {
    _lastError = error;
    onError?.call(error);
  }
  
  /// 状态变化回调
  void Function(ServiceState)? onStateChanged;
  
  /// 错误回调
  void Function(String)? onError;
}

/// 扩展的服务基类，支持配置和日志
abstract class ExtendedService extends BaseService {
  ConfigService? _configService;
  LogService? _logService;
  
  ConfigService get configService {
    if (_configService == null) {
      throw StateError('ConfigService not initialized');
    }
    return _configService!;
  }
  
  LogService get logService {
    if (_logService == null) {
      throw StateError('LogService not initialized');
    }
    return _logService!;
  }
  
  /// 设置依赖服务
  void setDependencies({
    ConfigService? configService,
    LogService? logService,
  }) {
    _configService = configService;
    _logService = logService;
  }
  
  /// 记录日志的便捷方法
  void logInfo(String message, {String? tag}) {
    if (_logService != null) {
      _logService!.info(message, tag: tag ?? runtimeType.toString());
    }
  }
  
  void logWarning(String message, {String? tag}) {
    if (_logService != null) {
      _logService!.warning(message, tag: tag ?? runtimeType.toString());
    }
  }
  
  void logError(String message, {Object? error, String? tag}) {
    if (_logService != null) {
      _logService!.error(message, error: error, tag: tag ?? runtimeType.toString());
    }
  }
}

/// 服务管理器
class ServiceManager {
  ServiceManager._();
  static final ServiceManager _instance = ServiceManager._();
  factory ServiceManager() => _instance;
  
  final Map<Type, BaseService> _services = <Type, BaseService>{};
  final StreamController<ServiceEvent> _eventController = 
      StreamController<ServiceEvent>.broadcast();
  
  Stream<ServiceEvent> get events => _eventController.stream;
  
  /// 注册服务
  void registerService<T extends BaseService>(T service) {
    _services[T] = service;
    
    // 监听服务状态变化
    service.onStateChanged = (ServiceState state) {
      _eventController.add(ServiceEvent(
        type: T.toString(),
        state: state,
        timestamp: DateTime.now(),
      ));
    };
    
    service.onError = (String error) {
      _eventController.add(ServiceEvent(
        type: T.toString(),
        state: ServiceState.error,
        timestamp: DateTime.now(),
        error: error,
      ));
    };
  }
  
  /// 获取服务
  T getService<T extends BaseService>() {
    final BaseService? service = _services[T];
    if (service == null) {
      throw StateError('Service ${T.toString()} not registered');
    }
    return service as T;
  }
  
  /// 检查服务是否存在
  bool hasService<T extends BaseService>() {
    return _services.containsKey(T);
  }
  
  /// 初始化所有服务
  Future<void> initializeAll() async {
    try {
      logInfo('Initializing all services...');
      
      // 按依赖顺序初始化核心服务
      final List<Type> initOrder = <Type>[
        ConfigService,
        LogService,
        PermissionService,
        DatabaseService,
        AuthenticationService,
        CameraService,
        AudioService,
      ];
      
      for (final Type serviceType in initOrder) {
        if (_services.containsKey(serviceType)) {
          final BaseService service = _services[serviceType]!;
          if (!service.isInitialized) {
            await service.initialize();
            logInfo('Service ${serviceType.toString()} initialized');
          }
        }
      }
      
      // 设置服务间依赖
      _setupDependencies();
      
      logInfo('All services initialized successfully');
    } catch (error) {
      logError('Failed to initialize services', error: error);
      rethrow;
    }
  }
  
  /// 设置服务间依赖
  void _setupDependencies() {
    // 为扩展服务设置依赖
    _services.forEach((Type type, BaseService service) {
      if (service is ExtendedService) {
        service.setDependencies(
          configService: _services[ConfigService] as ConfigService?,
          logService: _services[LogService] as LogService?,
        );
      }
    });
  }
  
  /// 清理所有服务
  Future<void> disposeAll() async {
    try {
      logInfo('Disposing all services...');
      
      // 按相反顺序清理服务
      final List<BaseService> services = _services.values.toList().reversed.toList();
      
      for (final BaseService service in services) {
        if (service.isInitialized) {
          await service.dispose();
        }
      }
      
      _services.clear();
      logInfo('All services disposed');
    } catch (error) {
      logError('Failed to dispose services', error: error);
    }
  }
  
  /// 获取所有服务状态
  Map<String, ServiceState> getAllServiceStates() {
    return _services.map<String, ServiceState>(
      (Type type, BaseService service) => MapEntry(type.toString(), service.state),
    );
  }
  
  /// 获取初始化统计
  ServiceStats getStats() {
    int initializedCount = 0;
    int errorCount = 0;
    
    _services.forEach((Type type, BaseService service) {
      if (service.state == ServiceState.initialized) {
        initializedCount++;
      } else if (service.state == ServiceState.error) {
        errorCount++;
      }
    });
    
    return ServiceStats(
      totalServices: _services.length,
      initializedServices: initializedCount,
      errorServices: errorCount,
      lastUpdate: DateTime.now(),
    );
  }
  
  void logInfo(String message) {
    if (kDebugMode) {
      print('[ServiceManager] $message');
    }
  }
  
  void logError(String message, {Object? error}) {
    if (kDebugMode) {
      print('[ServiceManager] ERROR: $message');
      if (error != null) {
        print('[ServiceManager] Error details: $error');
      }
    }
  }
  
  void dispose() {
    _eventController.close();
  }
}

/// 服务事件
class ServiceEvent {
  const ServiceEvent({
    required this.type,
    required this.state,
    required this.timestamp,
    this.error,
  });
  
  final String type;
  final ServiceState state;
  final DateTime timestamp;
  final String? error;
  
  @override
  String toString() {
    return 'ServiceEvent(type: $type, state: $state, timestamp: $timestamp, error: $error)';
  }
}

/// 服务统计
class ServiceStats {
  const ServiceStats({
    required this.totalServices,
    required this.initializedServices,
    required this.errorServices,
    required this.lastUpdate,
  });
  
  final int totalServices;
  final int initializedServices;
  final int errorServices;
  final DateTime lastUpdate;
  
  double get initializationProgress {
    if (totalServices == 0) return 1.0;
    return initializedServices / totalServices;
  }
  
  bool get isAllInitialized => initializedServices == totalServices;
  
  @override
  String toString() {
    return 'ServiceStats(total: $totalServices, initialized: $initializedServices, errors: $errorServices, progress: ${(initializationProgress * 100).toStringAsFixed(1)}%)';
  }
}

/// 服务初始化异常
class ServiceInitializationException implements Exception {
  const ServiceInitializationException(this.message, {this.serviceType});
  
  final String message;
  final String? serviceType;
  
  @override
  String toString() {
    if (serviceType != null) {
      return 'ServiceInitializationException($serviceType): $message';
    }
    return 'ServiceInitializationException: $message';
  }
}

/// 全局服务管理器实例
final ServiceManager serviceManager = ServiceManager();
