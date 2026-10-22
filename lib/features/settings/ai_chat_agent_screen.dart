import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/database_service.dart';
import '../../core/services/whatsapp_chat_service.dart';
import 'customer_auto_reply_screen.dart';

/// Clean Modern Theme for AI Chat Agent Screen matching reference design
class _AiTheme {
  static const Color headerNavyStart = Color(0xFF031024); // Deep Midnight Navy (from POS screen)
  static const Color headerNavyMid = Color(0xFF072146);   // Rich Royal Navy (from POS screen)
  static const Color headerNavyEnd = Color(0xFF0A2E5C);   // Deep Indigo Blue (from POS screen)
  static const Color pageBackground = Color(0xFFF1F5F9);
  static const Color cardBg = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color purpleBrand = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFFEDE9FE);
  static const Color greenBrand = Color(0xFF16A34A);
  static const Color greenLight = Color(0xFFDCFCE7);
  static const Color waGreen = Color(0xFF25D366);
  static const Color waGreenLight = Color(0xFFE8F8EE);

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

class AiChatAgentScreen extends StatefulWidget {
  const AiChatAgentScreen({super.key});

  @override
  State<AiChatAgentScreen> createState() => _AiChatAgentScreenState();
}

class _AiChatAgentScreenState extends State<AiChatAgentScreen> {
  final DatabaseService _db = DatabaseService();
  final WhatsAppChatService _waService = WhatsAppChatService();

  late bool _isEnabled;
  late String _persona;
  late String _model;
  late int _delaySeconds;
  late bool _autoMenuSuggest;
  late bool _autoOrderTaking;
  late bool _customAutoReplyEnabled;

  late TextEditingController _agentNameCtrl;
  late TextEditingController _greetingCtrl;
  late TextEditingController _promptCtrl;
  late TextEditingController _houseRulesCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _customAutoReplyCtrl;

  bool _obscureApiKey = true;
  bool _showCustomApiKey = false;
  bool _isSaving = false;
  bool _isLoadingInitial = false;

  // Meta WhatsApp Connection Status
  bool _isMetaConnected = false;
  String _metaPhoneId = '';
  String _metaPhoneNumber = '';

