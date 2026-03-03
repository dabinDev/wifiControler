# Flutter UDP Control Suite 代码风格指南

## 📋 概述

本文档定义了 Flutter UDP Control Suite 项目的代码风格、命名规范和最佳实践，确保代码的一致性、可读性和可维护性。

## 🎯 核心原则

1. **一致性** - 所有代码遵循统一的风格规范
2. **可读性** - 代码应该易于理解和维护
3. **简洁性** - 避免冗余和复杂的表达
4. **可维护性** - 便于后续的修改和扩展

## 📁 文件组织结构

```
lib/
├── constants/          # 常量定义
│   └── app_constants.dart
├── core/              # 核心服务
│   ├── service_manager.dart
│   └── theme_manager.dart
├── extensions/        # 扩展方法
│   └── extensions.dart
├── utils/             # 工具类
│   └── common_utils.dart
├── widgets/           # UI组件
│   ├── common_widgets.dart
│   └── responsive_layout.dart
├── pages/             # 页面
├── services/          # 业务服务
├── models/            # 数据模型
├── exports.dart       # 统一导出
└── main.dart          # 应用入口
```

## 🏷️ 命名规范

### 文件命名
- 使用小写字母和下划线：`service_manager.dart`
- 组件文件以功能命名：`common_widgets.dart`
- 页面文件以页面类型命名：`control_page.dart`

### 类命名
- 使用 PascalCase（大驼峰命名）：`ServiceManager`
- 抽象类以 `Base` 或 `Abstract` 开头：`BaseService`
- 工具类以具体功能命名：`DateTimeUtils`
- 异常类以 `Exception` 结尾：`AppException`

### 变量命名
- 使用 camelCase（小驼峰命名）：`userName`
- 常量使用 UPPER_CASE：`MAX_RETRY_COUNT`
- 私有变量以下划线开头：`_privateVariable`
- 布尔变量以 `is`、`has`、`can` 开头：`isLoading`

### 方法命名
- 使用 camelCase：`getUserInfo()`
- 返回布尔值的方法以 `is`、`has`、`can` 开头：`isValidEmail()`
- 设置方法以 `set` 开头：`setUserName()`
- 获取方法以 `get` 开头：`getUserName()`

### 参数命名
- 使用 camelCase：`userName`
- 可选参数使用方括号：`[String? userName]`
- 命名参数使用花括号：`{required String userName}`

## 📝 代码格式

### 缩进和空格
- 使用 2 个空格缩进
- 不使用制表符（Tab）
- 运算符前后添加空格：`a + b`
- 逗号后添加空格：`a, b, c`
- 冒号后添加空格：`key: value`

### 行长度
- 每行不超过 80 个字符
- 超长行在适当位置换行
- 换行时保持 2 个空格缩进

### 空行
- 类、方法之间使用一个空行
- 逻辑块之间使用一个空行
- 相关代码块之间不使用空行

## 📖 注释规范

### 文件注释
```dart
/// 服务管理器
/// 
/// 负责管理应用中所有服务的生命周期，包括注册、初始化、销毁等操作。
/// 提供服务状态监控和错误处理机制。
/// 
/// 使用示例：
/// ```dart
/// final serviceManager = ServiceManager();
/// await serviceManager.initialize();
/// ```
class ServiceManager {
  // ...
}
```

### 类注释
```dart
/// 基础服务接口
/// 
/// 所有服务都应该实现此接口，确保统一的生命周期管理。
abstract class BaseService {
  /// 服务名称
  String get name;
  
  /// 初始化服务
  Future<void> initialize();
}
```

### 方法注释
```dart
/// 发送消息到指定设备
/// 
/// [deviceId] 目标设备ID
/// [message] 要发送的消息内容
/// 
/// 返回发送结果，包含成功/失败状态和相关信息
/// 
/// 抛出 [NetworkException] 当网络连接失败时
/// 抛出 [DeviceNotFoundException] 当目标设备不存在时
Future<Result<bool>> sendMessage(
  String deviceId,
  String message,
) async {
  // 实现
}
```

### 行内注释
```dart
// 检查网络连接状态
final bool isConnected = await _checkConnection();

// 如果连接失败，抛出异常
if (!isConnected) {
  throw NetworkException('网络连接失败');
}
```

## 🎨 UI 组件规范

### 组件命名
- 使用描述性名称：`UserAvatarButton`
- 组件类名以组件类型结尾：`UserAvatarButton`、`UserAvatarCard`
- 私有组件以下划线开头：`_UserAvatarButton`

### 组件结构
```dart
class UserAvatarButton extends StatelessWidget {
  const UserAvatarButton({
    super.key,
    required this.userId,
    this.size = 48.0,
    this.onTap,
  });

