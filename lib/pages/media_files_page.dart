import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../services/hardware_service.dart';
import 'image_preview_page.dart';
import 'video_preview_page.dart';
import 'audio_preview_page.dart';

class MediaFilesPage extends StatefulWidget {
  const MediaFilesPage({super.key});

  @override
  State<MediaFilesPage> createState() => _MediaFilesPageState();
}

class _MediaFilesPageState extends State<MediaFilesPage> {
  final List<Map<String, dynamic>> _mediaFiles = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMediaFiles();
  }

  Future<void> _loadMediaFiles() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final List<Map<String, dynamic>> files = await _collectMediaFiles();
      
      if (mounted) {
        setState(() {
          _mediaFiles.clear();
          _mediaFiles.addAll(files);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载文件失败: $e';
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _collectMediaFiles() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory capturesDir = Directory(path.join(appDir.path, 'captures'));
    final Directory recordingsDir = Directory(path.join(appDir.path, 'recordings'));

    final List<FileSystemEntity> entities = <FileSystemEntity>[];
    
    if (await capturesDir.exists()) {
      entities.addAll(await capturesDir.list().toList());
    }
    
    if (await recordingsDir.exists()) {
      entities.addAll(await recordingsDir.list().toList());
    }

    final List<Map<String, dynamic>> files = <Map<String, dynamic>>[];
    
    // 按修改时间排序，最新的在前面
    entities.sort((a, b) {
      final DateTime aModified = a.statSync().modified;
      final DateTime bModified = b.statSync().modified;
      return bModified.compareTo(aModified);
    });

    for (final FileSystemEntity entity in entities) {
      if (entity is! File) continue;
      
      final String filePath = entity.path;
      final int fileSize = await entity.length();
      final String extension = path.extension(filePath).toLowerCase();
      final String type = _resolveMediaType(extension);
      final DateTime modified = entity.statSync().modified;
      
      files.add(<String, dynamic>{
        'filePath': filePath,
        'fileName': path.basename(filePath),
        'fileSize': fileSize,
        'type': type,
        'modified': modified,
      });
    }

    return files;
  }

  String _resolveMediaType(String extension) {
    if (<String>['.jpg', '.jpeg', '.png'].contains(extension)) {
      return 'photo';
    }
    if (<String>['.mp4', '.mov', '.mkv'].contains(extension)) {
      return 'video';
    }
    if (<String>['.m4a', '.aac', '.wav', '.mp3'].contains(extension)) {
      return 'audio';
    }
    return 'file';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _openFile(Map<String, dynamic> file) async {
    final String filePath = file['filePath'] as String;
    final String fileName = file['fileName'] as String;
    final String type = file['type'] as String;

    Widget previewPage;
    
    switch (type) {
      case 'photo':
        previewPage = ImagePreviewPage(filePath: filePath, title: fileName);
        break;
      case 'video':
        previewPage = VideoPreviewPage(filePath: filePath, title: fileName);
        break;
      case 'audio':
        previewPage = AudioPreviewPage(filePath: filePath, title: fileName);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('不支持的文件类型')),
        );
        return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => previewPage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体文件'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMediaFiles,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red.shade400, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMediaFiles,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _mediaFiles.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无媒体文件', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _mediaFiles.length,
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> file = _mediaFiles[index];
                        final String filePath = file['filePath'] as String;
                        final String fileName = file['fileName'] as String;
                        final String type = file['type'] as String;
                        final int fileSize = file['fileSize'] as int;
                        final DateTime modified = file['modified'] as DateTime;

                        IconData icon;
                        Color color;
                        
                        switch (type) {
                          case 'photo':
                            icon = Icons.image;
                            color = Colors.blue;
                            break;
                          case 'video':
                            icon = Icons.videocam;
                            color = Colors.red;
                            break;
                          case 'audio':
                            icon = Icons.audiotrack;
                            color = Colors.green;
                            break;
                          default:
                            icon = Icons.insert_drive_file;
                            color = Colors.grey;
                        }

                        return Card(
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _openFile(file),
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    ),
                                    child: type == 'photo'
                                        ? Image.file(
                                            File(filePath),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(icon, color: color, size: 48);
                                            },
                                          )
                                        : Icon(icon, color: color, size: 48),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatFileSize(fileSize),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(modified),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
