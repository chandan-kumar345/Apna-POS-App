import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import 'choose_business_category_screen.dart';

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

  String get displayName => '$code ($symbol) - $name';
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
    db.saveOnboardingProgress(route: 'business_details', step: 3);
    final phone = db.currentUser?.phone ?? '9899636418';
    final cleanPhone = phone.replaceAll(RegExp(r'^\+\d+\s*'), '');

    _countryController = TextEditingController(text: 'India');
    _phoneController = TextEditingController(
      text: cleanPhone.isNotEmpty ? cleanPhone : '9899636418',
    );
  }

  @override
  void dispose() {
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Neumorphic Currency Selection Search Modal (60% screen height, compact, no cross icon)
  void _showCurrencySelectionPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.60,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33001C55),
                        blurRadius: 24,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Column(
                      children: [
                        // Top Handle Bar
                        const SizedBox(height: 10),
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title Header (Cross icon removed)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Select Currency',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 1.5),
                              Text(
                                'Choose the operating currency for billing',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Compact Neumorphic Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 1.2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08002870),
                                  blurRadius: 4,
                                  offset: Offset(1, 2),
                                ),
                                BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 4,
                                  offset: Offset(-1, -1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onChanged: (val) => setModalState(() => query = val),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Search currency or country...',
                                      hintStyle: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
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
                        ),
                        const SizedBox(height: 8),

                        // Compact Currency List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isSelected = _selectedCurrency.code == item.code;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEEF4FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.2 : 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x04002870),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedCurrency = item);
                                    Navigator.pop(context);
                                  },
                                  child: Row(
                                    children: [
                                      Text(item.flag, style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  item.code,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: isSelected ? const Color(0xFF021B54) : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(0xFF0066FF).withValues(alpha: 0.12)
                                                        : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: Text(
                                                    item.symbol,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF021B54),
                                          size: 17,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Neumorphic Country Time Zone Selection Search Modal (60% screen height, compact, no cross icon)
  void _showTimeZoneSelectionPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.60,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33001C55),
                        blurRadius: 24,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Column(
                      children: [
                        // Top Handle Bar
                        const SizedBox(height: 10),
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title Header (Cross icon removed)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Select Country Time Zone',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 1.5),
                              Text(
                                'Choose your primary business time zone',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Compact Neumorphic Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 1.2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08002870),
                                  blurRadius: 4,
                                  offset: Offset(1, 2),
                                ),
                                BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 4,
                                  offset: Offset(-1, -1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onChanged: (val) => setModalState(() => query = val),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Search time zone or country...',
                                      hintStyle: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
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
                        ),
                        const SizedBox(height: 8),

                        // Compact Time Zone List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isSelected = _selectedTimeZone.displayName == item.displayName;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEEF4FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.2 : 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x04002870),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedTimeZone = item);
                                    Navigator.pop(context);
                                  },
                                  child: Row(
                                    children: [
                                      Text(item.flag, style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF0066FF).withValues(alpha: 0.12)
                                                    : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                item.offset,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.region,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected ? const Color(0xFF021B54) : const Color(0xFF334155),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF021B54),
                                          size: 17,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
          'The Sky High';

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
          backgroundColor: const Color(0xFF021B54),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Business details for "$businessName" saved successfully!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      await db.saveOnboardingProgress(route: 'choose_category', step: 4);

      if (!mounted) return;

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
    final dynamicCompanyName = db.restaurant?.name ??
        db.currentUser?.companyName ??
        'The Sky High';

    return Scaffold(
      backgroundColor: const Color(0xFF021B54),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // 1. Top Header on Midnight Navy (Company Icon Removed)
              _buildTopHeader(dynamicCompanyName),

              // 2. Curved White Neumorphic Body Sheet with Sticky Next Button
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x25001C55),
                        blurRadius: 24,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: Column(
                      children: [
                        // Scrollable Content
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error Banner if validation fails
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFCA5A5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: Color(0xFFB91C1C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // FIELD 1: Country Name
                                const Text(
                                  'Country name',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Enter or verify your operating country',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Compact Neumorphic Country Box
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F9FD),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A002870),
                                        blurRadius: 6,
                                        offset: Offset(2, 3),
                                      ),
                                      BoxShadow(
                                        color: Colors.white,
                                        blurRadius: 6,
                                        offset: Offset(-2, -2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🇮🇳', style: TextStyle(fontSize: 19)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _countryController,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'India',
                                            hintStyle: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF94A3B8),
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

                                const SizedBox(height: 16),

                                // FIELD 2: Business Mobile Number
                                const Text(
                                  'Business mobile number',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Mobile number for customer invoices and orders',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Compact Neumorphic Phone Box
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F9FD),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A002870),
                                        blurRadius: 6,
                                        offset: Offset(2, 3),
                                      ),
                                      BoxShadow(
                                        color: Colors.white,
                                        blurRadius: 6,
                                        offset: Offset(-2, -2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🇮🇳', style: TextStyle(fontSize: 19)),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'IN +91',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Container(
                                        height: 16,
                                        width: 1.2,
                                        margin: const EdgeInsets.symmetric(horizontal: 10),
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: 0.3,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: '9899636418',
                                            hintStyle: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF94A3B8),
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

                                const SizedBox(height: 16),

                                // FIELD 3: Currency Type
                                const Text(
                                  'Currency Type',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Selected currency for billing and items pricing',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Compact Neumorphic Currency Selector Box
                                InkWell(
                                  onTap: _showCurrencySelectionPopup,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F9FD),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0A002870),
                                          blurRadius: 6,
                                          offset: Offset(2, 3),
                                        ),
                                        BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 6,
                                          offset: Offset(-2, -2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Selected Currency Chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x06002870),
                                                blurRadius: 3,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(_selectedCurrency.flag, style: const TextStyle(fontSize: 13.5)),
                                              const SizedBox(width: 5),
                                              Text(
                                                '${_selectedCurrency.code} (${_selectedCurrency.symbol}) - ${_selectedCurrency.name}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const Spacer(),

                                        // Blue Add/Change Icon Button
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF0066FF), Color(0xFF0052E0)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF0066FF).withValues(alpha: 0.3),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.add_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // FIELD 4: Country Time Zone
                                const Text(
                                  'Country time zone',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Regional timezone for orders and register shifts',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Compact Neumorphic Timezone Selector Box
                                InkWell(
                                  onTap: _showTimeZoneSelectionPopup,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 48),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F9FD),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0A002870),
                                          blurRadius: 6,
                                          offset: Offset(2, 3),
                                        ),
                                        BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 6,
                                          offset: Offset(-2, -2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Text(_selectedTimeZone.flag, style: const TextStyle(fontSize: 17)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedTimeZone.displayName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0066FF).withValues(alpha: 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Color(0xFF0066FF),
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),

                        // Sticky Bottom Action Button ("Next" - Centered, Midnight Navy, Background Removed)
                        _buildStickyBottomBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Top Midnight Navy Header with Circular Back Button and Company Name Badge (Icon Removed)
  Widget _buildTopHeader(String companyName) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF021B54),
            Color(0xFF03266B),
            Color(0xFF021B54),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Back Button and Company Name Pill Badge (Icon Removed)
              Row(
                children: [
                  // Neumorphic Frosted Circular Back Button
                  InkWell(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.88),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: Color(0xFF0F172A),
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Neumorphic Frosted Company Name Badge (Icon Removed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        companyName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Title
              const Text(
                'Business details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 5),

              // Subtitle
              const Text(
                'Set up your country, phone number, and billing currency',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sticky Bottom Action Bar with Centered Midnight Navy "Next" Button (Background Removed)
  Widget _buildStickyBottomBar() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF021B54),
                Color(0xFF002B7A),
                Color(0xFF003D9E),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30021B54),
                blurRadius: 12,
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
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Center(
                    child: Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