  final String userId;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colorScheme.primary,
        ),
        child: _buildAvatar(),
      ),
    );
  }

  Widget _buildAvatar() {
    // 实现
  }
}
```

### 布局规范
- 使用 `const` 构造函数优化性能
- 合理使用 `Expanded`、`Flexible` 和 `Spacer`
- 优先使用 `Column` 和 `Row` 而不是嵌套的 `Container`
- 使用 `SizedBox` 替代 `Container` 作为间距

## 🛠️ 异步编程规范

### Future 使用
```dart
// ✅ 正确：使用 async/await
Future<String> getUserData() async {
  final response = await _api.getUser();
  return response.data;
}

// ✅ 正确：错误处理
Future<String> getUserData() async {
  try {
    final response = await _api.getUser();
    return response.data;
  } catch (error) {
    _logger.error('获取用户数据失败', error);
    rethrow;
  }
}

// ❌ 错误：忽略错误处理
Future<String> getUserData() async {
  final response = await _api.getUser(); // 没有错误处理
  return response.data;
}
```

### Stream 使用
```dart
// ✅ 正确：使用 StreamController
class MessageService {
  final _messageController = StreamController<String>.broadcast();
  
  Stream<String> get messageStream => _messageController.stream;
  
  void sendMessage(String message) {
    _messageController.add(message);
  }
  
  void dispose() {
    _messageController.close();
  }
}

// ✅ 正确：使用 StreamBuilder
StreamBuilder<String>(
  stream: messageService.messageStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return Text(snapshot.data!);
    }
    return const CircularProgressIndicator();
  },
)
```

## 🎯 错误处理规范

### 异常类型
```dart
// 自定义异常类型
class NetworkException extends AppException {
  const NetworkException(String message) : super(message);
}

class ValidationException extends AppException {
  const ValidationException(String message) : super(message);
}
```

### 错误处理模式
```dart
// ✅ 正确：使用 Result 类型
Future<Result<User>> getUser(String userId) async {
  try {
    final user = await _api.getUser(userId);
    return Result.success(user);
  } catch (error) {
    return Result.failure('获取用户失败: $error');
  }
}

// ✅ 正确：使用 try-catch
Future<void> sendMessage(String message) async {
  try {
    await _networkService.send(message);
  } on NetworkException catch (error) {
    _showErrorSnackBar('网络错误: ${error.message}');
  } catch (error) {
    _logger.error('发送消息失败', error);
    _showErrorSnackBar('发送失败');
  }
}
```

## 📊 状态管理规范

### StatefulWidget 使用
```dart
class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  List<User> _users = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    // 清理资源
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _userService.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_error != null) {
      return Text('错误: $_error');
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        return UserTile(user: _users[index]);
      },
    );
  }
}
```

## 🔧 性能优化规范

### Widget 优化
```dart
// ✅ 正确：使用 const 构造函数
const Text('Hello World')
const EdgeInsets.all(16.0)
const Icon(Icons.add)

// ✅ 正确：使用 const 类
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user});
  
  final User user;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(user.name),
            Text(user.email),
          ],
        ),
      ),
    );
  }
}

// ✅ 正确：使用 RepaintBoundary
RepaintBoundary(
  child: ComplexWidget(),
)
```

### 列表优化
```dart
// ✅ 正确：使用 ListView.builder
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ItemWidget(item: items[index]);
  },
)

// ✅ 正确：使用 AutomaticKeepAliveClientMixin
class ItemWidget extends StatefulWidget {
  const ItemWidget({super.key, required this.item});
  
  final Item item;
  
  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text(widget.item.name);
  }
}
```

## 🧪 测试规范

### 单元测试
```dart
// test/services/user_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:udp_control/services/user_service.dart';

void main() {
  group('UserService', () {
    late UserService userService;
    late MockApi mockApi;

    setUp(() {
      mockApi = MockApi();
      userService = UserService(api: mockApi);
    });

    test('should return user when API call succeeds', () async {
      // Arrange
      const userId = '123';
      const expectedUser = User(id: userId, name: 'Test User');
      when(mockApi.getUser(userId)).thenAnswer((_) async => expectedUser);

      // Act
      final result = await userService.getUser(userId);

      // Assert
      expect(result.isSuccess, true);
      expect(result.data, expectedUser);
      verify(mockApi.getUser(userId)).called(1);
    });

    test('should return failure when API call fails', () async {
      // Arrange
      const userId = '123';
      when(mockApi.getUser(userId)).thenThrow(Exception('API Error'));

      // Act
      final result = await userService.getUser(userId);

      // Assert
      expect(result.isFailure, true);
      expect(result.error, contains('API Error'));
    });
  });
}
```

### Widget 测试
```dart
// test/widgets/user_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udp_control/widgets/user_card.dart';

void main() {
  group('UserCard', () {
    testWidgets('should display user name and email', (tester) async {
      // Arrange
      const user = User(id: '123', name: 'Test User', email: 'test@example.com');

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserCard(user: user),
          ),
        ),
      );

      // Assert
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      // Arrange
      const user = User(id: '123', name: 'Test User');
      bool wasTapped = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserCard(
              user: user,
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(UserCard));
      await tester.pump();

      // Assert
      expect(wasTapped, true);
    });
  });
}
```

## 📚 文档规范

### README 文件
```markdown
# 项目名称

