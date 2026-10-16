import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/database_service.dart';
import '../../core/services/whatsapp_chat_service.dart';

/// Compact Neumorphic Styling for AI Chat Agent Screen
class _AiTheme {
  static const Color background = Color(0xFFEEF2F6);
  static const Color darkShadow = Color(0xFFCBD5E1);
  static const Color lightShadow = Colors.white;

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color purpleBrand = Color(0xFF7C3AED);
  static const Color greenBrand = Color(0xFF059669);
  static const Color blueBrand = Color(0xFF2563EB);

  static List<BoxShadow> get cardShadows => [
        BoxShadow(
          color: lightShadow.withValues(alpha: 0.95),
          offset: const Offset(-4, -4),
          blurRadius: 8,
        ),
        BoxShadow(
          color: darkShadow.withValues(alpha: 0.70),
          offset: const Offset(4, 4),
          blurRadius: 8,
        ),
      ];

  static BoxDecoration get neumorphicCard => BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadows,
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.0),
      );

  static BoxDecoration get sunkenWell => BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1).withValues(alpha: 0.6), width: 1),
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

  late TextEditingController _agentNameCtrl;
  late TextEditingController _greetingCtrl;
  late TextEditingController _promptCtrl;
  late TextEditingController _houseRulesCtrl;
  late TextEditingController _apiKeyCtrl;

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

    _agentNameCtrl = TextEditingController(text: _db.aiChatAgentName);
    _greetingCtrl = TextEditingController(text: _db.aiChatAgentGreeting);
    _promptCtrl = TextEditingController(text: _db.aiChatAgentSystemPrompt);
    _houseRulesCtrl = TextEditingController(text: _db.aiChatAgentCustomInstructions);
    _apiKeyCtrl = TextEditingController(text: _db.aiChatAgentApiKey);
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

      // 2. Fetch business AI settings
      final backendSettings = await _waService.getAiAgentSettings();
      if (backendSettings != null && mounted) {
        setState(() {
          if (backendSettings['enabled'] != null) {
            _isEnabled = backendSettings['enabled'] == true && _isMetaConnected;
          }
          if (backendSettings['persona'] != null) _persona = backendSettings['persona'].toString();
          if (backendSettings['model'] != null) _model = backendSettings['model'].toString();
          if (backendSettings['autoReplyDelaySeconds'] != null) {
            _delaySeconds = (backendSettings['autoReplyDelaySeconds'] as num).toInt();
          }
          if (backendSettings['autoMenuSuggest'] != null) {
            _autoMenuSuggest = backendSettings['autoMenuSuggest'] == true;
          }
          if (backendSettings['autoOrderTaking'] != null) {
            _autoOrderTaking = backendSettings['autoOrderTaking'] == true;
          }

          if (backendSettings['agentName'] != null) _agentNameCtrl.text = backendSettings['agentName'].toString();
          if (backendSettings['greeting'] != null) _greetingCtrl.text = backendSettings['greeting'].toString();
          if (backendSettings['systemPrompt'] != null) _promptCtrl.text = backendSettings['systemPrompt'].toString();
          if (backendSettings['customInstructions'] != null) {
            _houseRulesCtrl.text = backendSettings['customInstructions'].toString();
          }
          if (backendSettings['apiKey'] != null) {
            _apiKeyCtrl.text = backendSettings['apiKey'].toString();
            if (_apiKeyCtrl.text.isNotEmpty) _showCustomApiKey = true;
          }
        });
      }
    } catch (_) {
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
    _simInputCtrl.dispose();
    _simScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isEnabled && !_isMetaConnected) {
      _showMetaRequiredDialog();
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    // 1. Save locally in DatabaseService
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
      autoReplyDelay: _delaySeconds,
    );

    // 2. Synchronize to Backend MongoDB Business record
    final success = await _waService.updateAiAgentSettings({
      'enabled': _isEnabled,
      'persona': _persona.trim(),
      'agentName': _agentNameCtrl.text.trim(),
      'greeting': _greetingCtrl.text.trim(),
      'autoMenuSuggest': _autoMenuSuggest,
      'autoOrderTaking': _autoOrderTaking,
      'systemPrompt': _promptCtrl.text.trim(),
      'customInstructions': _houseRulesCtrl.text.trim(),
      'model': _model.trim(),
      'autoReplyDelaySeconds': _delaySeconds,
      'apiKey': _apiKeyCtrl.text.trim(),
    });

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF051C48),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: success ? const Color(0xFF10B981) : Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                success ? 'AI Agent settings saved and synced to database!' : 'Saved locally. Backend will sync on connection.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showMetaRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Meta WhatsApp API Required', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text(
          'To activate the AI Chat Agent and receive direct WhatsApp orders, your business must connect Meta WhatsApp Cloud API credentials first.',
          style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _AiTheme.purpleBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showMetaConnectDialog();
            },
            child: const Text('Connect Meta API', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
              Text('Connect Meta WhatsApp API', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
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
                _buildDialogField('System User Access Token *', tokenCtrl, 'Permanent Meta Access Token', isPassword: true),
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
                              backgroundColor: Color(0xFF051C48),
                              content: Text('Meta WhatsApp API Connected Successfully! AI Agent is now ready.'),
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
        'apiKey': _apiKeyCtrl.text,
        'model': _model,
      };

      final response = await _waService.simulateAiChat(trimmed, overrideSettings);
      final replyText = response?['replyText']?.toString() ??
          "Namaste! I have noted your message: \"$trimmed\". How else can I assist you today? 😊";

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
    final restaurantName = _db.restaurant?.name ?? 'Apna POS';

    return Scaffold(
      backgroundColor: _AiTheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF051C48),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA78BFA), width: 1.2),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Color(0xFFDDD6FE), size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'AI Chat Agent Settings',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$restaurantName • WhatsApp POS Assistant',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Compact Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: (_isEnabled && _isMetaConnected) ? const Color(0x2E10B981) : Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_isEnabled && _isMetaConnected) ? const Color(0xFF10B981) : Colors.white24,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isEnabled && _isMetaConnected) ? const Color(0xFF10B981) : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          (_isEnabled && _isMetaConnected) ? 'Online' : 'Standby',
                          style: TextStyle(
                            color: (_isEnabled && _isMetaConnected) ? const Color(0xFF34D399) : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
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
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator(color: _AiTheme.purpleBrand))
          : Center(
              // Constrained & Wrapped Screen Layout
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Meta Integration & Master Switch Card
                      _buildMetaStatusAndMasterCard(),
                      const SizedBox(height: 12),

                      // 2. Direct Order Taking Card
                      _buildOrderTakingCard(),
                      const SizedBox(height: 12),

                      // 3. Agent Identity & Greeting
                      _buildSectionHeader('IDENTITY & GREETING', Icons.badge_rounded, _AiTheme.blueBrand),
                      const SizedBox(height: 6),
                      _buildIdentityCard(),
                      const SizedBox(height: 12),

                      // 4. Conversational Persona
                      _buildSectionHeader('CONVERSATIONAL PERSONA', Icons.psychology_rounded, _AiTheme.purpleBrand),
                      const SizedBox(height: 6),
                      _buildPersonaSelector(),
                      const SizedBox(height: 12),

                      // 5. Custom Instructions & House Rules
                      _buildSectionHeader('SPECIAL HOUSE RULES', Icons.menu_book_rounded, const Color(0xFFD97706)),
                      const SizedBox(height: 6),
                      _buildHouseRulesCard(),
                      const SizedBox(height: 12),

                      // 6. Gemini Intelligence Engine (No key required for merchant)
                      _buildSectionHeader('AI ENGINE & SPEED', Icons.memory_rounded, const Color(0xFF4F46E5)),
                      const SizedBox(height: 6),
                      _buildEngineCard(),
                      const SizedBox(height: 14),

                      // 7. WhatsApp Simulator
                      _buildSectionHeader('LIVE WHATSAPP SIMULATOR', Icons.chat_rounded, const Color(0xFF25D366)),
                      const SizedBox(height: 6),
                      _buildSimulatorCard(),
                      const SizedBox(height: 20),

                      // 8. Save Button
                      _buildSaveButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Section Header with Small Icon
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // 1. Meta WhatsApp Connection & Master Switch Card
  Widget _buildMetaStatusAndMasterCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _AiTheme.neumorphicCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta WhatsApp Connection Status Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _isMetaConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isMetaConnected ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Icon(
                  _isMetaConnected ? Icons.check_circle_rounded : Icons.link_off_rounded,
                  color: _isMetaConnected ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isMetaConnected ? 'Meta Cloud API Connected' : 'Meta API Not Integrated',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _isMetaConnected ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isMetaConnected ? const Color(0xFF22C55E).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isMetaConnected ? 'Verified' : 'Required',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: _isMetaConnected ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isMetaConnected
                          ? (_metaPhoneId.isNotEmpty ? 'Phone ID: $_metaPhoneId' : 'Ready for WhatsApp messaging')
                          : 'Connect your Meta WhatsApp API credentials to enable the AI agent.',
                      style: const TextStyle(fontSize: 10.5, color: _AiTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (!_isMetaConnected)
                ElevatedButton.icon(
                  onPressed: _showMetaConnectDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_link_rounded, size: 14, color: Colors.white),
                  label: const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Master Switch Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Activate Autonomous AI Auto-Reply',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _AiTheme.textDark),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AI responds to incoming customer chats instantly on your WhatsApp Business number.',
                      style: TextStyle(fontSize: 10.5, color: _AiTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isEnabled && _isMetaConnected,
                activeThumbColor: Colors.white,
                activeTrackColor: _AiTheme.purpleBrand,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFCBD5E1),
                onChanged: _isMetaConnected
                    ? (val) {
                        HapticFeedback.lightImpact();
                        setState(() => _isEnabled = val);
                      }
                    : (_) => _showMetaRequiredDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Direct Order Taking Card
  Widget _buildOrderTakingCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _AiTheme.neumorphicCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF059669), size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'DIRECT ORDER TAKING IN CHAT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _autoOrderTaking ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _autoOrderTaking ? 'POS Active' : 'Off',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _autoOrderTaking ? const Color(0xFF059669) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'When customers text food/beverage orders on WhatsApp, the AI automatically detects menu dishes, calculates the bill, creates a pending POS Order, and alerts your counter in real time.',
            style: TextStyle(fontSize: 10.5, color: _AiTheme.textMuted, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSmallToggleTile(
                  'Auto-Create POS Order',
                  'Direct takeaway & delivery ordering',
                  _autoOrderTaking,
                  (val) => setState(() => _autoOrderTaking = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallToggleTile(
                  'Suggest Bestsellers',
                  'Recommends popular dishes & combos',
                  _autoMenuSuggest,
                  (val) => setState(() => _autoMenuSuggest = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallToggleTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _AiTheme.sunkenWell,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _AiTheme.textDark)),
                const SizedBox(height: 1),
                Text(subtitle, style: const TextStyle(fontSize: 9.5, color: _AiTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              activeTrackColor: _AiTheme.greenBrand,
              activeThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFCBD5E1),
              onChanged: (v) {
                HapticFeedback.lightImpact();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 3. Agent Identity & Greeting Card
  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _AiTheme.neumorphicCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assistant Display Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _AiTheme.textDark)),
          const SizedBox(height: 4),
          _buildCompactTextField(_agentNameCtrl, 'e.g. Apna AI Assistant'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Welcome Greeting Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _AiTheme.textDark)),
              Row(
                children: [
                  _buildTagChip('{restaurant_name}'),
                  const SizedBox(width: 4),
                  _buildTagChip('{customer_name}'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildCompactTextField(_greetingCtrl, 'Greeting sent on first customer message', maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return GestureDetector(
      onTap: () {
        final text = _greetingCtrl.text;
        _greetingCtrl.text = '$text $tag';
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: _AiTheme.purpleBrand.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(tag, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _AiTheme.purpleBrand)),
      ),
    );
  }

  // 4. Conversational Persona Selector
  Widget _buildPersonaSelector() {
    final personas = [
      {'id': 'friendly', 'label': 'Friendly', 'icon': Icons.sentiment_satisfied_alt_rounded, 'desc': 'Warm & Courteous'},
      {'id': 'hinglish', 'label': 'Hinglish', 'icon': Icons.chat_bubble_outline_rounded, 'desc': 'Desi Hindi + English'},
      {'id': 'professional', 'label': 'Executive', 'icon': Icons.business_center_rounded, 'desc': 'Formal & Crisp'},
      {'id': 'chef', 'label': 'Chef Host', 'icon': Icons.restaurant_menu_rounded, 'desc': 'Passionate Foodie'},
      {'id': 'sales', 'label': 'Sales Host', 'icon': Icons.campaign_rounded, 'desc': 'Highlights Combos'},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _AiTheme.neumorphicCard,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: personas.map((p) {
          final isSelected = _persona == p['id'];
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _persona = p['id'] as String);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? _AiTheme.purpleBrand : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _AiTheme.purpleBrand : const Color(0xFFCBD5E1),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _AiTheme.purpleBrand.withValues(alpha: 0.35),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p['icon'] as IconData, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        p['desc'] as String,
                        style: TextStyle(
                          fontSize: 8.5,
                          color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 5. Special House Rules Card
  Widget _buildHouseRulesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _AiTheme.neumorphicCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Instructions for AI',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _AiTheme.textDark),
          ),
          const SizedBox(height: 2),
          const Text(
            'Add house policies, closing hours, or delivery radius notes (e.g. "Kitchen closes at 11 PM. Delivery above ₹200 free.")',
            style: TextStyle(fontSize: 10, color: _AiTheme.textMuted),
          ),
          const SizedBox(height: 6),
          _buildCompactTextField(_houseRulesCtrl, 'e.g. Pure veg kitchen. No orders taken after 11 PM.', maxLines: 2),
        ],
      ),
    );
  }

  // 6. AI Engine Card (Server AI Included by Default)
  Widget _buildEngineCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _AiTheme.neumorphicCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, size: 16, color: _AiTheme.purpleBrand),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Google Gemini 3.8 Flash Engine', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _AiTheme.textDark)),
                    Text('Platform-wide server AI included • No merchant key required', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Included ✅', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
              ),
            ],
          ),

          const SizedBox(height: 10),
          // Reply Delay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Auto-Reply Delay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _AiTheme.textDark)),
              Row(
                children: [1, 2, 3, 5].map((s) {
                  final isSel = _delaySeconds == s;
                  return GestureDetector(
                    onTap: () => setState(() => _delaySeconds = s),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSel ? _AiTheme.purpleBrand : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isSel ? _AiTheme.purpleBrand : const Color(0xFFCBD5E1)),
                      ),
                      child: Text('${s}s', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF334155))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 8),
          // Optional Custom API Key accordion
          InkWell(
            onTap: () => setState(() => _showCustomApiKey = !_showCustomApiKey),
            child: Row(
              children: [
                Icon(_showCustomApiKey ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, size: 16, color: _AiTheme.purpleBrand),
                const SizedBox(width: 4),
                const Text('Custom Gemini API Key (Optional)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _AiTheme.purpleBrand)),
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
                fillColor: Colors.white,
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

  // 7. Live WhatsApp Simulator Card
  Widget _buildSimulatorCard() {
    return Container(
      decoration: _AiTheme.neumorphicCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulator Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF075E54),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                const Text('Live WhatsApp Chat Simulator', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _simMessages.clear();
                      final rName = _db.restaurant?.name ?? 'Our Restaurant';
                      _simMessages.add({
                        'role': 'assistant',
                        'text': _greetingCtrl.text.replaceAll('{restaurant_name}', rName).replaceAll('{customer_name}', 'Guest'),
                      });
                    });
                  },
                  child: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ),
              ],
            ),
          ),

          // Messages View
          Container(
            height: 220,
            color: const Color(0xFFE5DDD5).withValues(alpha: 0.6),
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
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFFE7FFDB) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(10),
                        topRight: const Radius.circular(10),
                        bottomLeft: Radius.circular(isUser ? 10 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 10),
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                    ),
                    child: Text(
                      m['text'] ?? '',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), height: 1.3),
                    ),
                  ),
                );
              },
            ),
          ),

          // Message Input Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _simInputCtrl,
                    style: const TextStyle(fontSize: 11),
                    onSubmitted: _sendSimulationMessage,
                    decoration: const InputDecoration(
                      hintText: 'Type "I want 2 Tea and 1 Sandwich" to test direct ordering...',
                      hintStyle: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSimulating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _AiTheme.purpleBrand))
                      : const Icon(Icons.send_rounded, size: 16, color: Color(0xFF075E54)),
                  onPressed: _isSimulating ? null : () => _sendSimulationMessage(_simInputCtrl.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 8. Save Button
  Widget _buildSaveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF051C48),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
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

  Widget _buildCompactTextField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 11.5, color: _AiTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.8),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _AiTheme.purpleBrand, width: 1.2)),
      ),
    );
  }
}
