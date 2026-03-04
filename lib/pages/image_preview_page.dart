import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.black,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '图片加载失败',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
