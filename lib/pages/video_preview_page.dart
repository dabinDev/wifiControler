import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewPage extends StatefulWidget {
  const VideoPreviewPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.filePath));
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
      });
      
      // 监听播放状态
      _controller!.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _controller!.value.isPlaying;
          });
        }
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: _hasError
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '视频加载失败',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              )
            : !_isInitialized
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 64,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
