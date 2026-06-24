import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models/subscription.dart';
import 'providers/subscription_provider.dart';
import 'services/icon_service.dart';
void main() {
  runApp(
    // ← Оборачиваем в Provider
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
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Настройки")
        ],
      ),
    );
  }
}

// ==================== ГЛАВНЫЙ ЭКРАН ====================

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ← Получаем данные из Provider
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        final active = provider.activeSubscriptions;
        final inactive = provider.subscriptions.where((s) => !s.isActive).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Подписки"),
              bottom: const TabBar(tabs: [
                Tab(text: "Активные"), 
                Tab(text: "Неактивные")
              ]),
            ),
            body: TabBarView(
              children: [
                _buildList(context, provider, active),
                _buildList(context, provider, inactive),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context, 
    SubscriptionProvider provider,
    List<Subscription> list,
  ) {
    if (list.isEmpty) {
      return const Center(
        child: Text("Нет подписок", style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(s.category),
              child: Text(
                s.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${s.category} • ${_getCycleText(s.cycle)}"),
            trailing: Row(
  mainAxisSize: MainAxisSize.min, // Важно: используем минимум места по горизонтали
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    Text(
      "${s.price.toStringAsFixed(0)} ${s.currency}",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
    const SizedBox(width: 8), // Отступ между ценой и кнопкой
    IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
      onPressed: () => _showDeleteDialog(context, provider, s),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(), // Убирает лишние отступы вокруг кнопки
    ),
  ],
),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => AddSubscriptionScreen(subscription: s),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getCycleText(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return 'в неделю';
      case BillingCycle.monthly:
        return 'в месяц';
      case BillingCycle.yearly:
        return 'в год';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Видео':
        return Colors.red;
      case 'Музыка':
        return Colors.green;
      case 'Игры':
        return Colors.purple;
      case 'Софт':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    SubscriptionProvider provider,
    Subscription subscription,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить подписку?'),
        content: Text('Вы уверены, что хотите удалить "${subscription.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSubscription(subscription.id!);
              Navigator.pop(dialogContext);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ==================== ЭКРАН ДОБАВЛЕНИЯ/РЕДАКТИРОВАНИЯ ====================

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? subscription;  // null = добавление, не null = редактирование
  
  const AddSubscriptionScreen({super.key, this.subscription});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  IconData? _selectedIcon; 
  String _selectedCategory = 'Видео';
  BillingCycle _selectedCycle = BillingCycle.monthly;
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = ['Видео', 'Музыка', 'Игры', 'Софт', 'Другое'];

  @override
  void initState() {
    super.initState();
    
    // Если редактируем — заполняем поля из существующей подписки
    _nameController = TextEditingController(text: widget.subscription?.name ?? '');
    _priceController = TextEditingController(
      text: widget.subscription?.price.toString() ?? '',
    );
    _selectedCategory = widget.subscription?.category ?? 'Видео';
    _selectedCycle = widget.subscription?.cycle ?? BillingCycle.monthly;
    _selectedDate = widget.subscription?.startDate ?? DateTime.now();
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
            // Название
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Название сервиса",
                hintText: "Netflix, Spotify...",
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите название';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Цена
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
                if (value == null || value.isEmpty) {
                  return 'Введите цену';
                }
                if (double.tryParse(value) == null) {
                  return 'Введите число';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // кнопка выбора картинки
            // Пример кнопки в форме
            ListTile(
              leading: Icon(_selectedIcon ?? Icons.subscriptions),
              title: Text(_selectedIcon == null ? "Выберите иконку" : "Иконка выбрана"),
               onTap: () async {
                final icon = await IconService.pickIcon(context);
                if (icon != null) {
                  setState(() => _selectedIcon = icon);
    }
  },
),
            // Категория
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: "Категория",
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value ?? 'Видео');
              },
            ),
            const SizedBox(height: 16),
            
            // Цикл оплаты
            DropdownButtonFormField<BillingCycle>(
              initialValue: _selectedCycle,
              decoration: const InputDecoration(
                labelText: "Период оплаты",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: BillingCycle.weekly, child: Text('Еженедельно')),
                DropdownMenuItem(value: BillingCycle.monthly, child: Text('Ежемесячно')),
                DropdownMenuItem(value: BillingCycle.yearly, child: Text('Ежегодно')),
              ],
              onChanged: (value) {
                setState(() => _selectedCycle = value ?? BillingCycle.monthly);
              },
            ),
            const SizedBox(height: 16),
            
            // Дата начала
            ListTile(
              title: Text(
                "Дата начала: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 32),
            
            // Кнопка сохранения
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEditing ? "Сохранить изменения" : "Добавить подписку"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
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
      // Редактирование
      final updated = widget.subscription!.copyWith(
        name: _nameController.text,
        price: price,
        category: _selectedCategory,
        cycle: _selectedCycle,
        startDate: _selectedDate,
      );
      provider.updateSubscription(updated);
    } else {
      // Добавление новой
      final newSub = Subscription(
        name: _nameController.text,
        price: price,
        currency: '₽',
        cycle: _selectedCycle,
        startDate: _selectedDate,
        category: _selectedCategory,
        // Добавляем сохранение иконки (сохраняем код иконки как строку)
        iconPath: _selectedIcon?.codePoint.toString(), 
      );
      provider.addSubscription(newSub);
    }

    Navigator.pop(context);
  }
}

// ==================== ЭКРАН НАСТРОЕК ====================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Настройки")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Общая статистика
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
            
            // Кнопка удаления всех
            ElevatedButton.icon(
              onPressed: () => _showClearDialog(context),
              icon: const Icon(Icons.delete_forever),
              label: const Text("Удалить все подписки"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
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
              final provider = Provider.of<SubscriptionProvider>(context, listen: false);
              // Удаляем все подписки
              for (final sub in provider.subscriptions) {
                await provider.deleteSubscription(sub.id!);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Удалить все', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}