# Flutter 快速运行脚本
Write-Host "🚀 Flutter 快速运行脚本" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Yellow

# 设置工作目录
Set-Location "e:\AndroidProject\webRtc"

# 检查设备连接
Write-Host "📱 检查设备连接..." -ForegroundColor Blue
$devices = adb devices | Select-String "device$"
if (-not $devices) {
    Write-Host "❌ 未找到连接的设备" -ForegroundColor Red
    Read-Host "按 Enter 键退出"
    exit 1
}

Write-Host "✅ 设备已连接" -ForegroundColor Green

# 清理构建缓存
Write-Host "🧹 清理构建缓存..." -ForegroundColor Blue
flutter clean

# 获取依赖
Write-Host "📦 获取依赖..." -ForegroundColor Blue
flutter pub get

# 构建 APK
Write-Host "🔨 构建 APK..." -ForegroundColor Blue
flutter build apk --debug

# 检查 APK 文件
$apkPath = "build\outputs\apk\debug\app-debug.apk"
if (Test-Path $apkPath) {
    Write-Host "✅ APK 构建成功: $apkPath" -ForegroundColor Green
    
    # 安装 APK
    Write-Host "📲 安装 APK..." -ForegroundColor Blue
    adb install -r $apkPath
    
    if ($LASTEXITCODE -eq 0) {
        # 启动应用
        Write-Host "🎯 启动应用..." -ForegroundColor Blue
        adb shell am start -n com.example.webrtc/.MainActivity
        
        Write-Host "🎉 应用已成功安装并启动！" -ForegroundColor Green
    } else {
        Write-Host "❌ 安装失败" -ForegroundColor Red
    }
} else {
    Write-Host "❌ APK 文件未找到: $apkPath" -ForegroundColor Red
    Write-Host "🔍 搜索所有 APK 文件:" -ForegroundColor Yellow
    Get-ChildItem -Path "build" -Filter "*.apk" -Recurse | ForEach-Object { $_.FullName }
}

Write-Host ""
Write-Host "💡 提示: 如果 flutter run 仍然无法自动安装，请使用此脚本" -ForegroundColor Cyan
Read-Host "按 Enter 键退出"
