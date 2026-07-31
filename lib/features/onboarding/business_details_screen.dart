import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../dashboard/main_layout.dart';
import 'choose_business_category_screen.dart';
import 'add_business_address_screen.dart';

class CurrencyItem {
  final String symbol;
  final String code;
  final String name;
  final String flag;

  const CurrencyItem({
    required this.symbol,
    required this.code,
    required this.name,
    required this.flag,
  });

  String get displayName => '$code($symbol) - $name';
}

const List<CurrencyItem> allWorldCurrencies = [
  CurrencyItem(symbol: '₹', code: 'INR', name: 'India', flag: '🇮🇳'),
  CurrencyItem(symbol: '\$', code: 'USD', name: 'United States', flag: '🇺🇸'),
  CurrencyItem(symbol: '€', code: 'EUR', name: 'Eurozone (Europe)', flag: '🇪🇺'),
  CurrencyItem(symbol: '£', code: 'GBP', name: 'United Kingdom', flag: '🇬🇧'),
  CurrencyItem(symbol: 'د.إ', code: 'AED', name: 'United Arab Emirates', flag: '🇦🇪'),
  CurrencyItem(symbol: 'C\$', code: 'CAD', name: 'Canada', flag: '🇨🇦'),
  CurrencyItem(symbol: 'A\$', code: 'AUD', name: 'Australia', flag: '🇦🇺'),
  CurrencyItem(symbol: '¥', code: 'JPY', name: 'Japan', flag: '🇯🇵'),
  CurrencyItem(symbol: 'S\$', code: 'SGD', name: 'Singapore', flag: '🇸🇬'),
  CurrencyItem(symbol: '¥', code: 'CNY', name: 'China', flag: '🇨🇳'),
  CurrencyItem(symbol: '﷼', code: 'SAR', name: 'Saudi Arabia', flag: '🇸🇦'),
  CurrencyItem(symbol: '﷼', code: 'QAR', name: 'Qatar', flag: '🇶🇦'),
  CurrencyItem(symbol: '﷼', code: 'OMR', name: 'Oman', flag: '🇴🇲'),
  CurrencyItem(symbol: 'د.ك', code: 'KWD', name: 'Kuwait', flag: '🇰🇼'),
  CurrencyItem(symbol: 'د.ب', code: 'BHD', name: 'Bahrain', flag: '🇧🇭'),
  CurrencyItem(symbol: 'NZ\$', code: 'NZD', name: 'New Zealand', flag: '🇳🇿'),
  CurrencyItem(symbol: 'CHF', code: 'CHF', name: 'Switzerland', flag: '🇨🇭'),
  CurrencyItem(symbol: 'RM', code: 'MYR', name: 'Malaysia', flag: '🇲🇾'),
  CurrencyItem(symbol: '฿', code: 'THB', name: 'Thailand', flag: '🇹🇭'),
  CurrencyItem(symbol: 'Rp', code: 'IDR', name: 'Indonesia', flag: '🇮🇩'),
  CurrencyItem(symbol: '🇵🇭', code: 'PHP', name: 'Philippines', flag: '🇵🇭'),
  CurrencyItem(symbol: 'kr', code: 'SEK', name: 'Sweden', flag: '🇸🇪'),
  CurrencyItem(symbol: 'kr', code: 'NOK', name: 'Norway', flag: '🇳🇴'),
  CurrencyItem(symbol: 'kr', code: 'DKK', name: 'Denmark', flag: '🇩🇰'),
  CurrencyItem(symbol: 'R\$', code: 'BRL', name: 'Brazil', flag: '🇧🇷'),
  CurrencyItem(symbol: 'R', code: 'ZAR', name: 'South Africa', flag: '🇿🇦'),
  CurrencyItem(symbol: '₩', code: 'KRW', name: 'South Korea', flag: '🇰🇷'),
  CurrencyItem(symbol: '₫', code: 'VND', name: 'Vietnam', flag: '🇻🇳'),
  CurrencyItem(symbol: 'Rs', code: 'PKR', name: 'Pakistan', flag: '🇵🇰'),
  CurrencyItem(symbol: 'Tk', code: 'BDT', name: 'Bangladesh', flag: '🇧🇩'),
  CurrencyItem(symbol: 'Rs', code: 'LKR', name: 'Sri Lanka', flag: '🇱🇰'),
  CurrencyItem(symbol: 'रू', code: 'NPR', name: 'Nepal', flag: '🇳🇵'),
];

class TimeZoneItem {
  final String offset;
  final String region;
  final String flag;

  const TimeZoneItem({
    required this.offset,
    required this.region,
    required this.flag,
  });