  // Simulator State
  final TextEditingController _simInputCtrl = TextEditingController();
  final ScrollController _simScrollCtrl = ScrollController();
  final List<Map<String, String>> _simMessages = [];
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _initValuesFromDb();
    _loadFromBackend();
  }

  void _initValuesFromDb() {
    _isEnabled = _db.isAiChatAgentEnabled;
    _persona = _db.aiChatAgentPersona;
    _model = _db.aiChatAgentModel;
    _delaySeconds = _db.aiChatAgentAutoReplyDelay;
    _autoMenuSuggest = _db.isAiChatAgentAutoMenuSuggest;
    _autoOrderTaking = _db.isAiChatAgentAutoOrderTaking;
    _customAutoReplyEnabled = _db.isAiChatAgentCustomAutoReplyEnabled;

    _agentNameCtrl = TextEditingController(text: _db.aiChatAgentName);
    _greetingCtrl = TextEditingController(text: _db.aiChatAgentGreeting);
    _promptCtrl = TextEditingController(text: _db.aiChatAgentSystemPrompt);
    _houseRulesCtrl = TextEditingController(text: _db.aiChatAgentCustomInstructions);
    _apiKeyCtrl = TextEditingController(text: _db.aiChatAgentApiKey);
    final savedCustomMsg = _db.aiChatAgentCustomAutoReplyMessage;
    _customAutoReplyCtrl = TextEditingController(
      text: savedCustomMsg.isNotEmpty
          ? savedCustomMsg
          : 'Hello {customer_name}! Thank you for messaging {restaurant_name}. How can we assist you today? To view our menu or place an order, simply reply with "Menu" or "Hi". For inquiries or table bookings, call us at {phone}.',
    );
    _showCustomApiKey = _apiKeyCtrl.text.trim().isNotEmpty;

    _isMetaConnected = _db.isWhatsAppIntegrationEnabled && _db.whatsAppPhoneId.isNotEmpty;
    _metaPhoneId = _db.whatsAppPhoneId;
    _metaPhoneNumber = _db.whatsAppPhoneNumber;

    final rName = _db.restaurant?.name ?? 'Our Restaurant';
    _simMessages.add({
      'role': 'assistant',
      'text': _greetingCtrl.text.replaceAll('{restaurant_name}', rName).replaceAll('{customer_name}', 'Guest'),
    });
  }

  /// Load settings directly from backend MongoDB
  Future<void> _loadFromBackend() async {
    setState(() => _isLoadingInitial = true);
    try {
      // 1. Fetch live Meta connection status
      final connInfo = await _waService.getConnectionStatus();
      if (mounted && connInfo != null) {
        setState(() {
          _isMetaConnected = connInfo.connected || (_db.isWhatsAppIntegrationEnabled && _db.whatsAppPhoneId.isNotEmpty);
          _metaPhoneId = connInfo.phoneNumberId.isNotEmpty ? connInfo.phoneNumberId : _db.whatsAppPhoneId;
          _metaPhoneNumber = connInfo.phoneNumber.isNotEmpty ? connInfo.phoneNumber : _db.whatsAppPhoneNumber;
        });
      }

      // 2. Fetch business AI settings directly from database
      final backendSettings = await _waService.getAiAgentSettings();
      if (backendSettings != null && mounted) {
        setState(() {
          if (backendSettings['enabled'] != null) {
            _isEnabled = backendSettings['enabled'] == true;
          }
          if (backendSettings['persona'] != null && backendSettings['persona'].toString().isNotEmpty) {
            _persona = backendSettings['persona'].toString();
          }
          if (backendSettings['model'] != null && backendSettings['model'].toString().isNotEmpty) {
            _model = backendSettings['model'].toString();
          }
          if (backendSettings['autoReplyDelaySeconds'] != null) {
            _delaySeconds = (backendSettings['autoReplyDelaySeconds'] as num).toInt();
          }
          if (backendSettings['autoMenuSuggest'] != null) {
            _autoMenuSuggest = backendSettings['autoMenuSuggest'] == true;
          }
          if (backendSettings['autoOrderTaking'] != null) {
            _autoOrderTaking = backendSettings['autoOrderTaking'] == true;
          }

          if (backendSettings['agentName'] != null) {
            _agentNameCtrl.text = backendSettings['agentName'].toString();
          }
          if (backendSettings['greeting'] != null) {
            _greetingCtrl.text = backendSettings['greeting'].toString();
          }
          if (backendSettings['systemPrompt'] != null) {
            _promptCtrl.text = backendSettings['systemPrompt'].toString();
          }
          if (backendSettings['customInstructions'] != null) {
            _houseRulesCtrl.text = backendSettings['customInstructions'].toString();
          }
          if (backendSettings['customAutoReplyEnabled'] != null) {
            _customAutoReplyEnabled = backendSettings['customAutoReplyEnabled'] == true;
          }
          if (backendSettings['customAutoReplyMessage'] != null && backendSettings['customAutoReplyMessage'].toString().isNotEmpty) {
            _customAutoReplyCtrl.text = backendSettings['customAutoReplyMessage'].toString();
          }
          if (backendSettings['apiKey'] != null) {
            _apiKeyCtrl.text = backendSettings['apiKey'].toString();
            if (_apiKeyCtrl.text.isNotEmpty) _showCustomApiKey = true;
          }
        });

        await _db.saveAiChatAgentSettings(
          enabled: _isEnabled,
          persona: _persona,
          greeting: _greetingCtrl.text,
          autoMenuSuggest: _autoMenuSuggest,
          autoOrderTaking: _autoOrderTaking,
          systemPrompt: _promptCtrl.text,
          apiKey: _apiKeyCtrl.text,
          agentName: _agentNameCtrl.text,
          model: _model,
          customInstructions: _houseRulesCtrl.text,
          customAutoReplyEnabled: _customAutoReplyEnabled,
          customAutoReplyMessage: _customAutoReplyCtrl.text.trim(),
          autoReplyDelay: _delaySeconds,
        );
      }
    } catch (e) {
      debugPrint('[AiChatAgentScreen] Error loading backend AI settings: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  @override
  void dispose() {
    _agentNameCtrl.dispose();
    _greetingCtrl.dispose();
    _promptCtrl.dispose();
    _houseRulesCtrl.dispose();
    _apiKeyCtrl.dispose();
    _customAutoReplyCtrl.dispose();
    _simInputCtrl.dispose();
    _simScrollCtrl.dispose();
    super.dispose();
  }

  /// Save settings locally and synchronize to backend
  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    await _db.saveAiChatAgentSettings(
      enabled: _isEnabled,
      persona: _persona,
      greeting: _greetingCtrl.text,
      autoMenuSuggest: _autoMenuSuggest,
      autoOrderTaking: _autoOrderTaking,
      systemPrompt: _promptCtrl.text,
      apiKey: _apiKeyCtrl.text,
      agentName: _agentNameCtrl.text,
      model: _model,
      customInstructions: _houseRulesCtrl.text,
      customAutoReplyEnabled: _customAutoReplyEnabled,
      customAutoReplyMessage: _customAutoReplyCtrl.text.trim(),
      autoReplyDelay: _delaySeconds,
    );

    final success = await _waService.updateAiAgentSettings({
      'enabled': _isEnabled,
      'persona': _persona.trim(),
      'agentName': _agentNameCtrl.text.trim(),
      'greeting': _greetingCtrl.text.trim(),
      'autoMenuSuggest': _autoMenuSuggest,
      'autoOrderTaking': _autoOrderTaking,
      'systemPrompt': _promptCtrl.text.trim(),
      'customInstructions': _houseRulesCtrl.text.trim(),
      'customAutoReplyEnabled': _customAutoReplyEnabled,
      'customAutoReplyMessage': _customAutoReplyCtrl.text.trim(),
      'model': _model.trim(),
      'autoReplyDelaySeconds': _delaySeconds,
      'apiKey': _apiKeyCtrl.text.trim(),
    });

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: success ? const Color(0xFF10B981) : Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  success
                      ? 'AI Agent settings saved and synced to database!'
                      : 'Saved locally. Backend will sync on connection.',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showMetaConnectDialog() {
    final phoneIdCtrl = TextEditingController(text: _metaPhoneId);
    final phoneNumCtrl = TextEditingController(text: _metaPhoneNumber);
    final tokenCtrl = TextEditingController(text: _db.whatsAppAccessToken);
    bool isSavingMeta = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.hub_rounded, color: Color(0xFF25D366), size: 20),
              SizedBox(width: 8),
              Text('Connect Meta WhatsApp API',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your Meta Cloud API credentials to link your WhatsApp Business number:',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                _buildDialogField('Phone Number ID *', phoneIdCtrl, 'e.g. 1284061438133660'),
                const SizedBox(height: 10),
                _buildDialogField('WhatsApp Business Number', phoneNumCtrl, 'e.g. +91 9709593705'),
                const SizedBox(height: 10),
                _buildDialogField('Permanent Access Token *', tokenCtrl, 'Permanent Meta System Token', isPassword: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: isSavingMeta
                  ? null
                  : () async {
                      if (phoneIdCtrl.text.trim().isEmpty || tokenCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone Number ID and Access Token are required.')),
                        );
                        return;
                      }
                      setDlgState(() => isSavingMeta = true);
                      try {
                        await _waService.saveConnection(
                          phoneNumberId: phoneIdCtrl.text.trim(),
                          phoneNumber: phoneNumCtrl.text.trim(),
                          accessToken: tokenCtrl.text.trim(),
                        );
                        await _db.saveWhatsAppIntegrationSettings(
                          enabled: true,
                          provider: 'meta_cloud',
                          phoneNumber: phoneNumCtrl.text.trim(),
                          phoneId: phoneIdCtrl.text.trim(),
                          wabaId: _db.whatsAppWabaId,
                          accessToken: tokenCtrl.text.trim(),
                          webhookToken: _db.whatsAppWebhookToken,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          setState(() {
                            _isMetaConnected = true;
                            _metaPhoneId = phoneIdCtrl.text.trim();
                            _metaPhoneNumber = phoneNumCtrl.text.trim();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF0F172A),
                              content: Text('Meta WhatsApp API Connected Successfully! AI Agent is active.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Connection failed: $e')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDlgState(() => isSavingMeta = false);
                      }
                    },
              child: isSavingMeta
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Connect & Activate', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, String hint, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: isPassword,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          ),
        ),
      ],
    );
  }

  Future<void> _sendSimulationMessage(String userText) async {
    if (userText.trim().isEmpty || _isSimulating) return;

    final trimmed = userText.trim();
    _simInputCtrl.clear();

    setState(() {
      _simMessages.add({'role': 'user', 'text': trimmed});
      _isSimulating = true;
    });

    _scrollSimToBottom();

    try {
      final overrideSettings = {
        'enabled': true,
        'persona': _persona,
        'agentName': _agentNameCtrl.text,
        'greeting': _greetingCtrl.text,
        'autoMenuSuggest': _autoMenuSuggest,
        'autoOrderTaking': _autoOrderTaking,
        'systemPrompt': _promptCtrl.text,
        'customInstructions': _houseRulesCtrl.text,
        'customAutoReplyEnabled': _customAutoReplyEnabled,
        'customAutoReplyMessage': _customAutoReplyCtrl.text.trim(),
        'apiKey': _apiKeyCtrl.text,
        'model': _model,
      };

      final response = await _waService.simulateAiChat(trimmed, overrideSettings);
      final replyText = response?['replyText']?.toString() ??
          "Namaste! I have received your request for: \"$trimmed\". How else can I assist you today? 😊";

      if (mounted) {
        setState(() {
          _simMessages.add({'role': 'assistant', 'text': replyText});
          _isSimulating = false;
        });
        _scrollSimToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _simMessages.add({
            'role': 'assistant',
            'text': "Namaste! I received your inquiry about '$trimmed'. Our team will be happy to assist you! 🍽️",
          });
          _isSimulating = false;
        });
        _scrollSimToBottom();
      }
    }
  }

  void _scrollSimToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_simScrollCtrl.hasClients) {
        _simScrollCtrl.animateTo(
          _simScrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = _db.restaurant?.name ?? 'Pizza 47';

    return Scaffold(
      backgroundColor: _AiTheme.pageBackground,
      resizeToAvoidBottomInset: false,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Stack(
          children: [
            // 1. Continuous Top Midnight Navy Gradient (covers header & behind curved corners)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _AiTheme.headerNavyStart, // Deep Midnight Navy
                      _AiTheme.headerNavyMid,   // Rich Royal Navy
                      _AiTheme.headerNavyEnd,   // Deep Indigo Blue
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
                // Top Header Bar
                _buildTopAppBar(restaurantName),

                // Curved Sheet Container with Rounded Top Corners (No black edge)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _AiTheme.pageBackground,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: _isLoadingInitial
                          ? const Center(child: CircularProgressIndicator(color: _AiTheme.purpleBrand))
                          : SafeArea(
                              top: false,
                              bottom: true,
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                child: Center(
                                  // Screen wrapping constraint for neat, responsive cards
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 580),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Card 1: Meta Cloud API Connected & Autonomous AI Auto-Reply
                                        _buildMetaStatusAndMasterCard(),
                                        const SizedBox(height: 12),

                                        // Card 2: DIRECT ORDER TAKING IN CHAT
                                        _buildOrderTakingCard(),
                                        const SizedBox(height: 12),

                                        // Card 2B: CUSTOMER TEXT AUTO-REPLY MESSAGE
                                        _buildCustomerAutoReplyCard(),
                                        const SizedBox(height: 12),

                                        // Card 3: IDENTITY & GREETING
                                        _buildIdentityCard(),
                                        const SizedBox(height: 12),

                                        // Card 4: CONVERSATIONAL PERSONA
                                        _buildPersonaCard(),
                                        const SizedBox(height: 12),

                                        // Card 5: KITCHEN & HOUSE RULES
                                        _buildHouseRulesCard(),
                                        const SizedBox(height: 12),

                                        // Card 6: AI ENGINE & SPEED
                                        _buildEngineCard(),
                                        const SizedBox(height: 12),

                                        // Card 7: LIVE WHATSAPP SIMULATOR
                                        _buildSimulatorCard(),
                                        const SizedBox(height: 16),

                                        // Card 8: Save & Sync Button
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

  // 1. Top Header Bar (Matching the POS Screen palette)
  Widget _buildTopAppBar(String restaurantName) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Row(
          children: [
            // Circular Back Button
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.0),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'AI Chat Agent Settings',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$restaurantName • WhatsApp POS Assistant',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Standby / Online Status Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isEnabled ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isEnabled ? 'Online' : 'Standby',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card 1: Meta Cloud API Connected & Autonomous AI Auto-Reply (Compact & Managed Spacing)
  Widget _buildMetaStatusAndMasterCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _AiTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: WhatsApp Icon + Connection Status + Verified Pill
          Row(
            children: [
              // Compact WhatsApp Square Icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _AiTheme.waGreenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: _AiTheme.waGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isMetaConnected ? 'Meta Cloud API Connected' : 'Meta API Not Linked',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _AiTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _isMetaConnected
                          ? (_metaPhoneId.isNotEmpty ? 'Phone ID: $_metaPhoneId' : (_metaPhoneNumber.isNotEmpty ? _metaPhoneNumber : 'Connected'))
                          : 'Tap to configure WhatsApp Business credentials',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _AiTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Verified Pill Badge (or Connect)
              InkWell(
                onTap: _showMetaConnectDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: _isMetaConnected ? _AiTheme.greenLight : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isMetaConnected ? Icons.check_circle_rounded : Icons.link_rounded,
                        size: 11.5,
                        color: _isMetaConnected ? _AiTheme.greenBrand : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        _isMetaConnected ? 'Verified' : 'Connect',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _isMetaConnected ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 0.8),
          const SizedBox(height: 10),

          // Row 2: Activate Autonomous AI Auto-Reply Switch
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Activate Autonomous AI Auto-Reply',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _AiTheme.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AI responds to incoming customer chats instantly on your WhatsApp Business number.',
                      style: TextStyle(
                        fontSize: 10,
                        color: _AiTheme.textMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: _isEnabled,
                  activeTrackColor: const Color(0xFF22C55E),
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCBD5E1),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    setState(() => _isEnabled = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 2: DIRECT ORDER TAKING IN CHAT (Compact & Managed Spacing)
  Widget _buildOrderTakingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _AiTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Store Icon + Title on 1 line + POS Active Badge
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _AiTheme.greenLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.storefront_rounded, color: _AiTheme.greenBrand, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'DIRECT ORDER TAKING IN CHAT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _AiTheme.textDark,
                    letterSpacing: 0.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _AiTheme.greenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, size: 5.5, color: _AiTheme.greenBrand),
                    SizedBox(width: 3.5),
                    Text(
                      'POS Active',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'When customers text food/beverage orders on WhatsApp, the AI automatically detects menu dishes, calculates the bill, creates a pending POS Order, and alerts your counter in real time.',
            style: TextStyle(
              fontSize: 10,
              color: _AiTheme.textMuted,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          // Two side-by-side compact sub-cards (NO ICONS, ZERO WASTED SPACE, NO TRUNCATION)
          Row(
            children: [
              // Sub-card 1: Auto-Create POS Order
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCFCE7), width: 1.0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Auto-Create POS Order',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _AiTheme.textDark,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              softWrap: true,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Take orders from chat.',
                              style: TextStyle(
                                fontSize: 8.5,
                                color: _AiTheme.textMuted,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Transform.scale(
                        scale: 0.70,
                        alignment: Alignment.centerRight,
                        child: Switch(
                          value: _autoOrderTaking,
                          activeTrackColor: const Color(0xFF22C55E),
                          activeThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            setState(() => _autoOrderTaking = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sub-card 2: Suggest Bestsellers
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF3E8FF), width: 1.0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Suggest Bestsellers',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _AiTheme.textDark,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              softWrap: true,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Recommend top items.',
                              style: TextStyle(
                                fontSize: 8.5,
                                color: _AiTheme.textMuted,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Transform.scale(
                        scale: 0.70,
                        alignment: Alignment.centerRight,
                        child: Switch(
                          value: _autoMenuSuggest,
                          activeTrackColor: const Color(0xFF22C55E),
                          activeThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            setState(() => _autoMenuSuggest = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 2B: CUSTOMER TEXT AUTO-REPLY MESSAGE (Opens dedicated multi-step screen)
  Widget _buildCustomerAutoReplyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _AiTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + Status Badge
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.quickreply_rounded, color: Color(0xFF2563EB), size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CUSTOMER AUTO-REPLY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _AiTheme.textDark,
                    letterSpacing: 0.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _customAutoReplyEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 5.5,
                      color: _customAutoReplyEnabled ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      _customAutoReplyEnabled ? 'Active' : 'Disabled',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _customAutoReplyEnabled ? const Color(0xFF15803D) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Set up automated multi-step responses for customer inquiries, timing, address, and table reservations outside food orders.',
            style: TextStyle(
              fontSize: 10,
              color: _AiTheme.textMuted,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          // Tappable action sub-card
          InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerAutoReplyScreen()),
              );
              if (mounted) {
                setState(() {
                  _customAutoReplyEnabled = _db.isAiChatAgentCustomAutoReplyEnabled;
                  _customAutoReplyCtrl.text = _db.aiChatAgentCustomAutoReplyMessage;
                });
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Configure Multi-Step Replies',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A8A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.70,
                    alignment: Alignment.centerRight,
                    child: Switch(
                      value: _customAutoReplyEnabled,
                      activeTrackColor: const Color(0xFF22C55E),
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) async {
                        HapticFeedback.lightImpact();
                        setState(() => _customAutoReplyEnabled = val);
                        await _db.saveCustomerAutoReplySettings(
                          enabled: val,
                          message: _customAutoReplyCtrl.text.trim(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 3: IDENTITY & GREETING (Matching the uploaded image)
  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _AiTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _AiTheme.purpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, color: _AiTheme.purpleBrand, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'IDENTITY & GREETING',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _AiTheme.textDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Assistant Display Name
          const Text(
            'Assistant Display Name',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _AiTheme.textDark),
          ),
          const SizedBox(height: 6),
          _buildStyledInputField(_agentNameCtrl, 'e.g. Apna AI Assistant'),
          const SizedBox(height: 14),

          // Welcome Greeting Template & { } Variables Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Welcome Greeting Template',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _AiTheme.textDark),
              ),
              // Variables Popup Pill Button
              PopupMenuButton<String>(
                tooltip: 'Insert template variable',
                onSelected: (val) {
                  final text = _greetingCtrl.text;
                  _greetingCtrl.text = '$text $val';
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: '{restaurant_name}',
                    child: Text('{restaurant_name} (Restaurant Name)', style: TextStyle(fontSize: 11)),
                  ),
                  const PopupMenuItem(
                    value: '{customer_name}',
                    child: Text('{customer_name} (Customer Name)', style: TextStyle(fontSize: 11)),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: _AiTheme.purpleLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('{ }', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _AiTheme.purpleBrand)),
                      SizedBox(width: 4),
                      Text('Variables', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _AiTheme.purpleBrand)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildStyledInputField(
            _greetingCtrl,
            'Namaste {customer_name}! Welcome to {restaurant_name}. How can I assist you today? You can ask for our menu recommendations, today\'s special offers, or table bookings!',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // Card 4: CONVERSATIONAL PERSONA (Matching the uploaded image)
  Widget _buildPersonaCard() {
    final personas = [
      {'id': 'friendly', 'label': 'Friendly', 'icon': Icons.sentiment_satisfied_alt_rounded, 'desc': 'Warm & courteous'},
      {'id': 'hinglish', 'label': 'Hinglish', 'icon': Icons.chat_bubble_outline_rounded, 'desc': 'Desi Hindi + English'},
      {'id': 'professional', 'label': 'Executive', 'icon': Icons.business_center_rounded, 'desc': 'Crisp & formal'},
      {'id': 'chef', 'label': 'Chef Host', 'icon': Icons.restaurant_menu_rounded, 'desc': 'Foodie & specials'},
      {'id': 'sales', 'label': 'Sales Pro', 'icon': Icons.campaign_rounded, 'desc': 'Combos & offers'},
      {'id': 'casual', 'label': 'Casual', 'icon': Icons.coffee_rounded, 'desc': 'Chill & friendly'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _AiTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _AiTheme.purpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: _AiTheme.purpleBrand, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'CONVERSATIONAL PERSONA',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _AiTheme.textDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Two-Column Grid of Persona options matching the image
          Column(
            children: [
              for (int i = 0; i < personas.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: _buildPersonaTile(personas[i])),
                      const SizedBox(width: 10),
                      if (i + 1 < personas.length)
                        Expanded(child: _buildPersonaTile(personas[i + 1]))
                      else
                        const Spacer(),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaTile(Map<String, dynamic> p) {
    final isSelected = _persona == p['id'];
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _persona = p['id'] as String);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _AiTheme.purpleBrand : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Persona Circle Icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _AiTheme.purpleBrand : const Color(0xFFE2E8F0),
              ),
              child: Icon(
                p['icon'] as IconData,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
            // Label only (description removed)
            Expanded(
              child: Text(
                p['label'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? _AiTheme.purpleBrand : _AiTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Trailing Checked / Radio Icon
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? _AiTheme.purpleBrand : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }

  // Card 5: KITCHEN & HOUSE RULES
  Widget _buildHouseRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _AiTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'KITCHEN & HOUSE RULES',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _AiTheme.textDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Custom Instructions for AI',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _AiTheme.textDark),
          ),
          const SizedBox(height: 6),
          _buildStyledInputField(
            _houseRulesCtrl,
            'e.g. Pure veg kitchen. Kitchen closes at 11 PM. Delivery above ₹200 free within 5 km.',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // Card 6: AI ENGINE & SPEED
  Widget _buildEngineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _AiTheme.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.memory_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI ENGINE & SPEED',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _AiTheme.textDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Google Gemini 2.0 Flash Engine',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _AiTheme.textDark)),
                    SizedBox(height: 1),
                    Text('Platform-wide server AI included • No merchant key required',
                        style: TextStyle(fontSize: 10, color: _AiTheme.greenBrand, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _AiTheme.greenLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Included ✅',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reply Delay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Auto-Reply Delay',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _AiTheme.textDark)),
              Row(
                children: [1, 2, 3, 5].map((s) {
                  final isSel = _delaySeconds == s;
                  return GestureDetector(
                    onTap: () => setState(() => _delaySeconds = s),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isSel ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '${s}s',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Optional Custom API Key Accordion
          InkWell(
            onTap: () => setState(() => _showCustomApiKey = !_showCustomApiKey),
            child: Row(
              children: [
                Icon(_showCustomApiKey ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    size: 16, color: _AiTheme.purpleBrand),
                const SizedBox(width: 4),
                const Text('Custom Gemini API Key (Optional)',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _AiTheme.purpleBrand)),
              ],
            ),
          ),
          if (_showCustomApiKey) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: _obscureApiKey,
              style: const TextStyle(fontSize: 11, color: _AiTheme.textDark),
              decoration: InputDecoration(
                hintText: 'Leave empty to use default platform AI',
                hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility, size: 14, color: Colors.grey),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Card 7: LIVE WHATSAPP SIMULATOR
  Widget _buildSimulatorCard() {
    final sampleChips = [
      {'label': '📜 Menu', 'msg': 'Show full menu'},
      {'label': '👨‍🍳 Specials', 'msg': 'What are today\'s chef specials?'},
      {'label': '🥗 Pure Veg', 'msg': 'Show pure veg options'},
      {'label': '☕ Order Food', 'msg': 'I want to order 2 Chai and 1 Samosa'},
      {'label': '🪑 Book Table', 'msg': 'Book a table for 4 tonight at 8 PM'},
      {'label': '⏰ Timings', 'msg': 'What are your opening hours?'},
    ];

    return Container(
      decoration: _AiTheme.whiteCard,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // WhatsApp Green Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: const Color(0xFF075E54),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Live WhatsApp Chat Simulator',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _simMessages.clear();
                      final rName = _db.restaurant?.name ?? 'Our Restaurant';
                      _simMessages.add({
                        'role': 'assistant',
                        'text': _greetingCtrl.text.replaceAll('{restaurant_name}', rName).replaceAll('{customer_name}', 'Guest'),
                      });
                    });
                  },
                  child: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // Messages View
          Container(
            height: 220,
            color: const Color(0xFFECE5DD),
            padding: const EdgeInsets.all(10),
            child: ListView.builder(
              controller: _simScrollCtrl,
              itemCount: _simMessages.length,
              itemBuilder: (context, index) {
                final m = _simMessages[index];
                final isUser = m['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    constraints: const BoxConstraints(maxWidth: 380),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFFDCF8C6) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(10),
                        topRight: const Radius.circular(10),
                        bottomLeft: Radius.circular(isUser ? 10 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 10),
                      ),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
                    ),
                    child: Text(
                      m['text'] ?? '',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), height: 1.3),
                    ),
                  ),
                );
              },
            ),
          ),
          // Quick Chips
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: sampleChips.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 0.8),
                      label: Text(
                        c['label']!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      onPressed: () => _sendSimulationMessage(c['msg']!),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Input Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _simInputCtrl,
                    style: const TextStyle(fontSize: 11.5),
                    onSubmitted: _sendSimulationMessage,
                    decoration: const InputDecoration(
                      hintText: 'Type a message to test WhatsApp templates...',
                      hintStyle: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSimulating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _AiTheme.purpleBrand))
                      : const Icon(Icons.send_rounded, size: 18, color: Color(0xFF075E54)),
                  onPressed: _isSimulating ? null : () => _sendSimulationMessage(_simInputCtrl.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 8: Save & Sync Button
  Widget _buildSaveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _AiTheme.headerNavyStart,
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
                  'Save & Sync AI Chat Agent',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
    );
  }

  Widget _buildStyledInputField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 11.5, color: _AiTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _AiTheme.purpleBrand, width: 1.2)),
      ),
    );
  }
}
