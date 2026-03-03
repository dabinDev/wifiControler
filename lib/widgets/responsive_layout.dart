import 'package:flutter/material.dart';

/// 屏幕尺寸分类
enum ScreenSize {
  mobile,
  tablet,
  desktop,
}

/// 响应式断点配置
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
}

/// 响应式配置
class ResponsiveConfig {
  const ResponsiveConfig({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final T mobile;
  final T? tablet;
  final T? desktop;

  T getValue(BuildContext context) {
    final ScreenSize screenSize = getScreenSize(context);
    
    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// 响应式布局助手
class ResponsiveHelper {
  /// 获取屏幕尺寸分类
  static ScreenSize getScreenSize(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    
    if (width < ResponsiveBreakpoints.mobile) {
      return ScreenSize.mobile;
    } else if (width < ResponsiveBreakpoints.tablet) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.desktop;
    }
  }

  /// 判断是否为移动设备
  static bool isMobile(BuildContext context) {
    return getScreenSize(context) == ScreenSize.mobile;
  }

  /// 判断是否为平板设备
  static bool isTablet(BuildContext context) {
    return getScreenSize(context) == ScreenSize.tablet;
  }

  /// 判断是否为桌面设备
  static bool isDesktop(BuildContext context) {
    return getScreenSize(context) == ScreenSize.desktop;
  }

  /// 获取响应式值
  static T getValue<T>(BuildContext context, ResponsiveConfig<T> config) {
    return config.getValue(context);
  }

  /// 获取响应式边距
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final ScreenSize size = getScreenSize(context);
    
    switch (size) {
      case ScreenSize.mobile:
        return const EdgeInsets.all(16);
      case ScreenSize.tablet:
        return const EdgeInsets.all(24);
      case ScreenSize.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// 获取响应式水平边距
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    final ScreenSize size = getScreenSize(context);
    
    switch (size) {
      case ScreenSize.mobile:
        return const EdgeInsets.symmetric(horizontal: 16);
      case ScreenSize.tablet:
        return const EdgeInsets.symmetric(horizontal: 24);
      case ScreenSize.desktop:
        return const EdgeInsets.symmetric(horizontal: 32);
    }
  }

  /// 获取响应式垂直边距
  static EdgeInsets getResponsiveVerticalPadding(BuildContext context) {
    final ScreenSize size = getScreenSize(context);
    
    switch (size) {
      case ScreenSize.mobile:
        return const EdgeInsets.symmetric(vertical: 16);
      case ScreenSize.tablet:
        return const EdgeInsets.symmetric(vertical: 24);
      case ScreenSize.desktop:
        return const EdgeInsets.symmetric(vertical: 32);
    }
  }

  /// 获取响应式间距
  static double getResponsiveSpacing(BuildContext context) {
    final ScreenSize size = getScreenSize(context);
    
    switch (size) {
      case ScreenSize.mobile:
        return 16;
      case ScreenSize.tablet:
        return 24;
      case ScreenSize.desktop:
        return 32;
    }
  }

  /// 获取响应式列数
  static int getResponsiveColumns(BuildContext context) {
    final ScreenSize size = getScreenSize(context);
    
    switch (size) {
      case ScreenSize.mobile:
        return 1;
      case ScreenSize.tablet:
        return 2;
      case ScreenSize.desktop:
        return 3;
    }
  }

  /// 获取响应式最大宽度
  static double getResponsiveMaxWidth(BuildContext context) {
    final ScreenSize size = getScreenSize(context);
    
    switch (size) {
      case ScreenSize.mobile:
        return double.infinity;
      case ScreenSize.tablet:
        return 800;
      case ScreenSize.desktop:
        return 1200;
    }
  }
}

/// 响应式构建器
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget Function(BuildContext) mobile;
  final Widget Function(BuildContext)? tablet;
  final Widget Function(BuildContext)? desktop;

  @override
  Widget build(BuildContext context) {
    final ScreenSize size = ResponsiveHelper.getScreenSize(context);
    
    switch (size) {
      case ScreenSize.mobile:
        return mobile(context);
      case ScreenSize.tablet:
        return tablet?.call(context) ?? mobile(context);
      case ScreenSize.desktop:
        return desktop?.call(context) ?? tablet?.call(context) ?? mobile(context);
    }
  }
}

/// 响应式布局组件
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.backgroundColor,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: ResponsiveBuilder(
        mobile: (BuildContext context) => _wrapWithPadding(context, mobile),
        tablet: tablet != null ? (BuildContext context) => _wrapWithPadding(context, tablet!) : null,
        desktop: desktop != null ? (BuildContext context) => _wrapWithMaxWidth(context, desktop!) : null,
      ),
    );
  }

  Widget _wrapWithPadding(BuildContext context, Widget child) {
    return Padding(
      padding: ResponsiveHelper.getResponsivePadding(context),
      child: child,
    );
  }

  Widget _wrapWithMaxWidth(BuildContext context, Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveHelper.getResponsiveMaxWidth(context),
        ),
        child: Padding(
          padding: ResponsiveHelper.getResponsivePadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// 响应式网格视图
class ResponsiveGridView extends StatelessWidget {
  const ResponsiveGridView({
    super.key,
    required this.children,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final int columns = ResponsiveHelper.getResponsiveColumns(context);
    final double responsiveSpacing = ResponsiveHelper.getResponsiveSpacing(context);
    
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: responsiveSpacing,
      mainAxisSpacing: responsiveSpacing,
      padding: padding ?? ResponsiveHelper.getResponsiveHorizontalPadding(context),
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: children,
    );
  }
}

/// 响应式列表视图
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.spacing = 8.0,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<Widget> children;
  final double spacing;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final double responsiveSpacing = ResponsiveHelper.getResponsiveSpacing(context);
    
    return ListView.separated(
      padding: padding ?? ResponsiveHelper.getResponsiveHorizontalPadding(context),
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: children.length,
      separatorBuilder: (BuildContext context, int index) => SizedBox(height: responsiveSpacing),
      itemBuilder: (BuildContext context, int index) => children[index],
    );
  }
}

