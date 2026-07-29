import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../dashboard/main_layout.dart';

class RestaurantOnboardingScreen extends StatefulWidget {
  const RestaurantOnboardingScreen({super.key});

  @override
  State<RestaurantOnboardingScreen> createState() => _RestaurantOnboardingScreenState();
}

class _RestaurantOnboardingScreenState extends State<RestaurantOnboardingScreen> {
  int _currentStep = 0;
  final db = DatabaseService();

  // Controllers
  final _nameController = TextEditingController(text: 'Apna POS Grand Diner');
  final _taglineController = TextEditingController(text: 'Delicious Food, Unmatched Speed');
  final _phoneController = TextEditingController(text: '+91 98765 43210');
  final _addressController = TextEditingController(text: '12-A Connaught Place, New Delhi');
  final _cuisineController = TextEditingController(text: 'North Indian & Multi-Cuisine');
  
  String _currencySymbol = '₹';
  final _taxController = TextEditingController(text: '5.0');
  final _tablesController = TextEditingController(text: '12');

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final rest = db.restaurant;
    if (rest != null) {
      _nameController.text = rest.name;
      _taglineController.text = rest.tagline;
      _phoneController.text = rest.phone;
      _addressController.text = rest.address;
      _cuisineController.text = rest.cuisineType;
      _currencySymbol = rest.currencySymbol;
      _taxController.text = rest.taxRate.toString();
      _tablesController.text = rest.tableCount.toString();
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final updated = RestaurantModel(
        id: db.restaurant?.id ?? 'rest_001',
        name: _nameController.text.trim(),
        tagline: _taglineController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        cuisineType: _cuisineController.text.trim(),
        currencySymbol: _currencySymbol,
        taxRate: double.tryParse(_taxController.text) ?? 5.0,
        tableCount: int.tryParse(_tablesController.text) ?? 12,
        isOnboarded: true,
      );

      await db.saveRestaurantOnboarding(updated);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Onboarding save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: GlassTheme.backgroundDecoration,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: GlassTheme.primaryCyan.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GlassTheme.primaryCyan.withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: GlassTheme.primaryCyan, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restaurant Setup Wizard',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'Configure Apna POS for your restaurant outlet',
                              style: TextStyle(fontSize: 13, color: GlassTheme.textMedium),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Progress Steps
                    Row(
                      children: [
                        _buildStepIndicator(0, 'Identity', Icons.restaurant_menu),
                        _buildStepConnector(0),
                        _buildStepIndicator(1, 'Tax & Tables', Icons.point_of_sale),
                        _buildStepConnector(1),
                        _buildStepIndicator(2, 'Launch POS', Icons.rocket_launch),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Main Step Card
                    GlassContainer(
                      padding: const EdgeInsets.all(30),
                      borderRadius: 24,
                      blurStrength: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentStep == 0) _buildStep1Identity(),
                          if (_currentStep == 1) _buildStep2TaxesAndTables(),
                          if (_currentStep == 2) _buildStep3Summary(),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_currentStep > 0)
                                GlassButton(
                                  label: 'Back',
                                  isPrimary: false,
                                  onPressed: () => setState(() => _currentStep--),
                                )
                              else
                                const SizedBox.shrink(),
                              GlassButton(
                                label: _currentStep == 2 ? 'Complete & Open Apna POS' : 'Next Step',
                                icon: _currentStep == 2 ? Icons.check_circle : Icons.arrow_forward,
                                isLoading: _isLoading,
                                onPressed: () {
                                  if (_currentStep < 2) {
                                    setState(() => _currentStep++);
                                  } else {
                                    _completeOnboarding();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    Color color = GlassTheme.textMedium;
    if (isActive) color = GlassTheme.primaryViolet;
    if (isDone) color = GlassTheme.accentNeonGreen;

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isActive ? 0.3 : 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isActive ? 2 : 1),
            ),
            child: Icon(isDone ? Icons.check : icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : GlassTheme.textMedium,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int stepIndex) {
    final isDone = _currentStep > stepIndex;
    return Container(
      width: 40,
      height: 2,
      color: isDone ? GlassTheme.accentNeonGreen : GlassTheme.glassBorder,
    );
  }

  Widget _buildStep1Identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Restaurant Basic Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'This will appear on customer bills and glass receipts',
          style: TextStyle(fontSize: 13, color: GlassTheme.textMedium),
        ),
        const SizedBox(height: 20),
        GlassTextField(
          controller: _nameController,
          labelText: 'Restaurant Name',
          hintText: 'Apna POS Diner',
          prefixIcon: Icons.store,
        ),
        const SizedBox(height: 16),
        GlassTextField(
          controller: _taglineController,
          labelText: 'Tagline / Slogan',
          hintText: 'Taste the Perfection',
          prefixIcon: Icons.bookmark_border,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GlassTextField(
                controller: _phoneController,
                labelText: 'Contact Phone',
                hintText: '+91 98765 43210',
                prefixIcon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlassTextField(
                controller: _cuisineController,
                labelText: 'Cuisine Type',
                hintText: 'Indian & Italian',
                prefixIcon: Icons.restaurant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassTextField(
          controller: _addressController,
          labelText: 'Full Address',
          hintText: '12 Connaught Place, New Delhi',
          prefixIcon: Icons.location_on_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildStep2TaxesAndTables() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Operational & Billing Setup',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Configure tax rates, table capacity, and currency settings',
          style: TextStyle(fontSize: 13, color: GlassTheme.textMedium),
        ),
        const SizedBox(height: 20),
        const Text(
          'Currency Symbol',
          style: TextStyle(color: GlassTheme.textMedium, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['₹', '\$', '€', '£', 'AED'].map((curr) {
              final isSel = _currencySymbol == curr;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(curr, style: TextStyle(color: isSel ? Colors.white : GlassTheme.textMedium, fontWeight: FontWeight.bold)),
                  selected: isSel,
                  selectedColor: GlassTheme.primaryViolet,
                  backgroundColor: GlassTheme.glassInput,
                  onSelected: (val) => setState(() => _currencySymbol = curr),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GlassTextField(
                controller: _taxController,
                labelText: 'Default Tax / GST Rate (%)',
                hintText: '5.0',
                prefixIcon: Icons.percent_rounded,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlassTextField(
                controller: _tablesController,
                labelText: 'Number of Tables',
                hintText: '12',
                prefixIcon: Icons.table_restaurant_rounded,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Summary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Confirm & Launch Apna POS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Everything is ready! We have pre-seeded starter categories and interactive floor tables for you.',
          style: TextStyle(fontSize: 13, color: GlassTheme.textMedium),
        ),
        const SizedBox(height: 20),
        GlassContainer(
          padding: const EdgeInsets.all(20),
          backgroundColor: GlassTheme.primaryViolet.withOpacity(0.12),
          borderColor: GlassTheme.primaryViolet.withOpacity(0.4),
          child: Column(
            children: [
              _buildSummaryRow('Restaurant Name', _nameController.text),
              _buildSummaryRow('Cuisine Type', _cuisineController.text),
              _buildSummaryRow('Currency & Tax', '$_currencySymbol | ${_taxController.text}% GST'),
              _buildSummaryRow('Total Floor Tables', '${_tablesController.text} Tables'),
              _buildSummaryRow('Database State', 'Configured & Persisted'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: GlassTheme.textMedium, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
