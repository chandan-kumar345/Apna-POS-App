import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final db = DatabaseService();

  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _taxController;

  @override
  void initState() {
    super.initState();
    final rest = db.restaurant;
    _nameController = TextEditingController(text: rest?.name ?? '');
    _taglineController = TextEditingController(text: rest?.tagline ?? '');
    _phoneController = TextEditingController(text: rest?.phone ?? '');
    _addressController = TextEditingController(text: rest?.address ?? '');
    _taxController = TextEditingController(text: rest?.taxRate.toString() ?? '5.0');
  }

  Future<void> _saveSettings() async {
    final updated = (db.restaurant ?? RestaurantModel(
      id: 'rest_001',
      name: '',
      tagline: '',
      phone: '',
      address: '',
      cuisineType: 'Indian',
    )).copyWith(
      name: _nameController.text.trim(),
      tagline: _taglineController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      taxRate: double.tryParse(_taxController.text) ?? 5.0,
    );

    await db.updateRestaurantProfile(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restaurant profile settings updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;

          Widget configSection = GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            blurStrength: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restaurant Outlet Configuration',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Update business name, receipt details, and tax rules',
                  style: TextStyle(fontSize: 12, color: GlassTheme.textMedium),
                ),
                const SizedBox(height: 18),

                GlassTextField(controller: _nameController, labelText: 'Restaurant Outlet Name', hintText: 'Apna POS Diner'),
                const SizedBox(height: 12),
                GlassTextField(controller: _taglineController, labelText: 'Slogan / Receipt Header Tagline', hintText: 'Taste the Perfection'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: GlassTextField(controller: _phoneController, labelText: 'Contact Phone', hintText: '+91 98765 43210')),
                    const SizedBox(width: 12),
                    Expanded(child: GlassTextField(controller: _taxController, labelText: 'GST / Tax Rate (%)', hintText: '5.0', keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                GlassTextField(controller: _addressController, labelText: 'Restaurant Address', hintText: 'Connaught Place, New Delhi', maxLines: 2),

                const SizedBox(height: 20),
                GlassButton(
                  label: 'Save Profile Settings',
                  icon: Icons.save_rounded,
                  height: 44,
                  onPressed: _saveSettings,
                ),
              ],
            ),
          );

          Widget dbHealthSection = GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            blurStrength: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Database Health & Storage',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                _buildDbStatRow('Engine Type', 'Dart Persistent Local Storage'),
                _buildDbStatRow('Menu Records', '${db.menuItems.length} Dishes'),
                _buildDbStatRow('Tables Registered', '${db.tables.length} Tables'),
                _buildDbStatRow('Total Orders Logged', '${db.orders.length} Bills'),
                _buildDbStatRow('Inventory Items', '${db.inventoryItems.length} Raw Stock Items'),
                const SizedBox(height: 14),
                const Divider(color: GlassTheme.glassBorder),
                const SizedBox(height: 10),

                GlassButton(
                  label: 'Re-Seed Clean Demo Data',
                  icon: Icons.restart_alt_rounded,
                  isSecondary: true,
                  height: 42,
                  onPressed: () async {
                    await db.resetDatabase();
                    if (!mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Database reset & pre-seeded with fresh data!')),
                    );
                  },
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              children: [
                configSection,
                const SizedBox(height: 14),
                dbHealthSection,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: configSection),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: dbHealthSection),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildDbStatRow(String key, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: GlassTheme.textMedium, fontSize: 12)),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
