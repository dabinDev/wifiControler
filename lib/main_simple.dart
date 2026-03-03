import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebRTC Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RoleSelectionPage(),
    );
  }
}

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Control Suite'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '选择角色',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ControlPage()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.control_camera, size: 48, color: Colors.blue.shade700),
                      const SizedBox(height: 8),
                      const Text('控制端', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('发送命令控制其他设备'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ControlledPage()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.smartphone, size: 48, color: Colors.red.shade700),
                      const SizedBox(height: 8),
                      const Text('被控制端', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('接收命令并执行操作'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('控制端'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          '控制端功能正在开发中...',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class ControlledPage extends StatelessWidget {
  const ControlledPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('被控制端'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          '被控制端功能正在开发中...',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
