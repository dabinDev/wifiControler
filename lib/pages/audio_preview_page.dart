import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class AudioPreviewPage extends StatefulWidget {
  const AudioPreviewPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<AudioPreviewPage> createState() => _AudioPreviewPageState();
}

class _AudioPreviewPageState extends State<AudioPreviewPage> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<double> _waveformData = [];

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      _audioPlayer = AudioPlayer();
      
      // 监听播放状态
      _audioPlayer!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });

      // 监听播放位置
      _audioPlayer!.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      // 监听音频时长
      _audioPlayer!.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _duration = duration!;
          });
        }
      });

      await _audioPlayer!.setFilePath(widget.filePath);
      _generateWaveformData();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _generateWaveformData() {
    // 生成模拟波形数据（实际应用中可以从音频文件解析真实波形）
    final Random random = Random();
    _waveformData = List.generate(100, (index) {
      return random.nextDouble() * 0.8 + 0.1;
    });
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.play();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
                    '音频加载失败',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              )
            : _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 音频文件图标
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(60),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.audiotrack,
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // 波形显示
                        Container(
                          height: 120,
                          child: CustomPaint(
                            painter: WaveformPainter(
                              waveformData: _waveformData,
                              progress: _duration.inMilliseconds > 0 
                                  ? _position.inMilliseconds / _duration.inMilliseconds 
                                  : 0.0,
                              isPlaying: _isPlaying,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // 时间显示
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // 播放控制按钮
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.replay_10,
                                color: Colors.white,
                                size: 48,
                              ),
                              onPressed: () async {
                                final newPosition = _position - const Duration(seconds: 10);
                                await _audioPlayer!.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                              },
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                                color: Colors.white,
                                size: 80,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(
                                Icons.forward_10,
                                color: Colors.white,
                                size: 48,
                              ),
                              onPressed: () async {
                                final newPosition = _position + const Duration(seconds: 10);
                                await _audioPlayer!.seek(newPosition > _duration ? _duration : newPosition);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final bool isPlaying;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double barWidth = size.width / waveformData.length;
    final double centerY = size.height / 2;

    for (int i = 0; i < waveformData.length; i++) {
      final double barHeight = waveformData[i] * size.height * 0.4;
      final double barX = i * barWidth + barWidth / 2;
      
      // 根据播放进度设置颜色
      if (i < waveformData.length * progress) {
        paint.color = isPlaying ? Colors.red : Colors.blue;
      } else {
        paint.color = Colors.white.withOpacity(0.3);
      }

      // 绘制上半部分
      canvas.drawLine(
        Offset(barX, centerY),
        Offset(barX, centerY - barHeight),
        paint,
      );

      // 绘制下半部分
      canvas.drawLine(
        Offset(barX, centerY),
        Offset(barX, centerY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // 总是重绘以显示动画效果
  }
}