  String get displayName => '($offset) $region';
}

const List<TimeZoneItem> allWorldTimeZones = [
  TimeZoneItem(offset: 'UTC+05:30', region: 'India Standard Time (IST) - India', flag: '🇮🇳'),
  TimeZoneItem(offset: 'UTC-05:00', region: 'Eastern Time (US & Canada)', flag: '🇺🇸'),
  TimeZoneItem(offset: 'UTC-06:00', region: 'Central Time (US & Canada)', flag: '🇺🇸'),
  TimeZoneItem(offset: 'UTC-07:00', region: 'Mountain Time (US & Canada)', flag: '🇺🇸'),
  TimeZoneItem(offset: 'UTC-08:00', region: 'Pacific Time (US & Canada)', flag: '🇺🇸'),
  TimeZoneItem(offset: 'UTC-09:00', region: 'Alaska Time (US)', flag: '🇺🇸'),
  TimeZoneItem(offset: 'UTC-10:00', region: 'Hawaii-Aleutian Time (US)', flag: '🇺🇸'),
  TimeZoneItem(offset: 'UTC-05:00', region: 'Indiana (East) - US', flag: '🇺🇸'),
  TimeZoneItem(offset: 'UTC+00:00', region: 'Greenwich Mean Time (GMT) - UK', flag: '🇬🇧'),
  TimeZoneItem(offset: 'UTC+01:00', region: 'Central European Time (CET) - Europe', flag: '🇪🇺'),
  TimeZoneItem(offset: 'UTC+04:00', region: 'Gulf Standard Time (GST) - UAE & Oman', flag: '🇦🇪'),
  TimeZoneItem(offset: 'UTC+03:00', region: 'Arabia Standard Time (AST) - Saudi Arabia', flag: '🇸🇦'),
  TimeZoneItem(offset: 'UTC+08:00', region: 'Singapore Standard Time (SST) - Singapore', flag: '🇸🇬'),
  TimeZoneItem(offset: 'UTC+08:00', region: 'China Standard Time (CST) - China', flag: '🇨🇳'),
  TimeZoneItem(offset: 'UTC+09:00', region: 'Japan Standard Time (JST) - Japan', flag: '🇯🇵'),
  TimeZoneItem(offset: 'UTC+10:00', region: 'Australian Eastern Time (AEST) - Sydney', flag: '🇦🇺'),
  TimeZoneItem(offset: 'UTC+12:00', region: 'New Zealand Standard Time (NZST) - Auckland', flag: '🇳🇿'),
  TimeZoneItem(offset: 'UTC+05:00', region: 'Pakistan Standard Time (PKT) - Pakistan', flag: '🇵🇰'),
  TimeZoneItem(offset: 'UTC+06:00', region: 'Bangladesh Standard Time (BST) - Bangladesh', flag: '🇧🇩'),
  TimeZoneItem(offset: 'UTC+05:45', region: 'Nepal Time (NPT) - Nepal', flag: '🇳🇵'),
  TimeZoneItem(offset: 'UTC+07:00', region: 'Indochina Time (ICT) - Thailand & Vietnam', flag: '🇹🇭'),
];

