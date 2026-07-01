import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models/subscription.dart';
import 'providers/subscription_provider.dart';
import 'data/subscription_icons.dart';
import 'services/notification_service.dart';          
import 'services/notification_permission_handler.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SubscriptionProvider()..loadSubscriptions(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subscription Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

// ==================== НАВИГАЦИЯ ====================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? const SubscriptionScreen()
          : const SettingsScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Главная"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Настройки"),
        ],
      ),
    );
  }
}

// ==================== ГЛАВНЫЙ ЭКРАН ====================

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int? _activeMenuId; // ID подписки, у которой сейчас открыто меню

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        final active = provider.activeSubscriptions;
        final inactive =
            provider.subscriptions.where((s) => !s.isActive).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Подписки"),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text("Создать"),
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: "Активные"),
                  Tab(text: "Неактивные"),
                ],
              ),
            ),
            // ✅ ДОБАВЛЕНО: Содержимое для вкладок
            body: Stack(
              children: [
                TabBarView(
                  children: [
                    _buildList(provider, active),
                    _buildList(provider, inactive),
                  ],
                ),
                if (_activeMenuId != null) _buildFloatingMenu(provider),
              ],
            ),
            // ✅ ДОБАВЛЕНО: Кнопка закрытия меню
            floatingActionButton: _activeMenuId != null
                ? FloatingActionButton(
                    onPressed: () => setState(() => _activeMenuId = null),
                    child: const Icon(Icons.close),
                  )
                : null,
          ),
        );
      },
    );
  }

  // Меню с кнопками
  Widget _buildFloatingMenu(SubscriptionProvider provider) {
    final sub = provider.subscriptions
        .where((s) => s.id == _activeMenuId)
        .firstOrNull;

    if (sub == null) return const SizedBox();

    return Positioned(
      right: 16,
      bottom: 80,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            _menuButton(Icons.calendar_month, Colors.green, "Продлить", () {
              provider.updateSubscription(sub.pay());
              setState(() => _activeMenuId = null);
            }),
            _menuButton(
              sub.isActive ? Icons.pause : Icons.play_arrow,
              Colors.orange,
              "Статус",
              () {
                provider.updateSubscription(
                    sub.copyWith(isActive: !sub.isActive));
                setState(() => _activeMenuId = null);
              },
            ),
            _menuButton(Icons.edit, Colors.blue, "Изменить", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AddSubscriptionScreen(subscription: sub)),
              );
              setState(() => _activeMenuId = null);
            }),
            _menuButton(Icons.delete_forever, Colors.red, "Удалить", () {
              provider.deleteSubscription(sub.id!);
              setState(() => _activeMenuId = null);
            }),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FloatingActionButton.small(
        heroTag: label,
        backgroundColor: color,
        onPressed: onTap,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  
  Widget _buildList(SubscriptionProvider provider, List<Subscription> list) {
    if (list.isEmpty) {
      return const Center(child: Text("Список пуст", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        final bool hasIcon = s.iconPath != null && s.iconPath!.isNotEmpty;

        return Dismissible(
          key: Key(s.id.toString()), // Ключ важен для работы свайпа
          direction: DismissDirection.endToStart, // Свайп только справа налево
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => provider.deleteSubscription(s.id!),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                child: hasIcon
                    ? Padding(padding: const EdgeInsets.all(6.0), child: Image.asset(s.iconPath!))
                    : Icon(Icons.subscriptions, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    "Списание: ${DateFormat('dd.MM.yyyy').format(s.nextBillingDate)}",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Индикатор цены и цикла
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${s.price.toStringAsFixed(0)} ${s.currency}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Кнопка меню
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => setState(() => _activeMenuId = s.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
// ==================== ЭКРАН ДОБАВЛЕНИЯ/РЕДАКТИРОВАНИЯ ====================

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? subscription; // null = добавление

  const AddSubscriptionScreen({super.key, this.subscription});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;

  String? _selectedIconPath;
  String _selectedCategory = 'Видео';
  BillingCycle _selectedCycle = BillingCycle.monthly;
  DateTime _selectedDate = DateTime.now(); // ✅ это дата СЛЕДУЮЩЕГО списания

  final List<String> _categories = [
    'Видео',
    'Музыка',
    'Игры',
    'Софт',
    'Другое'
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.subscription?.name ?? '');
    _priceController = TextEditingController(
      text: widget.subscription?.price.toString() ?? '',
    );
    _selectedCategory = widget.subscription?.category ?? 'Видео';
    _selectedCycle = widget.subscription?.cycle ?? BillingCycle.monthly;
    
    // ✅ ИСПРАВЛЕНО: при редактировании берём nextBillingDate, при создании - сегодня
    _selectedDate = widget.subscription?.nextBillingDate ?? DateTime.now();
    _selectedIconPath = widget.subscription?.iconPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickIcon() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Выберите иконку',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: SubscriptionIcons.all.length,
                    itemBuilder: (context, index) {
                      final path = SubscriptionIcons.all[index];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, path),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: _selectedIconPath == path
                                ? Border.all(color: Colors.blue, width: 2)
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(path),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedIconPath = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subscription != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Редактировать" : "Добавить")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: InkWell(
                onTap: _pickIcon,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: (_selectedIconPath != null &&
                                _selectedIconPath!.isNotEmpty)
                            ? Image.asset(_selectedIconPath!)
                            : Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedIconPath == null
                            ? "Нажмите для выбора"
                            : "Иконка выбрана",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Название сервиса",
                hintText: "Netflix, Spotify...",
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Цена",
                hintText: "500",
                border: OutlineInputBorder(),
                suffixText: '₽',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Введите цену';
                if (double.tryParse(value) == null) return 'Введите число';
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: "Категория",
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<BillingCycle>(
              value: _selectedCycle,
              decoration: const InputDecoration(
                labelText: "Период оплаты",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: BillingCycle.weekly, child: Text('Еженедельно')),
                DropdownMenuItem(
                    value: BillingCycle.monthly, child: Text('Ежемесячно')),
                DropdownMenuItem(
                    value: BillingCycle.yearly, child: Text('Ежегодно')),
              ],
              onChanged: (val) => setState(() => _selectedCycle = val!),
            ),
            const SizedBox(height: 16),

            // ✅ ИЗМЕНЕНО: теперь это дата СЛЕДУЮЩЕГО списания
            ListTile(
              title: Text(
                  "Дата следующего списания: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(
                  isEditing ? "Сохранить изменения" : "Добавить подписку"),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    final price = double.parse(_priceController.text);

    if (widget.subscription != null) {
      // ✅ Редактирование: сохраняем ID и startDate
      final old = widget.subscription!;
      final updated = old.copyWith(
        name: _nameController.text,
        price: price,
        category: _selectedCategory,
        cycle: _selectedCycle,
        nextBillingDate: _selectedDate, // пользователь может изменить
        iconPath: _selectedIconPath,
      );
      provider.updateSubscription(updated);
    } else {
      // ✅ Создание: startDate = сегодня, nextBillingDate = выбранная дата
      final newSub = Subscription(
        name: _nameController.text,
        price: price,
        currency: '₽',
        cycle: _selectedCycle,
        startDate: DateTime.now(),
        nextBillingDate: _selectedDate,
        category: _selectedCategory,
        iconPath: _selectedIconPath,
      );
      provider.addSubscription(newSub);
    }

    Navigator.pop(context);
  }
}
// ==================== ЭКРАН НАСТРОЕК ====================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Настройки")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Consumer<SubscriptionProvider>(
              builder: (context, provider, child) {
                return Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          "Всего подписок: ${provider.subscriptions.length}",
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Траты в месяц: ${provider.totalMonthlySpending.toStringAsFixed(0)} ₽",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // ✅ КНОПКА УДАЛЕНИЯ (уже была)
            ElevatedButton.icon(
              onPressed: () => _showClearDialog(context),
              icon: const Icon(Icons.delete_forever),
              label: const Text("Удалить все подписки"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ✅ НОВАЯ КНОПКА ДЛЯ ТЕСТОВОГО УВЕДОМЛЕНИЯ
            ElevatedButton.icon(
              onPressed: () => _sendTestNotification(context),
              icon: const Icon(Icons.notifications_active),
              label: const Text("Отправить тестовое уведомление"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ МЕТОД ДЛЯ ОТПРАВКИ ТЕСТОВОГО УВЕДОМЛЕНИЯ
  void _sendTestNotification(BuildContext context) async {
  // 1. Проверяем, есть ли уже разрешение
  final hasPermission = await NotificationPermissionHandler.checkPermission();

  if (!hasPermission) {
    // 2. Если разрешения нет — показываем объясняющий диалог
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications, color: Colors.blue),
            SizedBox(width: 8),
            Text('Разрешить уведомления?'),
          ],
        ),
        content: const Text(
          'SubQ будет отправлять напоминания за 24 часа до оплаты подписок, '
          'чтобы вы не пропустили платежи и избежали неожиданных списаний.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Разрешить'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    // 3. Запрашиваем системное разрешение
    final granted = await NotificationPermissionHandler.requestPermission();

    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Уведомления отключены. Вы можете включить их в настройках устройства.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
  }

  // 4. Разрешение есть — отправляем уведомление СРАЗУ
  final notificationService = NotificationService();
  await notificationService.sendNotification(
    title: '🔔 Напоминание о подписке',
    body: 'Через 24 часа будет списание за Netflix (500 ₽)',
    payload: 'test_notification',
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Тестовое уведомление отправлено!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить все подписки?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<SubscriptionProvider>(context,
                  listen: false);
              for (final sub in provider.subscriptions) {
                await provider.deleteSubscription(sub.id!);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Удалить все',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}