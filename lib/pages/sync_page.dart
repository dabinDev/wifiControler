import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/control_message.dart';
import '../protocol/message_types.dart';
import '../services/udp_service_enhanced.dart' as enhanced_udp;

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
  String _syncStatus = '待同步';

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
        await GallerySaver.saveImage(filePath, albumName: 'UDP Sync');
      } else if (isVideo) {
        await GallerySaver.saveVideo(filePath, albumName: 'UDP Sync');
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
      imageFormat: ImageFormat.JPEG,
      maxHeight: 240,
      quality: 75,
    );
    _videoThumbs[filePath] = thumbPath;
    return thumbPath;
  }

  Future<void> _showVideoPlayer(String filePath) async {
    _videoController?.dispose();
    final VideoPlayerController controller =
        VideoPlayerController.file(File(filePath));
    await controller.initialize();
    await controller.play();
    _videoController = controller;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final Duration duration = value.duration;
                  final Duration position = value.position;
                  final double max = duration.inMilliseconds.toDouble();
                  final double current = position.inMilliseconds
                      .clamp(0, duration.inMilliseconds)
                      .toDouble();
                  return Column(
                    children: [
                      Slider(
                        value: max == 0 ? 0 : current,
                        max: max == 0 ? 1 : max,
                        onChanged: (newValue) {
                          controller.seekTo(
                            Duration(milliseconds: newValue.toInt()),
                          );
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                            ),
                            onPressed: () {
                              if (value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                            },
                          ),
                          Text(
                            '${_formatDuration(position)} / ${_formatDuration(duration)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.pause();
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAudioPlayer(String filePath) async {
    _audioPlayer?.dispose();
    final AudioPlayer player = AudioPlayer();
    await player.setFilePath(filePath);
    await player.play();
    _audioPlayer = player;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snapshot) {
            final Duration position = snapshot.data ?? Duration.zero;
            final Duration duration = player.duration ?? Duration.zero;
            final double max = duration.inMilliseconds.toDouble();
            final double current = position.inMilliseconds
                .clamp(0, duration.inMilliseconds)
                .toDouble();
            return AlertDialog(
              title: Text(path.basename(filePath)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: max == 0 ? 0 : current,
                    max: max == 0 ? 1 : max,
                    onChanged: (newValue) {
                      player.seek(
                        Duration(milliseconds: newValue.toInt()),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          player.playing
                              ? Icons.pause_circle
                              : Icons.play_circle,
                        ),
                        onPressed: () async {
                          if (player.playing) {
                            await player.pause();
                          } else {
                            await player.play();
                          }
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                      Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await player.stop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('停止'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showImagePreview(String filePath) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.file(File(filePath), fit: BoxFit.contain),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
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
    setState(() {
      _syncStatus = '接收中: $fileId (${_chunkBuffers[fileId]!.length}/$total)';
    });
  }

  Future<void> _handleFileEnd(ControlMessage message) async {
    final String? fileId = message.payload?['fileId']?.toString();
    if (fileId == null) return;
    final String fileName = message.payload?['fileName']?.toString() ?? fileId;
    final int? total = _chunkTotals[fileId];
    final Map<int, List<int>>? chunks = _chunkBuffers[fileId];
    if (total == null || chunks == null || chunks.length < (total ?? 0)) {
      if (total == null) {
        return;
      }
      final List<int> missing = _resolveMissingIndexes(total, chunks);
      final int retries = _missingRetries[fileId] ?? 0;
      if (missing.isEmpty) return;
      if (retries >= _maxMissingRetries) {
        setState(() {
          _syncStatus = '文件缺块: $fileName (重试失败)';
        });
        return;
      }
      _missingRetries[fileId] = retries + 1;
      await _requestMissingChunks(fileId, missing);
      setState(() {
        _syncStatus = '请求缺块: $fileName (${missing.length})';
      });
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
      _syncStatus = '同步完成: $fileName';
    });
    _missingRetries.remove(fileId);
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
      _syncStatus = '开始同步 ${_remoteFiles.length} 个文件';
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
    setState(() {
      _syncing = false;
    });
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
                        icon: const Icon(Icons.sync),
                        label: const Text('同步'),
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
