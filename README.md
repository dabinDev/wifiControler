# Flutter UDP 控制套件

一个基于 Flutter 的跨平台设备控制系统，支持通过 UDP 网络协议实现远程设备控制和文件同步。

## 📱 功能特性

### 🎯 核心功能
- **双角色架构**：设备可作为控制端或被控制端
- **实时控制**：支持拍照、录像、录音等硬件操作
- **文件同步**：高效的文件传输和同步功能
- **状态监控**：实时设备状态显示和心跳检测

### 🛠️ 控制端功能
- **设备发现**：自动扫描局域网内的被控制设备
- **命令发送**：支持多种控制指令的发送
- **文件管理**：远程文件浏览和下载
- **进度显示**：文件同步进度百分比显示
- **状态反馈**：实时显示设备响应和执行状态

### 📱 被控制端功能
- **硬件控制**：相机拍照、视频录制、音频录制
- **智能操作**：操作状态互斥，防止冲突
- **状态上报**：定期向控制端发送设备状态
- **文件服务**：提供文件列表和文件传输服务
- **通知系统**：接收控制指令的实时通知

## 🚀 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK (Android 开发)
- Xcode (iOS 开发)

### 安装依赖
```bash
flutter pub get
```

### 运行应用
```bash
# 开发模式运行
flutter run

# 构建发布版本
flutter build apk --release
flutter build ios --release
```

## 📖 使用指南

### 1. 启动应用
应用启动后会显示角色选择界面：
- **控制端**：用于控制其他设备
- **被控制端**：接收控制指令

### 2. 控制端使用

#### 设备连接
1. 启动控制端应用
2. 应用会自动扫描局域网内的被控制设备
3. 在设备列表中选择要控制的设备

#### 发送控制指令
1. 在命令标签页中选择或输入控制指令
2. 点击发送按钮
3. 查看设备响应和执行结果

#### 文件同步
1. 切换到同步标签页
2. 选择目标设备
3. 点击同步按钮获取文件列表
4. 查看同步进度：`同步中: 3/10 (45%)`
5. 同步完成后按钮变绿色显示"同步成功"

### 3. 被控制端使用

#### 接收控制指令
1. 启动被控制端应用
2. 应用会自动注册到网络中
3. 等待控制端连接和指令

#### 手动操作
1. 点击界面上的操作按钮
2. 支持的操作：
   - 📸 拍照
   - 🎥 录像
   - 🎤 录音
3. **智能操作逻辑**：
   - 录音中再次点击录音 → 停止录音
   - 录像中再次点击录像 → 停止录像
   - 录音中点击录像 → 停止录音并开始录像

#### 文件浏览
1. 点击右上角的文件夹图标
2. 查看本地媒体文件（图片、视频、音频）
3. 点击文件可预览内容

## 🎮 控制指令

### 基础指令
| 指令 | 功能 | 说明 |
|------|------|------|
| 拍照 | TAKE_PHOTO | 拍摄一张照片 |
| 开始录像 | RECORD_START | 开始视频录制 |
| 停止录像 | RECORD_STOP | 停止视频录制 |
| 开始录音 | AUDIO_START | 开始音频录制 |
| 停止录音 | AUDIO_STOP | 停止音频录制 |

### 文件操作
| 指令 | 功能 | 说明 |
|------|------|------|
| 同步列表 | SYNC_LIST_REQ | 获取设备文件列表 |
| 同步文件 | SYNC_FILE_REQ | 请求同步指定文件 |
| 缺块重传 | SYNC_FILE_MISSING | 请求缺失文件块 |

## 📊 状态监控

### 设备状态信息
- **电池电量**：实时电量百分比和充电状态
- **存储空间**：可用存储空间（GB）
- **CPU温度**：处理器温度（℃）
- **WiFi信号**：信号强度（dBm）
- **录制状态**：当前录制操作状态

### 网络状态
- **连接状态**：网络连接状态指示
- **设备发现**：自动发现和清理离线设备
- **心跳检测**：5秒间隔心跳，15秒超时清理

## 🔧 技术架构

### 网络协议
- **UDP广播**：设备发现和心跳检测
- **UDP单播**：控制指令和ACK确认
- **文件传输**：分块传输，支持断点续传

### 状态管理
- **操作互斥**：同时只能进行一种录制操作
- **智能切换**：新操作自动停止冲突操作
- **状态同步**：实时状态更新和通知

### 错误处理
- **类型安全**：安全的类型转换，避免运行时错误
- **网络异常**：自动重连和错误恢复
- **并发保护**：防止状态更新冲突

## 📁 项目结构

```
lib/
├── main.dart                 # 应用入口
├── pages/                    # 页面文件
│   ├── control_page.dart     # 控制端页面
│   ├── controlled_page.dart  # 被控制端页面
│   ├── sync_page.dart        # 文件同步页面
│   └── media_files_page.dart # 媒体文件浏览页面
├── services/                 # 服务层
│   ├── hardware_service.dart # 硬件控制服务
│   └── enhanced_udp.dart     # UDP网络服务
├── protocol/                 # 协议定义
│   └── message_types.dart    # 消息类型定义
└── core/                     # 核心组件
    ├── service_manager.dart  # 服务管理器
    └── theme_manager.dart    # 主题管理器
```

## 🔌 权限要求

### Android 权限
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS 权限
```xml
<key>NSCameraUsageDescription</key>
<string>此应用需要访问相机进行拍照和录像</string>
<key>NSMicrophoneUsageDescription</key>
<string>此应用需要访问麦克风进行录音</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>此应用需要访问相册保存媒体文件</string>
```

## 🐛 故障排除

### 常见问题

#### 1. 设备发现失败
- **检查网络**：确保设备在同一局域网内
- **防火墙**：检查防火墙是否阻止UDP通信
- **端口冲突**：确保8888和8889端口未被占用

#### 2. 控制指令无响应
- **网络连接**：检查网络连接状态
- **设备状态**：确认被控制端正在运行
- **权限检查**：确认应用具有必要的权限

#### 3. 文件同步失败
- **存储空间**：检查设备存储空间是否充足
- **文件权限**：确认应用有文件读写权限
- **网络稳定性**：确保网络连接稳定

### 调试模式
启用调试模式查看详细日志：
```bash
flutter run --debug
```

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

如有问题或建议，请通过以下方式联系：
- 提交 Issue
- 发送邮件
- 技术讨论群

---

**注意**：本应用仅用于合法的设备控制和测试目的，请遵守相关法律法规。