## 概述
简要描述项目功能和用途。

## 特性
- 特性1
- 特性2
- 特性3

## 安装
```bash
flutter pub get
```

## 使用
```dart
import 'package:your_package/your_package.dart';
```

## API 文档
详细的 API 文档链接。

## 示例
提供使用示例。

## 贡献
贡献指南。

## 许可证
许可证信息。
```

### API 文档
```dart
/// 用户服务
/// 
/// 提供用户相关的业务逻辑，包括获取用户信息、更新用户资料等功能。
/// 
/// ## 使用示例
/// 
/// ```dart
/// final userService = UserService();
/// final result = await userService.getUser('123');
/// 
/// if (result.isSuccess) {
///   print('用户名: ${result.data.name}');
/// } else {
///   print('错误: ${result.error}');
/// }
/// ```
class UserService {
  /// 获取用户信息
  /// 
  /// [userId] 用户ID，不能为空
  /// 
  /// 返回 [Result<User>] 包含用户信息或错误信息
  /// 
  /// ## 示例
  /// 
  /// ```dart
  /// final result = await userService.getUser('123');
  /// if (result.isSuccess) {
  ///   print(result.data.name);
  /// }
  /// ```
  /// 
  /// ## 异常
  /// 
  /// 抛出 [ArgumentException] 当 userId 为空时
  /// 抛出 [NetworkException] 当网络连接失败时
  Future<Result<User>> getUser(String userId) async {
    // 实现
  }
}
```

## 🔍 代码审查清单

### 功能性
- [ ] 代码实现了所有需求功能
- [ ] 边界条件处理正确
- [ ] 错误处理完整
- [ ] 性能符合要求

### 可读性
- [ ] 命名清晰有意义
- [ ] 注释完整准确
- [ ] 代码结构清晰
- [ ] 复杂逻辑有说明

### 可维护性
- [ ] 遵循项目规范
- [ ] 模块化程度高
- [ ] 耦合度低
- [ ] 易于扩展

### 测试
- [ ] 单元测试覆盖率高
- [ ] 集成测试完整
- [ ] 边界测试充分
- [ ] 性能测试通过

## 🚀 最佳实践

### 1. 使用类型安全
```dart
// ✅ 正确：使用强类型
List<String> names = ['Alice', 'Bob'];
Map<String, int> ages = {'Alice': 25, 'Bob': 30};

// ❌ 错误：使用 dynamic
List names = ['Alice', 'Bob'];
Map ages = {'Alice': 25, 'Bob': 30};
```

### 2. 优先使用组合而非继承
```dart
// ✅ 正确：使用组合
class UserService {
  final ApiClient _apiClient;
  final CacheManager _cacheManager;
  
  UserService(this._apiClient, this._cacheManager);
}

// ❌ 错误：过度使用继承
class UserService extends ApiClient {
  // 不必要的继承
}
```

### 3. 使用依赖注入
```dart
// ✅ 正确：使用依赖注入
class UserPage extends StatelessWidget {
  const UserPage({super.key, required this.userService});
  
  final UserService userService;
}

// ❌ 错误：硬编码依赖
class UserPage extends StatelessWidget {
  final UserService _userService = UserService(); // 硬编码
}
```

### 4. 遵循单一职责原则
```dart
// ✅ 正确：单一职责
class UserService {
  Future<User> getUser(String id) async => /* 只负责获取用户 */;
}

class UserValidator {
  bool isValidEmail(String email) => /* 只负责验证 */;
}

// ❌ 错误：多重职责
class UserService {
  Future<User> getUser(String id) async => /* 获取用户 */;
  bool isValidEmail(String email) => /* 验证邮箱 */;
  void sendEmail(String to, String message) => /* 发送邮件 */;
}
```

### 5. 使用常量而非魔法数字
```dart
// ✅ 正确：使用常量
class AppConstants {
  static const int maxRetryCount = 3;
  static const Duration timeout = Duration(seconds: 30);
}

// 使用常量
for (int i = 0; i < AppConstants.maxRetryCount; i++) {
  // ...
}

// ❌ 错误：魔法数字
for (int i = 0; i < 3; i++) { // 3 是什么意思？
  // ...
}
```

## 📋 总结

遵循本代码风格指南可以确保代码质量、提高开发效率、降低维护成本。所有开发者都应该熟悉并严格遵守这些规范。

记住：
- 代码是写给人看的，顺便给机器执行
- 一致的风格比个人偏好更重要
- 好的代码不需要注释，但复杂的逻辑需要解释
- 测试是代码质量的保障
- 重构是持续改进的过程

让我们一起编写优雅、高效、可维护的 Flutter 代码！
