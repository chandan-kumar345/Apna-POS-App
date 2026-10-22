import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/database_service.dart';
import '../../core/services/whatsapp_chat_service.dart';

/// Clean Modern Theme for Customer Text Auto-Reply Screen matching AI settings design
class _AutoReplyTheme {
  static const Color headerNavyStart = Color(0xFF031024); // Deep Midnight Navy
  static const Color headerNavyMid = Color(0xFF072146);   // Rich Royal Navy
  static const Color headerNavyEnd = Color(0xFF0A2E5C);   // Deep Indigo Blue
  static const Color pageBackground = Color(0xFFF1F5F9);
  static const Color cardBg = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color blueBrand = Color(0xFF2563EB);
  static const Color blueLight = Color(0xFFEFF6FF);
  static const Color greenBrand = Color(0xFF16A34A);
  static const Color greenLight = Color(0xFFDCFCE7);

  static BoxDecoration get whiteCard => BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      );
}

/// Represents a configurable reply step triggered by customer keywords
class _AutoReplyStepItem {
  String id;
  String title;
  TextEditingController keywordCtrl;
  TextEditingController responseCtrl;

  _AutoReplyStepItem({
    required this.id,
    required this.title,
    required String keywords,
    required String response,
  })  : keywordCtrl = TextEditingController(text: keywords),
        responseCtrl = TextEditingController(text: response);

  void dispose() {
    keywordCtrl.dispose();
    responseCtrl.dispose();
  }

  Map<String, dynamic> toMap(int order) => {
        'id': id,
        'stepName': title,
        'triggerKeyword': keywordCtrl.text.trim(),
        'responseMessage': responseCtrl.text.trim(),
        'actionType': 'reply',
        'order': order,
      };
}

class CustomerAutoReplyScreen extends StatefulWidget {
  const CustomerAutoReplyScreen({super.key});

  @override
  State<CustomerAutoReplyScreen> createState() => _CustomerAutoReplyScreenState();
}

class _CustomerAutoReplyScreenState extends State<CustomerAutoReplyScreen> {
  final DatabaseService _db = DatabaseService();
  final WhatsAppChatService _waService = WhatsAppChatService();

  late bool _enabled;
  late TextEditingController _primaryMessageCtrl;
  final List<_AutoReplyStepItem> _steps = [];

