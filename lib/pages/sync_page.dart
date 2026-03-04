import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/control_message.dart';
import '../protocol/message_types.dart';
import '../services/udp_service_enhanced.dart' as enhanced_udp;
import 'image_preview_page.dart';
import 'video_preview_page.dart';
import 'audio_preview_page.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({
    super.key,
    required this.udpService,
    required this.getDevices,
    required this.getDeviceIps,
    required this.controllerId,
    required this.targetPort,
  });

  final enhanced_udp.UdpService udpService;
  final List<String> Function() getDevices;
  final Map<String, String> Function() getDeviceIps;
  final String controllerId;
  final int targetPort;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  StreamSubscription<enhanced_udp.UdpDatagramEvent>? _eventSub;
  String? _selectedDevice;
  bool _syncing = false;
  bool _syncSuccess = false;
  String _syncStatus = '待同步';
  int _totalFiles = 0;
  int _currentFileIndex = 0;
  int _currentFileProgress = 0;

  final List<Map<String, dynamic>> _remoteFiles = <Map<String, dynamic>>[];
  final Map<String, Map<int, List<int>>> _chunkBuffers =
      <String, Map<int, List<int>>>{};
  final Map<String, int> _chunkTotals = <String, int>{};
  final Map<String, int> _missingRetries = <String, int>{};
  final List<String> _downloadedFiles = <String>[];
  final Map<String, String?> _videoThumbs = <String, String?>{};
  static const int _maxMissingRetries = 3;
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _eventSub = widget.udpService.events.listen(_handleUdpEvent);
  }

  Future<Directory> _resolveAudioSaveDir() async {
    if (Platform.isAndroid) {
      final Directory downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        return downloads;
      }
    }
    final Directory appDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(appDir.path, 'synced_saved'));
  }

  Future<void> _saveFileToFolder(String filePath) async {
    try {
      final String extension = path.extension(filePath).toLowerCase();
      final bool isImage = <String>['.jpg', '.jpeg', '.png'].contains(extension);
      final bool isVideo = <String>['.mp4', '.mov', '.mkv'].contains(extension);
      final bool isAudio = <String>['.m4a', '.aac', '.wav', '.mp3']
          .contains(extension);

      final bool granted = await _ensureSavePermissions(
        needsImage: isImage,
        needsVideo: isVideo,
        needsAudio: isAudio,
      );
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未授予保存权限')),
        );
        return;
      }

      if (isImage) {
        await ImageGallerySaver.saveFile(filePath, name: 'UDP_Sync');
      } else if (isVideo) {
        await ImageGallerySaver.saveFile(filePath, name: 'UDP_Sync');
      } else {
        final Directory savedDir = await _resolveAudioSaveDir();
        if (!await savedDir.exists()) {
          await savedDir.create(recursive: true);
        }
        final String fileName = path.basename(filePath);
        final File source = File(filePath);
        final File target = File(path.join(savedDir.path, fileName));
        await target.writeAsBytes(await source.readAsBytes());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存到系统相册/文件夹')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<bool> _ensureSavePermissions({
    required bool needsImage,
    required bool needsVideo,
    required bool needsAudio,
  }) async {
    final List<Permission> permissions = <Permission>[];
    if (Platform.isAndroid) {
      if (needsImage) permissions.add(Permission.photos);
      if (needsVideo) permissions.add(Permission.videos);
      if (needsAudio) permissions.add(Permission.audio);
      permissions.add(Permission.storage);
    } else {
      permissions.add(Permission.photos);
    }
    final Map<Permission, PermissionStatus> results =
        await permissions.request();
    return results.values.every((status) => status.isGranted);
  }

  Future<String?> _getVideoThumbnail(String filePath) async {
    if (_videoThumbs.containsKey(filePath)) {
      return _videoThumbs[filePath];
    }
    final String? thumbPath = await VideoThumbnail.thumbnailFile(
      video: filePath,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 200,
      quality: 75,
    );
    _videoThumbs[filePath] = thumbPath;
    return thumbPath;
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showImagePreview(String filePath) async {
    if (!mounted) return;
    final String fileName = path.basename(filePath);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ImagePreviewPage(
          filePath: filePath,
          title: fileName,
        ),
      ),
    );
  }

  Future<void> _showVideoPlayer(String filePath) async {
    if (!mounted) return;
    final String fileName = path.basename(filePath);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => VideoPreviewPage(
          filePath: filePath,
          title: fileName,
        ),
      ),
    );
  }

  Future<void> _showAudioPlayer(String filePath) async {
    if (!mounted) return;
    final String fileName = path.basename(filePath);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AudioPreviewPage(
          filePath: filePath,
          title: fileName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  void _handleUdpEvent(enhanced_udp.UdpDatagramEvent event) {
    final ControlMessage message = event.message;
    if (message.type == MessageTypes.syncListResp) {
      _handleListResponse(message);
    } else if (message.type == MessageTypes.syncFileChunk) {
      _handleFileChunk(message);
    } else if (message.type == MessageTypes.syncFileEnd) {
      _handleFileEnd(message);
    }
  }

  Future<void> _handleListResponse(ControlMessage message) async {
    final List<dynamic>? files = message.payload?['files'] as List<dynamic>?;
    if (files == null) return;
    setState(() {
      _remoteFiles
        ..clear()
        ..addAll(files.whereType<Map<String, dynamic>>());
      _syncStatus = '获取到 ${_remoteFiles.length} 个文件';
    });
    await _requestAllFiles();
  }

  void _handleFileChunk(ControlMessage message) {
    final String? fileId = message.payload?['fileId']?.toString();
    final int? index = _toInt(message.payload?['index']);
    final int? total = _toInt(message.payload?['total']);
    final String? data = message.payload?['data']?.toString();
    if (fileId == null || index == null || total == null || data == null) {
      return;
    }
    _chunkTotals[fileId] = total;
    _chunkBuffers.putIfAbsent(fileId, () => <int, List<int>>{});
    _chunkBuffers[fileId]![index] = base64Decode(data);
    
    // 计算当前文件进度
    final int currentFileChunks = _chunkBuffers[fileId]!.length;
    final int fileProgress = ((currentFileChunks / total) * 100).round();
    
    // 找到当前文件在列表中的索引
    final int fileIndex = _downloadedFiles.indexWhere((file) => file.contains(fileId));
    final int displayIndex = fileIndex >= 0 ? fileIndex + 1 : _currentFileIndex + 1;
    
    setState(() {
      _currentFileProgress = fileProgress;
      _syncStatus = '同步中: $displayIndex/$_totalFiles ($fileProgress%)';
    });
  }

  Future<void> _handleFileEnd(ControlMessage message) async {
    final String? fileId = message.payload?['fileId']?.toString();
    if (fileId == null) return;
    final String fileName = message.payload?['fileName']?.toString() ?? fileId;
    final int? total = _chunkTotals[fileId];
    final Map<int, List<int>>? chunks = _chunkBuffers[fileId];
    if (total == null || chunks == null || chunks.length < (total ?? 0)) {
      _addLog('文件不完整: $fileName');
      return;
    }

    final BytesBuilder builder = BytesBuilder(copy: false);
    for (int i = 0; i < total; i++) {
      final List<int>? part = chunks[i];
      if (part == null) continue;
      builder.add(part);
    }

    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory syncDir = Directory(path.join(appDir.path, 'synced'));
    if (!await syncDir.exists()) {
      await syncDir.create(recursive: true);
    }
    final File outFile = File(path.join(syncDir.path, fileName));
    await outFile.writeAsBytes(builder.takeBytes());

    setState(() {
      _downloadedFiles.add(outFile.path);
      _currentFileIndex = _downloadedFiles.length;
      _currentFileProgress = 100;
      _syncStatus = '同步中: $_currentFileIndex/$_totalFiles (100%)';
    });
    _missingRetries.remove(fileId);
    _addLog('文件完成: $fileName');

    // 检查是否所有文件都完成
    if (_downloadedFiles.length >= _totalFiles) {
      setState(() {
        _syncing = false;
        _syncSuccess = true;
        _syncStatus = '同步完成: $_totalFiles/$_totalFiles (100%)';
      });
      _addLog('所有文件同步完成');
    }
  }

  void _addLog(String message) {
    // 同步页面的日志方法（简单实现）
    print('SyncPage: $message');
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Future<void> _requestList() async {
    final String? deviceId = _selectedDevice;
    if (deviceId == null) return;
    final String? ip = widget.getDeviceIps()[deviceId];
    if (ip == null) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    final ControlMessage request = ControlMessage(
      type: MessageTypes.syncListReq,
      messageId: 'sync-list-$now',
      from: widget.controllerId,
      to: deviceId,
      timestampMs: now,
    );

    await widget.udpService.sendUnicast(
      jsonPayload: request.toJson(),
      ip: ip,
      port: widget.targetPort,
    );
    setState(() {
      _syncStatus = '请求列表中...';
      _syncSuccess = false;
    });
  }

  Future<void> _requestAllFiles() async {
    if (_remoteFiles.isEmpty) {
      setState(() {
        _syncStatus = '没有可同步文件';
      });
      return;
    }
    setState(() {
      _syncing = true;
      _syncSuccess = false;
      _totalFiles = _remoteFiles.length;
      _currentFileIndex = 0;
      _currentFileProgress = 0;
      _syncStatus = '开始同步 $_totalFiles 个文件';
      _downloadedFiles.clear();
    });
    for (final Map<String, dynamic> file in _remoteFiles) {
      final String? fileId = file['fileId']?.toString();
      if (fileId != null) {
        _missingRetries[fileId] = 0;
      }
      await _requestFile(file['fileId']?.toString());
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    // 不要在这里设置_syncing = false，等所有文件完成后再设置
  }

  Future<void> _requestFile(String? fileId) async {
    final String? deviceId = _selectedDevice;
    if (deviceId == null || fileId == null) return;
    final String? ip = widget.getDeviceIps()[deviceId];
    if (ip == null) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ControlMessage request = ControlMessage(
      type: MessageTypes.syncFileReq,
      messageId: 'sync-file-$fileId-$now',
      from: widget.controllerId,
      to: deviceId,
      timestampMs: now,
      payload: <String, dynamic>{'fileId': fileId},
    );
    await widget.udpService.sendUnicast(
      jsonPayload: request.toJson(),
      ip: ip,
      port: widget.targetPort,
      retry: false,
    );
  }

  Future<void> _requestMissingChunks(String fileId, List<int> missing) async {
    final String? deviceId = _selectedDevice;
    if (deviceId == null) return;
    final String? ip = widget.getDeviceIps()[deviceId];
    if (ip == null) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ControlMessage request = ControlMessage(
      type: MessageTypes.syncFileMissing,
      messageId: 'sync-missing-$fileId-$now',
      from: widget.controllerId,
      to: deviceId,
      timestampMs: now,
      payload: <String, dynamic>{
        'fileId': fileId,
        'missing': missing,
      },
    );
    await widget.udpService.sendUnicast(
      jsonPayload: request.toJson(),
      ip: ip,
      port: widget.targetPort,
      retry: false,
    );
  }

  List<int> _resolveMissingIndexes(
    int total,
    Map<int, List<int>>? chunks,
  ) {
    if (chunks == null) return List<int>.generate(total, (int i) => i);
    final List<int> missing = <int>[];
    for (int i = 0; i < total; i++) {
      if (!chunks.containsKey(i)) {
        missing.add(i);
      }
    }
    return missing;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> devices = widget.getDevices();
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新列表',
            onPressed: _syncing ? null : _requestList,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '在线设备',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: devices
                      .map(
                        (device) => ChoiceChip(
                          label: Text(device),
                          selected: _selectedDevice == device,
                          onSelected: (selected) {
                            setState(() {
                              _selectedDevice = selected ? device : null;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedDevice == null || _syncing
                            ? null
                            : _requestList,
                        icon: Icon(_syncSuccess ? Icons.check_circle : Icons.sync),
                        label: Text(_syncSuccess ? '同步成功' : '同步'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _syncSuccess ? Colors.green : null,
                          foregroundColor: _syncSuccess ? Colors.white : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _syncStatus,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _downloadedFiles.isEmpty
                ? const Center(child: Text('暂无同步文件'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _downloadedFiles.length,
                    itemBuilder: (context, index) {
                      final String filePath = _downloadedFiles[index];
                      final String extension =
                          path.extension(filePath).toLowerCase();
                      final bool isImage =
                          <String>['.jpg', '.jpeg', '.png'].contains(extension);
                      final bool isVideo =
                          <String>['.mp4', '.mov', '.mkv'].contains(extension);
                      final bool isAudio = <String>['.m4a', '.aac', '.wav', '.mp3']
                          .contains(extension);
                      final IconData icon =
                          isVideo ? Icons.videocam : Icons.audiotrack;
                      return GestureDetector(
                        onTap: () {
                          if (isImage) {
                            _showImagePreview(filePath);
                          } else if (isVideo) {
                            _showVideoPlayer(filePath);
                          } else if (isAudio) {
                            _showAudioPlayer(filePath);
                          }
                        },
                        onLongPress: () => _saveFileToFolder(filePath),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: isImage
                                      ? Image.file(
                                          File(filePath),
                                          fit: BoxFit.cover,
                                        )
                                      : isVideo
                                          ? FutureBuilder<String?>(
                                              future: _getVideoThumbnail(filePath),
                                              builder: (context, snapshot) {
                                                final String? thumbPath =
                                                    snapshot.data;
                                                if (thumbPath == null) {
                                                  return Container(
                                                    color: Colors.grey.shade200,
                                                    child: Icon(
                                                      icon,
                                                      size: 42,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  );
                                                }
                                                return Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Image.file(
                                                      File(thumbPath),
                                                      fit: BoxFit.cover,
                                                    ),
                                                    Center(
                                                      child: Icon(
                                                        Icons.play_circle_fill,
                                                        size: 42,
                                                        color: Colors.white
                                                            .withOpacity(0.8),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            )
                                          : Container(
                                              color: Colors.grey.shade200,
                                              child: Icon(
                                                icon,
                                                size: 42,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  path.basename(filePath),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
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