class BusinessDetailsScreen extends StatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  final db = DatabaseService();

  late TextEditingController _countryController;
  late TextEditingController _phoneController;

  CurrencyItem _selectedCurrency = allWorldCurrencies[0];
  TimeZoneItem _selectedTimeZone = allWorldTimeZones[0];

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final phone = db.currentUser?.phone ?? '9899636369';
    final cleanPhone = phone.replaceAll(RegExp(r'^\+\d+\s*'), '');

    _countryController = TextEditingController(text: 'India');
    _phoneController = TextEditingController(
        text: cleanPhone.isNotEmpty ? cleanPhone : '9899636369');
  }

  @override
  void dispose() {
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Currency Selection Search Popup Modal
  void _showCurrencySelectionPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allWorldCurrencies.where((c) {
              final q = query.toLowerCase();
              return c.displayName.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q) ||
                  c.name.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Currency',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Field
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setModalState(() => query = val),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              hintText: 'Search currency or country...',
                              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = _selectedCurrency.code == item.code;
                        return ListTile(
                          leading: Text(item.flag, style: const TextStyle(fontSize: 24)),
                          title: Text(
                            '${item.code} (${item.symbol})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            item.name,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00C2FF), size: 22)
                              : null,
                          onTap: () {
                            setState(() => _selectedCurrency = item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Country Time Zone Selection Search Popup Modal
  void _showTimeZoneSelectionPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allWorldTimeZones.where((tz) {
              final q = query.toLowerCase();
              return tz.displayName.toLowerCase().contains(q) ||
                  tz.offset.toLowerCase().contains(q) ||
                  tz.region.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Country Time Zone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Field
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setModalState(() => query = val),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              hintText: 'Search time zone or country...',
                              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = _selectedTimeZone.displayName == item.displayName;
                        return ListTile(
                          leading: Text(item.flag, style: const TextStyle(fontSize: 24)),
                          title: Text(
                            item.displayName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00C2FF), size: 22)
                              : null,
                          onTap: () {
                            setState(() => _selectedTimeZone = item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSaveAndComplete() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final businessName = db.restaurant?.name ??
          db.currentUser?.companyName ??
          'Tea Coffee';

      final updated = RestaurantModel(
        id: db.restaurant?.id ?? 'rest_001',
        name: businessName,
        tagline: 'Authentic Flavors & Swift Service',
        phone: '+91 ${_phoneController.text.trim()}',
        address: '12-A Connaught Place, New Delhi',
        cuisineType: 'Multi-Cuisine POS',
        currencySymbol: _selectedCurrency.symbol,
        taxRate: 5.0,
        tableCount: 12,
        isOnboarded: true,
      );

      await db.saveRestaurantOnboarding(updated);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF00C2FF), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Business details for "$businessName" saved successfully!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Open Choose Business Category Screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChooseBusinessCategoryScreen()),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Error saving details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessTitle = db.restaurant?.name ??
        db.currentUser?.companyName ??
        'Tea Coffee';

    return Scaffold(
      body: Stack(
        children: [
          // 1. Deep Midnight Background Gradient with Glass Ambient Glows
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.4),
                  radius: 1.25,
                  colors: [
                    Color(0x550052FF), // Logo Electric Blue Ambient Glow
                    Color(0xFF071126),
                    Color(0xFF03060F),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 2. Glassmorphism Orbs / Ambient Light Orbs
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00C2FF).withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C2FF).withOpacity(0.18),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 160,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F46E5).withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 3. Main Screen Layout
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Glass Header with Back Button and Business Name Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          businessTitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. White Bottom Curved Card Container matching Auth Theme
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 30,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error Banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFFCA5A5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded,
                                            color: Color(0xFFEF4444), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: Color(0xFFB91C1C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // 1. Country Name Field
                                const Text(
                                  'Country name',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(26), // Stadium Semi-Circle Pill Shape
                                    border: Border.all(
                                      color: const Color(0xFF00C2FF), // Highlighted Cyan border
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1400C2FF),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _countryController,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A), // Crisp High-Contrast Black
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'India',
                                            hintStyle: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFFCBD5E1),
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // 2. Business Mobile Number Field
                                const Text(
                                  'Business mobile number',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(26), // Stadium Semi-Circle Pill Shape
                                    border: Border.all(
                                      color: const Color(0xFF00C2FF), // Highlighted Cyan border
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1400C2FF),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'IN +91',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Container(
                                        height: 20,
                                        width: 1,
                                        margin: const EdgeInsets.symmetric(horizontal: 10),
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A), // Crisp High-Contrast Black
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: '9899636369',
                                            hintStyle: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFFCBD5E1),
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // 3. Currency Type Field (Opens Currency Popup Search Modal)
                                const Text(
                                  'Currency Type',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                InkWell(
                                  onTap: _showCurrencySelectionPopup,
                                  borderRadius: BorderRadius.circular(26),
                                  child: Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(26), // Stadium Semi-Circle Pill Shape
                                      border: Border.all(
                                        color: const Color(0xFF00C2FF), // Highlighted Cyan border
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1400C2FF),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Selected Currency Single Chip with High Contrast Black Text
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Text(
                                            _selectedCurrency.displayName,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A), // Crisp High Contrast Black
                                            ),
                                          ),
                                        ),

                                        const Spacer(),

                                        // Blue Plus Add Icon matching screenshot
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF0088FF),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // 4. Country Time Zone Field (Opens TimeZone Popup Search Modal)
                                const Text(
                                  'Country time zone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                InkWell(
                                  onTap: _showTimeZoneSelectionPopup,
                                  borderRadius: BorderRadius.circular(26),
                                  child: Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(26), // Stadium Semi-Circle Pill Shape
                                      border: Border.all(
                                        color: const Color(0xFF00C2FF), // Highlighted Cyan border
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1400C2FF),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedTimeZone.displayName,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A), // Crisp High Contrast Black
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: Color(0xFF00C2FF),
                                          size: 26,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 5. Primary Action Button ("Next")
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: GlassTheme.primaryButtonGradient,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x3300C2FF),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSaveAndComplete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Next',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
