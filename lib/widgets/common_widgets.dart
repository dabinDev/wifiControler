import 'package:flutter/material.dart';
import '../core/theme_manager.dart';

/// 状态指示器组件
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.status,
    this.size = 12.0,
    this.showLabel = false,
    this.label,
  });

  final ConnectionStatus status;
  final double size;
  final bool showLabel;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = themeManager.getCurrentTheme(
      systemBrightness: Theme.of(context).brightness,
    );

    Color getColor() {
      switch (status) {
        case ConnectionStatus.connected:
          return theme.colorScheme.success;
        case ConnectionStatus.connecting:
          return theme.colorScheme.warning;
        case ConnectionStatus.disconnected:
          return theme.colorScheme.error;
        case ConnectionStatus.unknown:
          return theme.colorScheme.onSurface.withOpacity(0.5);
      }
    }

    String getLabelText() {
      if (label != null) return label!;
      switch (status) {
        case ConnectionStatus.connected:
          return '已连接';
        case ConnectionStatus.connecting:
          return '连接中';
        case ConnectionStatus.disconnected:
          return '未连接';
        case ConnectionStatus.unknown:
          return '未知';
      }
    }

    Widget indicator = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: getColor(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: getColor().withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );

    if (status == ConnectionStatus.connecting) {
      indicator = TweenAnimationBuilder<double>(
        duration: const Duration(seconds: 1),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (BuildContext context, double value, Widget? child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: 0.6 + (0.4 * value),
              child: child,
            ),
          );
        },
        child: indicator,
      );
    }

    if (!showLabel) return indicator;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        indicator,
        const SizedBox(width: 8),
        Text(
          getLabelText(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: getColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 连接状态枚举
enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  unknown,
}

/// 状态卡片组件
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.status,
    this.onTap,
    this.color,
  });

  final String title;
  final String value;
  final IconData? icon;
  final ConnectionStatus? status;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = themeManager.getCurrentTheme(
      systemBrightness: Theme.of(context).brightness,
    );

    Color cardColor = color ?? theme.colorScheme.surface;
    Color textColor = theme.colorScheme.onSurface;

    if (status != null) {
      switch (status!) {
        case ConnectionStatus.connected:
          cardColor = theme.colorScheme.success.withOpacity(0.1);
          textColor = theme.colorScheme.success;
          break;
        case ConnectionStatus.connecting:
          cardColor = theme.colorScheme.warning.withOpacity(0.1);
          textColor = theme.colorScheme.warning;
          break;
        case ConnectionStatus.disconnected:
          cardColor = theme.colorScheme.error.withOpacity(0.1);
          textColor = theme.colorScheme.error;
          break;
        case ConnectionStatus.unknown:
          break;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(
                      icon,
                      size: 20,
                      color: textColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (status != null)
                    StatusIndicator(
                      status: status!,
                      size: 8,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 操作按钮组件
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ActionButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ActionButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = themeManager.getCurrentTheme(
      systemBrightness: Theme.of(context).brightness,
    );

    Widget button;
    switch (variant) {
      case ActionButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildButtonContent(theme),
        );
        break;
      case ActionButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildButtonContent(theme),
        );
        break;
      case ActionButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildButtonContent(theme),
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  Widget _buildButtonContent(AppTheme theme) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == ActionButtonVariant.primary
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}

/// 按钮变体枚举
enum ActionButtonVariant {
  primary,
  secondary,
  text,
}

/// 信息卡片组件
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
    this.padding,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = themeManager.getCurrentTheme(
      systemBrightness: Theme.of(context).brightness,
    );

    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 日志项组件
class LogItem extends StatelessWidget {
  const LogItem({
    super.key,
    required this.message,
    required this.timestamp,
    required this.level,
    this.tag,
    this.onTap,
  });

  final String message;
  final DateTime timestamp;
  final LogLevel level;
  final String? tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = themeManager.getCurrentTheme(
      systemBrightness: Theme.of(context).brightness,
    );

    Color getLevelColor() {
      switch (level) {
        case LogLevel.info:
          return theme.colorScheme.info;
        case LogLevel.warning:
          return theme.colorScheme.warning;
        case LogLevel.error:
          return theme.colorScheme.error;
        case LogLevel.debug:
          return theme.colorScheme.onSurface.withOpacity(0.7);
      }
    }

    String getLevelIcon() {
      switch (level) {
        case LogLevel.info:
          return 'ℹ️';
        case LogLevel.warning:
          return '⚠️';
        case LogLevel.error:
          return '❌';
        case LogLevel.debug:
          return '🔍';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: getLevelColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.left(
                color: getLevelColor(),
                width: 3,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      getLevelIcon(),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(timestamp),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (tag != null) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: null,
                  softWrap: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

/// 日志级别枚举
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 设备卡片组件
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.status,
    this.ipAddress,
    this.lastSeen,
    this.onTap,
    this.onLongPress,
    this.actions,
  });

  final String deviceId;
  final String deviceName;
  final ConnectionStatus status;
  final String? ipAddress;
  final DateTime? lastSeen;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = themeManager.getCurrentTheme(
      systemBrightness: Theme.of(context).brightness,
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  StatusIndicator(status: status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          deviceName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deviceId,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
              if (ipAddress != null || lastSeen != null) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (ipAddress != null) ...<Widget>[
                      Icon(
                        Icons.wifi,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ipAddress!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                    if (ipAddress != null && lastSeen != null)
                      const SizedBox(width: 16),
                    if (lastSeen != null) ...<Widget>[
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatLastSeen(lastSeen!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final Duration diff = DateTime.now().difference(lastSeen);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }
}

/// 空状态组件
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.action,
  });

  final String title;
  final String description;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = themeManager.getCurrentTheme(
      systemBrightness: Theme.of(context).brightness,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
