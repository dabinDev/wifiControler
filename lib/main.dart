import 'package:flutter/material.dart';

import 'pages/control_page.dart';
import 'pages/controlled_page.dart';

void main() {
  runApp(const ControlCenterApp());
}

class ControlCenterApp extends StatelessWidget {
  const ControlCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UDP Control Suite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C86)),
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
      appBar: AppBar(title: const Text('UDP Control Suite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Card(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                title: const Text('组网说明（点击展开）'),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                children: const <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('1) 一台手机开启热点，其他手机连接同一热点'),
                  ),
                  SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('2) 所有设备保持前台，先点击"扫描在线设备"'),
                  ),
                  SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('3) 选择角色后开始发送命令/状态同步'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '请选择设备角色',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: Card.filled(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => const ControlPage(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: <Widget>[
                            Icon(Icons.control_camera, size: 48),
                            SizedBox(height: 12),
                            Text('控制端', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                            SizedBox(height: 8),
                            Text('发送命令，管理设备', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card.filled(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => const ControlledPage(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: <Widget>[
                            Icon(Icons.phone_android, size: 48),
                            SizedBox(height: 12),
                            Text('被控端', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                            SizedBox(height: 8),
                            Text('接收命令，执行任务', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
