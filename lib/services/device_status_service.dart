import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceStatus {
  const DeviceStatus({
    required this.batteryLevel,
    required this.isCharging,
    required this.storageFree,
    required this.storageTotal,
    required this.cpuTemp,
    required this.batteryTemp,
    required this.wifiSignalStrength,
    required this.uploadSpeed,
    required this.currentCamera,
    required this.zoomLevel,
    required this.memoryUsage,
    required this.networkType,
    required this.timestamp,
  });

  final double batteryLevel; // 0-100
  final bool isCharging;
  final double storageFree; // GB
  final double storageTotal; // GB
  final double cpuTemp; // Celsius
  final double batteryTemp; // Celsius
  final int wifiSignalStrength; // dBm
  final int uploadSpeed; // KB/s
  final String currentCamera; // 'front', 'back', 'external'
  final double zoomLevel; // 1.0-10.0
  final double memoryUsage; // 0-100%
  final String networkType; // 'wifi', 'mobile', 'none'
  final DateTime timestamp;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'batteryLevel': batteryLevel,
    'isCharging': isCharging,
    'storageFree': storageFree,
    'storageTotal': storageTotal,
    'cpuTemp': cpuTemp,
    'batteryTemp': batteryTemp,
    'wifiSignalStrength': wifiSignalStrength,
    'uploadSpeed': uploadSpeed,
    'currentCamera': currentCamera,
    'zoomLevel': zoomLevel,
    'memoryUsage': memoryUsage,
    'networkType': networkType,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  @override
  String toString() {
    return 'DeviceStatus(battery: ${batteryLevel.toStringAsFixed(1)}%, '
           'storage: ${storageFree.toStringAsFixed(1)}GB, '
           'cpu: ${cpuTemp.toStringAsFixed(1)}°C, '
           'wifi: ${wifiSignalStrength}dBm)';
  }
}

class DeviceStatusService {
  DeviceStatusService({
    this.updateInterval = const Duration(seconds: 5),
    bool? enableRealMonitoring,
  }) : enableRealMonitoring = enableRealMonitoring ?? (Platform.isAndroid || Platform.isIOS);

  final Duration updateInterval;
  final bool enableRealMonitoring;
  
  Timer? _updateTimer;
  DeviceStatus? _lastStatus;
  final StreamController<DeviceStatus> _statusController = 
      StreamController<DeviceStatus>.broadcast();
  
  // 模拟数据的基础值
  double _baseBattery = 75.0;
  double _baseStorage = 45.0;
  double _baseCpuTemp = 38.0;
  double _baseBatteryTemp = 35.0;
  int _baseWifiSignal = -45;
  int _baseUploadSpeed = 800;
  
  // 异常检测阈值
  static const double _lowBatteryThreshold = 20.0;
  static const double _highTempThreshold = 60.0;
  static const double _lowStorageThreshold = 5.0;
  static const int _weakWifiThreshold = -70;

  Stream<DeviceStatus> get statusStream => _statusController.stream;
  DeviceStatus? get lastStatus => _lastStatus;

  Future<void> startMonitoring() async {
    if (_updateTimer != null) return;
    
    // 立即获取一次状态
    await _updateStatus();
    
    // 启动定时更新
    _updateTimer = Timer.periodic(updateInterval, (_) => _updateStatus());
    
    if (kDebugMode) {
      print('[DeviceStatusService] Started monitoring (real: $enableRealMonitoring)');
    }
  }

  void stopMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = null;
    