  bool _isLoadingInitial = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initValuesFromDb();
    _loadFromBackend();
  }

  void _initValuesFromDb() {
    _enabled = _db.isAiChatAgentCustomAutoReplyEnabled;
    final savedMsg = _db.aiChatAgentCustomAutoReplyMessage;
    _primaryMessageCtrl = TextEditingController(
      text: savedMsg.isNotEmpty
          ? savedMsg
          : 'Hello {customer_name}! Thank you for messaging {restaurant_name}. How can we assist you today? To view our menu or place an order, reply "Menu" or "Hi". For inquiries, call us at {phone}.',
    );

    // Initialize multi-steps from DB or provide recommended defaults
    final savedSteps = _db.aiChatAgentCustomAutoReplySteps;
    _steps.clear();

    if (savedSteps.isNotEmpty) {
      for (int i = 0; i < savedSteps.length; i++) {
        final map = savedSteps[i];
        _steps.add(
          _AutoReplyStepItem(
            id: map['id']?.toString() ?? 'step_${DateTime.now().millisecondsSinceEpoch}_$i',
            title: map['stepName']?.toString() ?? 'Step ${i + 2}',
            keywords: map['triggerKeyword']?.toString() ?? '',
            response: map['responseMessage']?.toString() ?? '',
          ),
        );
      }
    } else {
      // Default recommended steps for restaurants
      _steps.addAll([
        _AutoReplyStepItem(
          id: 'step_timing',
          title: 'Step 2: Timings & Working Hours',
          keywords: 'timing, hours, open, close, kab khulta hai, kab band hota hai',
          response:
              'We are open every day from 10:00 AM to 11:00 PM at {restaurant_name}. Feel free to visit us or reply "Menu" to order delicious food!',
        ),
        _AutoReplyStepItem(
          id: 'step_location',
          title: 'Step 3: Location & Address',
          keywords: 'address, location, kahan hai, kahan par, directions, map',
          response:
              'We are located at: {address}. For directions or parking assistance, call us at {phone}. We look forward to serving you!',
        ),
        _AutoReplyStepItem(
          id: 'step_booking',
          title: 'Step 4: Table Booking & Reservations',
          keywords: 'table, book, reservation, seat, booking',
          response:
              'For table reservations at {restaurant_name}, please call our counter directly at {phone}. We will gladly prepare a table for your visit!',
        ),
      ]);
    }
  }

  Future<void> _loadFromBackend() async {
    setState(() => _isLoadingInitial = true);
    try {
      final backendSettings = await _waService.getAiAgentSettings();
      if (backendSettings != null && mounted) {
        setState(() {
          if (backendSettings['customAutoReplyEnabled'] != null) {
            _enabled = backendSettings['customAutoReplyEnabled'] == true;
          }
          if (backendSettings['customAutoReplyMessage'] != null &&
              backendSettings['customAutoReplyMessage'].toString().isNotEmpty) {
            _primaryMessageCtrl.text = backendSettings['customAutoReplyMessage'].toString();
          }

          final backendSteps = backendSettings['customAutoReplySteps'];
          if (backendSteps is List && backendSteps.isNotEmpty) {
            for (final s in _steps) {
              s.dispose();
            }
            _steps.clear();
            for (int i = 0; i < backendSteps.length; i++) {
              final map = backendSteps[i];
              _steps.add(
                _AutoReplyStepItem(
                  id: map['id']?.toString() ?? 'step_${DateTime.now().millisecondsSinceEpoch}_$i',
                  title: map['stepName']?.toString() ?? 'Step ${i + 2}',
                  keywords: map['triggerKeyword']?.toString() ?? '',
                  response: map['responseMessage']?.toString() ?? '',
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[CustomerAutoReplyScreen] Error loading backend settings: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  @override
  void dispose() {
    _primaryMessageCtrl.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final stepMaps = <Map<String, dynamic>>[];
    for (int i = 0; i < _steps.length; i++) {
      stepMaps.add(_steps[i].toMap(i));
    }

    await _db.saveCustomerAutoReplySettings(
      enabled: _enabled,
      message: _primaryMessageCtrl.text.trim(),
      steps: stepMaps,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Customer Auto-Reply & Steps saved and synced successfully!',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _addNewStep() {
    HapticFeedback.lightImpact();
    setState(() {
      final newIndex = _steps.length + 2;
      _steps.add(
        _AutoReplyStepItem(
          id: 'step_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Step $newIndex: Custom Reply',
          keywords: '',
          response: '',
        ),
      );
    });
  }

  void _removeStep(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      final item = _steps.removeAt(index);
      item.dispose();
    });
  }

  void _insertVariableIntoCtrl(TextEditingController ctrl, String variable) {
    HapticFeedback.selectionClick();
    final text = ctrl.text;
    final sel = ctrl.selection;
    if (sel.isValid && sel.start >= 0) {
      final newText = text.replaceRange(sel.start, sel.end, variable);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + variable.length),
      );
    } else {
      ctrl.text = text.isEmpty ? variable : '$text $variable';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = _db.restaurant?.name ?? 'Pizza 47';

    return Scaffold(
      backgroundColor: _AutoReplyTheme.pageBackground,
      resizeToAvoidBottomInset: false,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Stack(
          children: [
            // 1. Continuous Top Midnight Navy Gradient Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _AutoReplyTheme.headerNavyStart,
                      _AutoReplyTheme.headerNavyMid,
                      _AutoReplyTheme.headerNavyEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // 2. Foreground: App Bar and Curved Content Sheet
            Column(
              children: [
                _buildTopAppBar(),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _AutoReplyTheme.pageBackground,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: _isLoadingInitial
                          ? const Center(child: CircularProgressIndicator(color: _AutoReplyTheme.blueBrand))
                          : SafeArea(
                              top: false,
                              bottom: true,
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                child: Center(
                                  // Screen wrapping constraint matching AI Chat screen
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 580),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Card 1: Master Status Switch
                                        _buildMasterToggleCard(),
                                        const SizedBox(height: 12),

                                        // Card 2: Step 1 Initial Auto-Reply
                                        _buildStepOneCard(restaurantName),
                                        const SizedBox(height: 14),

                                        // Section Header for Multi-Steps
                                        Row(
                                          children: [
                                            const Icon(Icons.alt_route_rounded, size: 16, color: _AutoReplyTheme.blueBrand),
                                            const SizedBox(width: 6),
                                            const Expanded(
                                              child: Text(
                                                'CUSTOMER REPLY STEPS & KEYWORDS',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: _AutoReplyTheme.textDark,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: _addNewStep,
                                              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                              label: const Text('Add Step', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _AutoReplyTheme.blueBrand,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                elevation: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Dynamic Step Cards
                                        for (int i = 0; i < _steps.length; i++) ...[
                                          _buildStepCard(i, _steps[i], restaurantName),
                                          const SizedBox(height: 10),
                                        ],

                                        const SizedBox(height: 6),

                                        // Card 4: Real-time WhatsApp Simulator Preview
                                        _buildSimulatorPreviewCard(restaurantName),
                                        const SizedBox(height: 16),

                                        // Card 5: Save & Sync Button
                                        _buildSaveButton(),
                                        const SizedBox(height: 28),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 1. Top Header App Bar
  Widget _buildTopAppBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Customer Text Auto-Reply',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Multi-step replies according to customer messages',
                    style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _enabled ? _AutoReplyTheme.greenLight : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _enabled ? 'Active' : 'Disabled',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _enabled ? const Color(0xFF15803D) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card 1: Master Status Toggle Card
  Widget _buildMasterToggleCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _AutoReplyTheme.whiteCard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _AutoReplyTheme.blueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.quickreply_rounded, color: _AutoReplyTheme.blueBrand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Activate Customer Text Auto-Reply',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _AutoReplyTheme.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Responds automatically to WhatsApp inquiries outside food ordering.',
                  style: TextStyle(fontSize: 10, color: _AutoReplyTheme.textMuted, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.78,
            child: Switch(
              value: _enabled,
              activeTrackColor: const Color(0xFF22C55E),
              activeThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFCBD5E1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _enabled = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Card 2: Step 1 — Initial Welcome / Primary Auto-Reply
  Widget _buildStepOneCard(String restaurantName) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _AutoReplyTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _AutoReplyTheme.blueLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'STEP 1 • INITIAL AUTO-REPLY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _AutoReplyTheme.blueBrand,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _primaryMessageCtrl.text =
                        'Hello {customer_name}! Thank you for messaging {restaurant_name}. How can we assist you today? To view our menu or place an order, reply "Menu" or "Hi". For inquiries, call us at {phone}.';
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: const [
                      Icon(Icons.restart_alt_rounded, size: 12, color: _AutoReplyTheme.blueBrand),
                      SizedBox(width: 3),
                      Text('Default', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _AutoReplyTheme.blueBrand)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Sent immediately when a customer initiates a general chat. Guide them on available options, menu, or details.',
            style: TextStyle(fontSize: 10, color: _AutoReplyTheme.textMuted, height: 1.25),
          ),
          const SizedBox(height: 10),

          // Template Variables Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildVariableChip('{restaurant_name}', _primaryMessageCtrl),
              _buildVariableChip('{customer_name}', _primaryMessageCtrl),
              _buildVariableChip('{phone}', _primaryMessageCtrl),
              _buildVariableChip('{address}', _primaryMessageCtrl),
            ],
          ),
          const SizedBox(height: 8),

          // Multi-line Text Field
          TextField(
            controller: _primaryMessageCtrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 11.5, color: _AutoReplyTheme.textDark),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter Step 1 initial auto-reply message...',
              hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _AutoReplyTheme.blueBrand, width: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  // Card 3: Single Follow-Up Step Card
  Widget _buildStepCard(int index, _AutoReplyStepItem step, String restaurantName) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _AutoReplyTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header & Delete Button
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 2}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _AutoReplyTheme.textDark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _AutoReplyTheme.textDark),
                ),
              ),
              InkWell(
                onTap: () => _removeStep(index),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Trigger Keywords Input
          const Text(
            'When Customer Replies With (Keywords separated by comma):',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: step.keywordCtrl,
            style: const TextStyle(fontSize: 11, color: _AutoReplyTheme.textDark),
            decoration: InputDecoration(
              hintText: 'e.g. 1, timing, hours, open, close',
              hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _AutoReplyTheme.blueBrand, width: 1.1)),
            ),
          ),
          const SizedBox(height: 10),

          // Response Text & Variables
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Auto-Reply Message for this Step:',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              Text(
                'Tap variable to insert',
                style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _buildVariableChip('{restaurant_name}', step.responseCtrl, isMini: true),
              _buildVariableChip('{customer_name}', step.responseCtrl, isMini: true),
              _buildVariableChip('{phone}', step.responseCtrl, isMini: true),
              _buildVariableChip('{address}', step.responseCtrl, isMini: true),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: step.responseCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 11, color: _AutoReplyTheme.textDark),
            decoration: InputDecoration(
              hintText: 'Enter reply sent when customer texts matching keywords...',
              hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _AutoReplyTheme.blueBrand, width: 1.1)),
            ),
          ),
        ],
      ),
    );
  }

  // Card 4: WhatsApp Conversation Simulation Preview
  Widget _buildSimulatorPreviewCard(String restaurantName) {
    final samplePhone = _db.restaurant?.phone ?? '+91 9709593705';
    final sampleAddress = _db.restaurant?.address ?? 'Main Road, City Center';

    final step1Text = _primaryMessageCtrl.text
        .replaceAll('{restaurant_name}', restaurantName)
        .replaceAll('{customer_name}', 'Rahul')
        .replaceAll('{phone}', samplePhone)
        .replaceAll('{address}', sampleAddress);

    final firstStep = _steps.isNotEmpty ? _steps.first : null;
    final step2Trigger = firstStep != null && firstStep.keywordCtrl.text.isNotEmpty
        ? firstStep.keywordCtrl.text.split(',').first.trim()
        : 'Timing?';
    final step2Reply = firstStep != null && firstStep.responseCtrl.text.isNotEmpty
        ? firstStep.responseCtrl.text
            .replaceAll('{restaurant_name}', restaurantName)
            .replaceAll('{customer_name}', 'Rahul')
            .replaceAll('{phone}', samplePhone)
            .replaceAll('{address}', sampleAddress)
        : 'We are open daily 10 AM to 11 PM!';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.remove_red_eye_outlined, size: 13, color: Color(0xFF64748B)),
              SizedBox(width: 5),
              Text(
                'Live WhatsApp Multi-Step Flow Preview',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // User 1: "Hi"
          _buildChatBubble('Namaste!', isUser: true),
          const SizedBox(height: 4),

          // Assistant 1: Step 1
          _buildChatBubble(step1Text, isUser: false),
          const SizedBox(height: 6),

          // User 2: Customer reply
          _buildChatBubble(step2Trigger, isUser: true),
          const SizedBox(height: 4),

          // Assistant 2: Step 2
          _buildChatBubble(step2Reply, isUser: false),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, {required bool isUser}) {
    final screenW = MediaQuery.of(context).size.width;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: screenW * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFE7FFDB) : const Color(0xFFDCF8C6),
          borderRadius: BorderRadius.only(
            topLeft: isUser ? const Radius.circular(10) : Radius.zero,
            topRight: isUser ? Radius.zero : const Radius.circular(10),
            bottomLeft: const Radius.circular(10),
            bottomRight: const Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF111827), height: 1.25),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUser ? '10:45 AM' : '10:45 AM',
                  style: const TextStyle(fontSize: 8, color: Color(0xFF6B7280)),
                ),
                if (isUser) ...[
                  const SizedBox(width: 2.5),
                  const Icon(Icons.done_all_rounded, size: 10, color: Color(0xFF3B82F6)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Card 5: Bottom Save & Sync Button
  Widget _buildSaveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _AutoReplyTheme.headerNavyStart,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      onPressed: _isSaving ? null : _handleSave,
      child: _isSaving
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.save_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Save & Sync Multi-Step Auto-Replies',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
    );
  }

  Widget _buildVariableChip(String variable, TextEditingController ctrl, {bool isMini = false}) {
    return InkWell(
      onTap: () => _insertVariableIntoCtrl(ctrl, variable),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMini ? 5 : 7, vertical: isMini ? 2 : 3),
        decoration: BoxDecoration(
          color: _AutoReplyTheme.blueLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: isMini ? 9 : 11, color: const Color(0xFF1D4ED8)),
            const SizedBox(width: 2),
            Text(
              variable,
              style: TextStyle(fontSize: isMini ? 8.5 : 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
            ),
          ],
        ),
      ),
    );
  }
}