/// 响应式行布局
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.alignment = WrapAlignment.start,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final WrapAlignment runAlignment;
  final WrapCrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final double responsiveSpacing = ResponsiveHelper.getResponsiveSpacing(context);
    
    return Wrap(
      spacing: spacing > 0 ? responsiveSpacing : 0,
      runSpacing: runSpacing > 0 ? responsiveSpacing : 0,
      alignment: alignment,
      runAlignment: runAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

/// 响应式列布局
class ResponsiveColumn extends StatelessWidget {
  const ResponsiveColumn({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final double responsiveSpacing = ResponsiveHelper.getResponsiveSpacing(context);
    
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _buildChildren(responsiveSpacing),
    );
  }

  List<Widget> _buildChildren(double spacing) {
    if (children.isEmpty) return <Widget>[];
    
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1 && spacing > 0) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }
}

/// 响应式容器
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.margin,
    this.padding,
    this.constraints,
    this.alignment,
    this.decoration,
    this.foregroundDecoration,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final BoxConstraints? constraints;
  final Alignment? alignment;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final double? responsiveWidth = width;
    final double? responsiveHeight = height;
    final EdgeInsets? responsiveMargin = margin ?? ResponsiveHelper.getResponsiveHorizontalPadding(context);
    final EdgeInsets? responsivePadding = padding;
    
    return Container(
      width: responsiveWidth,
      height: responsiveHeight,
      margin: responsiveMargin,
      padding: responsivePadding,
      constraints: constraints,
      alignment: alignment,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// 响应式卡片
class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.elevation,
    this.shape,
    this.color,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double? elevation;
  final ShapeBorder? shape;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets? responsiveMargin = margin ?? ResponsiveHelper.getResponsiveHorizontalPadding(context);
    final EdgeInsets? responsivePadding = padding ?? const EdgeInsets.all(16);
    final double responsiveElevation = elevation ?? (ResponsiveHelper.isMobile(context) ? 2 : 4);
    
    Widget card = Card(
      margin: responsiveMargin,
      elevation: responsiveElevation,
      shape: shape,
      color: color,
      child: Padding(
        padding: responsivePadding,
        child: child,
      ),
    );
    
    if (onTap != null || onLongPress != null) {
      card = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: shape?.borderRadius ?? BorderRadius.circular(12),
        child: card,
      );
    }
    
    return card;
  }
}

/// 响应式扩展方法
extension ResponsiveExtensions on BuildContext {
  ScreenSize get screenSize => ResponsiveHelper.getScreenSize(this);
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  
  EdgeInsets get responsivePadding => ResponsiveHelper.getResponsivePadding(this);
  EdgeInsets get responsiveHorizontalPadding => ResponsiveHelper.getResponsiveHorizontalPadding(this);
  EdgeInsets get responsiveVerticalPadding => ResponsiveHelper.getResponsiveVerticalPadding(this);
  double get responsiveSpacing => ResponsiveHelper.getResponsiveSpacing(this);
  int get responsiveColumns => ResponsiveHelper.getResponsiveColumns(this);
  double get responsiveMaxWidth => ResponsiveHelper.getResponsiveMaxWidth(this);
}