    if (kDebugMode) {
      print('[DeviceStatusService] Stopped monitoring');
    }
  }

  Future<DeviceStatus> getCurrentStatus() async {
    await _updateStatus();
    return _lastStatus!;
  }

  Future<void> _updateStatus() async {
    try {
      final DeviceStatus status = enableRealMonitoring 
          ? await _getRealDeviceStatus()
          : _getSimulatedDeviceStatus();
      
      _lastStatus = status;
      _statusController.add(status);
      
      // 检查异常状态
      _checkForAlerts(status);
      
    } catch (error) {
      if (kDebugMode) {
        print('[DeviceStatusService] Error updating status: $error');
      }
      
      // 发生错误时使用模拟数据
      final DeviceStatus fallbackStatus = _getSimulatedDeviceStatus();
      _lastStatus = fallbackStatus;
      _statusController.add(fallbackStatus);
    }
  }

  Future<DeviceStatus> _getRealDeviceStatus() async {
    // 在真实环境中，这里会调用平台特定的API
    // 目前返回增强的模拟数据，但结构为真实API做准备
    
    return DeviceStatus(
      batteryLevel: await _getRealBatteryLevel(),
      isCharging: await _getRealChargingStatus(),
      storageFree: await _getRealStorageInfo(),
      storageTotal: 128.0, // 假设总存储128GB
      cpuTemp: await _getRealCpuTemperature(),
      batteryTemp: await _getRealBatteryTemperature(),
      wifiSignalStrength: await _getRealWifiSignal(),
      uploadSpeed: await _getRealUploadSpeed(),
      currentCamera: 'back',
      zoomLevel: 1.0,
      memoryUsage: await _getRealMemoryUsage(),
      networkType: await _getRealNetworkType(),
      timestamp: DateTime.now(),
    );
  }

  DeviceStatus _getSimulatedDeviceStatus() {
    final Random random = Random();
    
    // 添加随机波动
    final double batteryVariation = (random.nextDouble() - 0.5) * 2.0;
    final double storageVariation = (random.nextDouble() - 0.5) * 1.0;
    final double cpuTempVariation = (random.nextDouble() - 0.5) * 3.0;
    final double batteryTempVariation = (random.nextDouble() - 0.5) * 2.0;
    final int wifiVariation = random.nextInt(11) - 5; // -5 to 5
    final int uploadVariation = random.nextInt(201) - 100; // -100 to 100
    
    // 缓慢变化基础值
    _baseBattery += (random.nextDouble() - 0.51) * 0.5; // 缓慢下降
    _baseStorage += (random.nextDouble() - 0.52) * 0.2; // 缓慢下降
    _baseCpuTemp += (random.nextDouble() - 0.5) * 0.5;
    _baseBatteryTemp += (random.nextDouble() - 0.5) * 0.3;
    
    // 限制范围
    _baseBattery = _baseBattery.clamp(10.0, 100.0);
    _baseStorage = _baseStorage.clamp(5.0, 120.0);
    _baseCpuTemp = _baseCpuTemp.clamp(25.0, 70.0);
    _baseBatteryTemp = _baseBatteryTemp.clamp(20.0, 50.0);
    
    return DeviceStatus(
      batteryLevel: (_baseBattery + batteryVariation).clamp(0.0, 100.0),
      isCharging: random.nextDouble() < 0.1, // 10%概率充电中
      storageFree: (_baseStorage + storageVariation).clamp(0.0, 128.0),
      storageTotal: 128.0,
      cpuTemp: (_baseCpuTemp + cpuTempVariation).clamp(20.0, 80.0),
      batteryTemp: (_baseBatteryTemp + batteryTempVariation).clamp(15.0, 60.0),
      wifiSignalStrength: _baseWifiSignal + wifiVariation,
      uploadSpeed: (_baseUploadSpeed + uploadVariation).clamp(100, 2000),
      currentCamera: random.nextBool() ? 'back' : 'front',
      zoomLevel: 1.0 + random.nextDouble() * 2.0,
      memoryUsage: 40.0 + random.nextDouble() * 40.0, // 40-80%
      networkType: _getRandomNetworkType(random),
      timestamp: DateTime.now(),
    );
  }

  // 平台方法占位符（实际实现需要插件）
  Future<double> _getRealBatteryLevel() async {
    try {
      // 实际实现需要 battery_plus 插件
      // return await Battery.batteryLevel;
      return _baseBattery + (Random().nextDouble() - 0.5) * 2.0;
    } catch (error) {
      return 75.0;
    }
  }

  Future<bool> _getRealChargingStatus() async {
    try {
      // 实际实现需要 battery_plus 插件
      // return await Battery.isInBatteryOptimization;
      return Random().nextDouble() < 0.1;
    } catch (error) {
      return false;
    }
  }

  Future<double> _getRealStorageInfo() async {
    try {
      // 实际实现需要 path_provider 插件
      // return await _getAvailableStorage();
      return _baseStorage + (Random().nextDouble() - 0.5) * 1.0;
    } catch (error) {
      return 45.0;
    }
  }

  Future<double> _getRealCpuTemperature() async {
    // Android需要读取系统文件，iOS需要私有API
    return _baseCpuTemp + (Random().nextDouble() - 0.5) * 3.0;
  }

  Future<double> _getRealBatteryTemperature() async {
    // Android需要读取电池温度
    return _baseBatteryTemp + (Random().nextDouble() - 0.5) * 2.0;
  }

  Future<int> _getRealWifiSignal() async {
    try {
      // 实际实现需要 connectivity_plus 插件
      // return await _getWifiRssi();
      return _baseWifiSignal + Random().nextInt(11) - 5;
    } catch (error) {
      return -45;
    }
  }

  Future<int> _getRealUploadSpeed() async {
    // 实际实现需要网络测速
    return _baseUploadSpeed + Random().nextInt(201) - 100;
  }

  Future<double> _getRealMemoryUsage() async {
    try {
      // 实际实现需要读取内存信息
      // return await _getMemoryPercentage();
      return 40.0 + Random().nextDouble() * 40.0;
    } catch (error) {
      return 60.0;
    }
  }

  Future<String> _getRealNetworkType() async {
    try {
      // 实际实现需要 connectivity_plus 插件
      // return await _getNetworkType();
      return _getRandomNetworkType(Random());
    } catch (error) {
      return 'wifi';
    }
  }

  String _getRandomNetworkType(Random random) {
    final double rand = random.nextDouble();
    if (rand < 0.7) return 'wifi';
    if (rand < 0.95) return 'mobile';
    return 'none';
  }

  void _checkForAlerts(DeviceStatus status) {
    final List<String> alerts = <String>[];
    
    if (status.batteryLevel < _lowBatteryThreshold) {
      alerts.add('低电量警告: ${status.batteryLevel.toStringAsFixed(1)}%');
    }
    
    if (status.cpuTemp > _highTempThreshold) {
      alerts.add('CPU温度过高: ${status.cpuTemp.toStringAsFixed(1)}°C');
    }
    
    if (status.batteryTemp > _highTempThreshold) {
      alerts.add('电池温度过高: ${status.batteryTemp.toStringAsFixed(1)}°C');
    }
    
    if (status.storageFree < _lowStorageThreshold) {
      alerts.add('存储空间不足: ${status.storageFree.toStringAsFixed(1)}GB');
    }
    
    if (status.wifiSignalStrength < _weakWifiThreshold) {
      alerts.add('WiFi信号弱: ${status.wifiSignalStrength}dBm');
    }
    
    if (alerts.isNotEmpty) {
      _onAlertsDetected(alerts);
    }
  }

  void _onAlertsDetected(List<String> alerts) {
    if (kDebugMode) {
      print('[DeviceStatusService] Alerts: ${alerts.join(', ')}');
    }
    
    // 这里可以发送通知或触发其他处理
    // 例如：_notificationService.showAlert(alerts);
  }

  // 新增：获取设备健康分数
  double getHealthScore(DeviceStatus? status) {
    status ??= _lastStatus;
    if (status == null) return 0.0;
    
    double score = 100.0;
    
    // 电池影响 (30%)
    if (status.batteryLevel < _lowBatteryThreshold) {
      score -= 30;
    } else {
      score -= (100 - status.batteryLevel) * 0.3;
    }
    
    // 温度影响 (25%)
    if (status.cpuTemp > _highTempThreshold) {
      score -= 25;
    } else {
      score -= (status.cpuTemp - 25.0) * 0.5;
    }
    
    // 存储影响 (20%)
    if (status.storageFree < _lowStorageThreshold) {
      score -= 20;
    } else {
      score -= (100 - (status.storageFree / status.storageTotal * 100)) * 0.2;
    }
    
    // 网络影响 (15%)
    if (status.networkType == 'none') {
      score -= 15;
    } else if (status.wifiSignalStrength < _weakWifiThreshold) {
      score -= 10;
    }
    
    // 内存影响 (10%)
    if (status.memoryUsage > 90) {
      score -= 10;
    } else {
      score -= (status.memoryUsage - 50) * 0.2;
    }
    
    return score.clamp(0.0, 100.0);
  }

  // 新增：获取状态摘要
  Map<String, dynamic> getStatusSummary() {
    final DeviceStatus? status = _lastStatus;
    if (status == null) return <String, dynamic>{};
    
    return <String, dynamic>{
      'batteryLevel': status.batteryLevel,
      'isCharging': status.isCharging,
      'storageUsage': ((status.storageTotal - status.storageFree) / status.storageTotal * 100).toStringAsFixed(1),
      'temperature': status.cpuTemp,
      'networkSignal': status.wifiSignalStrength,
      'networkType': status.networkType,
      'healthScore': getHealthScore(status),
      'lastUpdate': status.timestamp.toIso8601String(),
    };
  }

  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}
