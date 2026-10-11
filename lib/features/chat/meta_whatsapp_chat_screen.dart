import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/services/whatsapp_chat_service.dart';
import '../../core/widgets/glass_company_name_badge.dart';
import '../../core/widgets/connection_status_badge.dart';

class MetaWhatsAppChatScreen extends StatefulWidget {
  final String? initialPhone;
  final String? initialCustomerName;
  final bool enablePolling;
  final bool autoLoad;
  final List<WhatsAppChatModel>? initialChats;

  const MetaWhatsAppChatScreen({
    super.key,
    this.initialPhone,
    this.initialCustomerName,
    this.enablePolling = true,
    this.autoLoad = true,
    this.initialChats,
  });

  @override
  State<MetaWhatsAppChatScreen> createState() => _MetaWhatsAppChatScreenState();
}

class _MetaWhatsAppChatScreenState extends State<MetaWhatsAppChatScreen> {
  final WhatsAppChatService _chatService = WhatsAppChatService();
  final DatabaseService _db = DatabaseService();

  List<WhatsAppChatModel> _chats = [];
  WhatsAppChatModel? _selectedChat;
  List<WhatsAppMessageModel> _messages = [];

  bool _isLoadingChats = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String _searchQuery = '';
  WhatsAppConnectionInfo? _connectionInfo;

  // New WhatsApp UI State
  String _selectedFilter = 'All'; // 'All' | 'Unread' | 'Groups'
  int _selectedBottomNavIndex = 0; // 0: Chats, 1: Updates, 2: Communities, 3: Calls

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  Timer? _pollingTimer;

  // WhatsApp Branding Colors
  static const Color waTealDark = Color(0xFF075E54);
  static const Color waTeal = Color(0xFF128C7E);
  static const Color waGreen = Color(0xFF25D366);
  static const Color waGreenLight = Color(0xFFD8FDD2);
  static const Color waGreenDark = Color(0xFF008069);
  static const Color waChatBg = Color(0xFFEFEAE2);
  static const Color waOutgoingBubble = Color(0xFFD9FDD3);
  static const Color waIncomingBubble = Colors.white;
  static const Color waDarkText = Color(0xFF111B21);
  static const Color waMutedText = Color(0xFF667781);
  static const Color waCheckBlue = Color(0xFF53BDEB);
  static const Color waLightGreyBg = Color(0xFFF0F2F5);

  @override
  void initState() {
    super.initState();
    if (widget.initialChats != null) {
      _chats = List.from(widget.initialChats!);
      _isLoadingChats = false;
    }
    if (widget.autoLoad) {
      _loadConnectionAndChats();
    } else {
      _isLoadingChats = false;
    }
    // Poll for real-time incoming messages every 4 seconds
    if (widget.enablePolling) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) {
          _refreshSilently();
        }
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConnectionAndChats() async {
    setState(() => _isLoadingChats = true);
    try {
      final conn = await _chatService.getConnectionStatus();
      final chats = await _chatService.getChats(search: _searchQuery);

      if (mounted) {
        setState(() {
          _connectionInfo = conn;
          _chats = chats;
          _isLoadingChats = false;
        });

        // If an initial phone was passed, open or create it
        if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
          _handleInitialPhone(widget.initialPhone!, widget.initialCustomerName);
        } else if (chats.isNotEmpty && _selectedChat == null && MediaQuery.of(context).size.width >= 680) {
          // Auto-select first chat on tablet/desktop
          _selectChat(chats.first);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingChats = false);
      }
    }
  }

  Future<void> _handleInitialPhone(String phone, String? name) async {
    try {
      final res = await _chatService.startNewChat(
        customerPhone: phone,
        customerName: name,
      );
      if (res != null && mounted) {
        setState(() {
          _selectedChat = res;
          if (!_chats.any((c) => c.id == res.id)) {
            _chats.insert(0, res);
          }
        });
        _loadMessages(res.id);
      }
    } catch (_) {}
  }

  Future<void> _refreshSilently() async {
    try {
      final chats = await _chatService.getChats(search: _searchQuery);
      if (mounted) {
        setState(() => _chats = chats);
        if (_selectedChat != null) {
          final updatedChat = chats.where((c) => c.id == _selectedChat!.id).firstOrNull;
          if (updatedChat != null) {
            _selectedChat = updatedChat;
          }
          final msgs = await _chatService.getChatMessages(_selectedChat!.id);
          if (mounted) {
            final bool hasChanged = msgs.length != _messages.length ||
                (msgs.isNotEmpty && _messages.isNotEmpty && msgs.last.id != _messages.last.id) ||
                (msgs.isNotEmpty && _messages.isNotEmpty && msgs.last.status != _messages.last.status);
            if (hasChanged) {
              setState(() => _messages = msgs);
              _scrollToBottom();
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _selectChat(WhatsAppChatModel chat) async {
    setState(() {
      _selectedChat = chat;
      _isLoadingMessages = true;
    });

    try {
      final msgs = await _chatService.getChatMessages(chat.id);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoadingMessages = false;
        });
        _scrollToBottom();
        // Clear unread badge in list
        final index = _chats.indexWhere((c) => c.id == chat.id);
        if (index != -1 && _chats[index].unreadCount > 0) {
          setState(() {
            _chats[index] = WhatsAppChatModel(
              id: _chats[index].id,
              customerPhone: _chats[index].customerPhone,
              customerName: _chats[index].customerName,
              lastMessage: _chats[index].lastMessage,
              lastMessageAt: _chats[index].lastMessageAt,
              lastMessageDirection: _chats[index].lastMessageDirection,
              unreadCount: 0,
              status: _chats[index].status,
              phoneNumberId: _chats[index].phoneNumberId,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  Future<void> _loadMessages(String chatId) async {
    try {
      final msgs = await _chatService.getChatMessages(chatId);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedChat == null || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final newMsg = await _chatService.sendMessage(_selectedChat!.id, text);
      if (newMsg != null && mounted) {
        setState(() {
          _messages.add(newMsg);
          _isSending = false;
        });
        _scrollToBottom();
        // Update chat list preview
        final index = _chats.indexWhere((c) => c.id == _selectedChat!.id);
        if (index != -1) {
          setState(() {
            _chats[index] = WhatsAppChatModel(
              id: _chats[index].id,
              customerPhone: _chats[index].customerPhone,
              customerName: _chats[index].customerName,
              lastMessage: text,
              lastMessageAt: DateTime.now(),
              lastMessageDirection: 'OUTGOING',
              unreadCount: 0,
              status: _chats[index].status,
              phoneNumberId: _chats[index].phoneNumberId,
            );
            // Move active chat to top
            final item = _chats.removeAt(index);
            _chats.insert(0, item);
          });
        }
      } else {
        setState(() => _isSending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showErrorSnackBar('Failed to send message: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNewChatDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final msgCtrl = TextEditingController(text: 'Hello! How can we help you today?');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          title: Row(
            children: const [
              Icon(Icons.person_add_alt_1_rounded, color: waTeal, size: 18),
              SizedBox(width: 8),
              Text('New WhatsApp Chat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    labelStyle: const TextStyle(fontSize: 12),
                    hintText: 'e.g. 9876543210 or +919876543210',
                    hintStyle: const TextStyle(fontSize: 11.5),
                    prefixIcon: const Icon(Icons.phone_android_rounded, size: 17),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Name (Optional)',
                    labelStyle: const TextStyle(fontSize: 12),
                    hintText: 'Customer Name',
                    hintStyle: const TextStyle(fontSize: 11.5),
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 17),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Initial Message',
                    labelStyle: const TextStyle(fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final phone = phoneCtrl.text.trim();
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid phone number')),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        final chat = await _chatService.startNewChat(
                          customerPhone: phone,
                          customerName: nameCtrl.text.trim(),
                          initialMessage: msgCtrl.text.trim(),
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (chat != null && mounted) {
                          _selectChat(chat);
                          _loadConnectionAndChats();
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) _showErrorSnackBar('Could not start chat: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: waTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Start Chat', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigureCredentialsDialog() {
    final phoneIdCtrl = TextEditingController(text: _connectionInfo?.phoneNumberId ?? _db.whatsAppPhoneId);
    final phoneNumCtrl = TextEditingController(text: _connectionInfo?.phoneNumber ?? _db.whatsAppPhoneNumber);
    final tokenCtrl = TextEditingController(text: _db.whatsAppAccessToken);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.tune_rounded, color: waTeal, size: 20),
              SizedBox(width: 8),
              Text('Meta API Credentials', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneIdCtrl,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number ID *',
                    hintText: 'e.g. 1284061438133660',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneNumCtrl,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Mobile Number',
                    hintText: 'e.g. +91 9709593705',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tokenCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    labelText: 'Access Token (Optional)',
                    hintText: 'Server default',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await _chatService.saveConnection(
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
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        _loadConnectionAndChats();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        _showErrorSnackBar('Save error: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: waTeal, foregroundColor: Colors.white),
              child: const Text('Save', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectedChat != null) {
          setState(() => _selectedChat = null);
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF031024), // Deep Midnight Navy (matching POS screen)
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF031024), // Deep Midnight Navy
                Color(0xFF072146), // Rich Royal Navy
                Color(0xFF0A2E5C), // Deep Indigo Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: true,
            child: Column(
              children: [
                // 1. TOP HEADER BAR (Identical to POS Screen)
                _buildPosStyleTopHeader(),

                // 2. ACTIVE SCREEN WORKSPACE (Curved Top Container wrapping the screen like POS)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDF3FA), // Signature Apna POS workspace background
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 16,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWideScreen = constraints.maxWidth >= 860;
                          if (isWideScreen) {
                            return _buildWidescreenLayout(constraints);
                          }
                          return _buildCenteredPhoneLayout(constraints);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosStyleTopHeader() {
    final companyTitle = _db.restaurant?.name ?? _db.currentUser?.companyName ?? 'Apna POS';
    final phoneId = _connectionInfo?.phoneNumberId ?? _db.whatsAppPhoneId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.transparent,
      child: Row(
        children: [
          // Circular Back / Home Button
          InkWell(
            onTap: () {
              if (_selectedChat != null) {
                setState(() => _selectedChat = null);
              } else {
                Navigator.of(context).pop();
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const ClipOval(
                child: Center(
                  child: Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 19),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // HIGHLIGHTED COMPANY NAME BADGE WITH WHATSAPP LIVE PILL
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: GlassCompanyNameBadge(
                    name: companyTitle,
                    hasDropdown: false,
                    isNeumorphic: false,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: phoneId.isNotEmpty ? 'Phone ID: $phoneId' : 'Meta WhatsApp Cloud API',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFF25D366)),
                        SizedBox(width: 4),
                        Text(
                          'WhatsApp Live',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF25D366)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // ONLINE / OFFLINE STATUS DOT INDICATOR (Same as POS)
          const GlassConnectionStatusBadge(isDarkTheme: true, compact: true),
          const SizedBox(width: 8),

          // Glass circular action buttons
          _buildGlassHeaderButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Chats',
            onTap: _loadConnectionAndChats,
          ),
          const SizedBox(width: 6),
          _buildGlassHeaderButton(
            icon: Icons.person_add_rounded,
            tooltip: 'New WhatsApp Chat',
            onTap: _showNewChatDialog,
          ),
          const SizedBox(width: 6),
          _buildGlassHeaderButton(
            icon: Icons.tune_rounded,
            tooltip: 'API Credentials',
            onTap: _showConfigureCredentialsDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildWidescreenLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Apna POS WhatsApp Control Companion Dashboard
          Expanded(
            flex: 3,
            child: _buildApnaPosCompanionPanel(),
          ),
          const SizedBox(width: 20),
          // Right Side: Smartphone Device Frame Mockup
          Expanded(
            flex: 4,
            child: _buildSmartphoneFrame(
              maxWidth: 410,
              maxHeight: (constraints.maxHeight - 32).clamp(580.0, 780.0),
              child: _selectedChat != null
                  ? _buildChatConversationView(isMobile: true)
                  : _buildWhatsAppMobileChatList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredPhoneLayout(BoxConstraints constraints) {
    final isMobile = constraints.maxWidth < 500;
    return Center(
      child: _buildSmartphoneFrame(
        maxWidth: isMobile ? constraints.maxWidth : 410,
        maxHeight: constraints.maxHeight,
        child: _selectedChat != null
            ? _buildChatConversationView(isMobile: true)
            : _buildWhatsAppMobileChatList(),
      ),
    );
  }

  Widget _buildApnaPosCompanionPanel() {
    final phoneId = _connectionInfo?.phoneNumberId ?? _db.whatsAppPhoneId;
    final integratedPhone = _connectionInfo?.phoneNumber ?? _db.whatsAppPhoneNumber;
    final int unreadTotal = _chats.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Icon(Icons.chat_rounded, color: waTeal, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _db.restaurant?.name ?? 'Apna POS Outlet',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Meta Cloud API • 2-Way Live Messaging',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircleAvatar(radius: 3, backgroundColor: Color(0xFF16A34A)),
                          SizedBox(width: 5),
                          Text(
                            'ONLINE',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Credentials summary
                Row(
                  children: [
                    Expanded(
                      child: _buildCompanionInfoPill(
                        label: 'Phone Number ID',
                        value: phoneId.isNotEmpty ? phoneId : 'Not Set',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCompanionInfoPill(
                        label: 'WhatsApp Number',
                        value: integratedPhone.isNotEmpty ? integratedPhone : 'Integrated',
                        icon: Icons.phone_android_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Live Metric Counters
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_chats.length}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const Text('Total Chats', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.mark_chat_unread_rounded, color: waGreen, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unreadTotal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: unreadTotal > 0 ? waGreen : const Color(0xFF0F172A),
                            ),
                          ),
                          const Text('Unread Messages', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Quick Action Buttons
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _showNewChatDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Start New Customer Chat', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: waTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _showConfigureCredentialsDialog,
                  icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF475569)),
                  label: const Text('Configure Phone ID & Credentials', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Guidance Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer replies to WhatsApp eBills or incoming queries automatically appear in real-time inside the live mobile phone view.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanionInfoPill({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  /// Smartphone Device Mockup Frame containing authentic WhatsApp Mobile View
  Widget _buildSmartphoneFrame({required Widget child, required double maxWidth, required double maxHeight}) {
    final bool isMobile = maxWidth < 500;
    final double frameWidth = isMobile ? (maxWidth - 12).clamp(320.0, 420.0) : 410.0;
    final double frameHeight = isMobile ? (maxHeight - 12).clamp(520.0, 840.0) : maxHeight.clamp(580.0, 820.0);
    final double outerRadius = isMobile ? 38.0 : 46.0;
    final double innerRadius = isMobile ? 30.0 : 38.0;
    final double borderWidth = isMobile ? 6.0 : 8.5;

    return Center(
      child: Container(
        width: frameWidth,
        height: frameHeight,
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 6 : 10,
          vertical: isMobile ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Dark Titanium Bezel
          borderRadius: BorderRadius.circular(outerRadius),
          border: Border.all(color: const Color(0xFF334155), width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              offset: const Offset(0, 18),
              blurRadius: 36,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.2),
              offset: const Offset(-1, -1),
              blurRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                // Phone Top Status Bar & Dynamic Island (White background with black icons matching reference UI)
                _buildPhoneStatusBar(),

                // Mobile View Body
                Expanded(child: child),

                // Bottom Home Bar Indicator (Centered black capsule matching reference UI)
                _buildPhoneHomeIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Phone Status Bar: 9:41 Time, Dynamic Island with Camera lens, Signal, WiFi, Battery
  Widget _buildPhoneStatusBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 9:41 Phone Clock
          const SizedBox(
            width: 60,
            child: Text(
              '9:41',
              style: TextStyle(
                color: Color(0xFF000000),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // Dynamic Island Notch Pill with camera lens
          Container(
            width: 106,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
                  ),
                ),
              ],
            ),
          ),

          // Signal, Wifi, Battery
          const SizedBox(
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.signal_cellular_alt_rounded, size: 14, color: Color(0xFF000000)),
                SizedBox(width: 3),
                Icon(Icons.wifi_rounded, size: 14, color: Color(0xFF000000)),
                SizedBox(width: 3),
                Icon(Icons.battery_full_rounded, size: 18, color: Color(0xFF000000)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Phone Bottom Home Indicator Bar
  Widget _buildPhoneHomeIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Center(
        child: Container(
          width: 124,
          height: 4.5,
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  /// WhatsApp Mobile View: Chat List Screen exactly matching uploaded reference image
  Widget _buildWhatsAppMobileChatList() {
    final int unreadTotal = _chats.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Column(
      children: [
        // 1. WhatsApp Top Header (White with bold green 'WhatsApp', Camera & 3-dots Menu)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(
            children: [
              const Text(
                'WhatsApp',
                style: TextStyle(
                  color: Color(0xFF00A884), // WhatsApp brand green
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, size: 22, color: Color(0xFF111B21)),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Camera',
                onPressed: () {},
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 22, color: Color(0xFF111B21)),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'More options',
                onSelected: (val) {
                  if (val == 'new_chat') _showNewChatDialog();
                  if (val == 'credentials') _showConfigureCredentialsDialog();
                  if (val == 'refresh') _loadConnectionAndChats();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'new_chat',
                    child: Text('New chat', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Text('Refresh chats', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'credentials',
                    child: Text('Settings / Credentials', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Search Bar with iridescent Meta AI gradient ring
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: waLightGreyBg,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _buildMetaAiRing(),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF111B21)),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _chatService.getChats(search: val).then((chats) {
                        if (mounted) setState(() => _chats = chats);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Ask Meta AI or Search',
                      hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF667781)),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF667781)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _loadConnectionAndChats();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Category Filter Pills: All, Unread, Groups
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            children: [
              _buildFilterPill('All'),
              const SizedBox(width: 8),
              _buildFilterPill('Unread', badgeCount: unreadTotal),
              const SizedBox(width: 8),
              _buildFilterPill('Groups'),
            ],
          ),
        ),

        // 4. Chat List Body with Circular Green FAB
        Expanded(
          child: Stack(
            children: [
              Container(
                color: Colors.white,
                child: _buildChatListColumn(),
              ),

              // Green WhatsApp Circular Floating Action Button
              Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: _showNewChatDialog,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A884),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_rounded, color: Colors.white, size: 23),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 5. Official WhatsApp Bottom Navigation Bar (Chats, Updates, Communities, Calls)
        _buildWhatsAppBottomNavBar(unreadTotal),
      ],
    );
  }

  /// Iridescent Meta AI Ring icon matching official WhatsApp UI
  Widget _buildMetaAiRing() {
    return Container(
      width: 21,
      height: 21,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF0064E0),
            Color(0xFF00A3FF),
            Color(0xFF8A3FFC),
            Color(0xFFFF3B30),
            Color(0xFF0064E0),
          ],
        ),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: const BoxDecoration(
          color: waLightGreyBg,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Filter pill chip (All, Unread, Groups)
  Widget _buildFilterPill(String title, {int badgeCount = 0}) {
    final bool isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? waGreenLight : waLightGreyBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? waGreenDark : const Color(0xFF54656F),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (badgeCount > 0 && !isSelected) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(
                  color: waGreenDark,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Official WhatsApp 4-Tab Bottom Navigation Bar
  Widget _buildWhatsAppBottomNavBar(int unreadCount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: waLightGreyBg, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(
            index: 0,
            label: 'Chats',
            icon: Icons.chat_rounded,
            badgeCount: unreadCount > 0 ? unreadCount : 1,
            isSelected: _selectedBottomNavIndex == 0,
          ),
          _buildBottomNavItem(
            index: 1,
            label: 'Updates',
            icon: Icons.motion_photos_on_outlined,
            isSelected: _selectedBottomNavIndex == 1,
          ),
          _buildBottomNavItem(
            index: 2,
            label: 'Communities',
            icon: Icons.groups_outlined,
            isSelected: _selectedBottomNavIndex == 2,
          ),
          _buildBottomNavItem(
            index: 3,
            label: 'Calls',
            icon: Icons.call_outlined,
            isSelected: _selectedBottomNavIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required String label,
    required IconData icon,
    int badgeCount = 0,
    required bool isSelected,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedBottomNavIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected ? waGreenLight : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? waGreenDark : const Color(0xFF54656F),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: waGreenDark,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF008069) : const Color(0xFF54656F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListColumn() {
    List<WhatsAppChatModel> filtered = _chats;

    // Filter by category pill
    if (_selectedFilter == 'Unread') {
      filtered = filtered.where((c) => c.unreadCount > 0).toList();
    } else if (_selectedFilter == 'Groups') {
      filtered = []; // No group chats in 1-on-1 business WhatsApp
    }

    if (_isLoadingChats) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF008069), strokeWidth: 2.5));
    }

    if (filtered.isEmpty) {
      return _buildEmptyChatList();
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: 74,
        color: Color(0xFFF1F5F9),
      ),
      itemBuilder: (context, index) {
        final chat = filtered[index];
        final isSelected = _selectedChat?.id == chat.id;

        return Material(
          color: isSelected ? const Color(0xFFF0F2F5) : Colors.white,
          child: InkWell(
            onTap: () => _selectChat(chat),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Text(
                      chat.avatarInitials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF111B21),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTimestamp(chat.lastMessageAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                color: chat.unreadCount > 0 ? const Color(0xFF008069) : const Color(0xFF667781),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (chat.lastMessageDirection == 'OUTGOING') ...[
                              const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF53BDEB)),
                              const SizedBox(width: 3),
                            ],
                            Expanded(
                              child: Text(
                                chat.lastMessage.isNotEmpty ? chat.lastMessage : 'No messages',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: chat.unreadCount > 0 ? const Color(0xFF111B21) : const Color(0xFF667781),
                                  fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (chat.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF25D366),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                child: Text(
                                  '${chat.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
        );
      },
    );
  }

  Widget _buildEmptyChatList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Icon(Icons.mark_chat_unread_outlined, size: 28, color: Color(0xFF008069)),
            ),
            const SizedBox(height: 10),
            const Text(
              'No chats yet',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF111B21)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Customer replies will appear here in real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF667781)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showNewChatDialog,
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('New Chat', style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildChatConversationView({bool isMobile = false}) {
    if (_selectedChat == null) return const SizedBox();

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: waTealDark,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _selectedChat = null),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(
                  _selectedChat!.avatarInitials,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 11),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedChat!.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 5.5, color: Color(0xFF4ADE80)),
                        const SizedBox(width: 4),
                        Text(
                          _selectedChat!.customerPhone,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFFE2E8F0)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () => _loadMessages(_selectedChat!.id),
              ),
            ],
          ),
        ),

        // Message List
        Expanded(
          child: Container(
            color: waChatBg,
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator(color: waTeal, strokeWidth: 2.5))
                : _messages.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'No messages yet',
                            style: TextStyle(fontSize: 11, color: waMutedText),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),
        ),

        // Bottom Quick Replies & Input Bar
        Container(
          color: const Color(0xFFF0F2F5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick reply chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickChip('Order Ready for Pickup'),
                    _buildQuickChip('Your bill total is ready'),
                    _buildQuickChip('Thank you for your visit!'),
                    _buildQuickChip('Table confirmed'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(fontSize: 12.5, color: waDarkText),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(fontSize: 12.5, color: waMutedText),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: waTeal,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: _isSending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 17),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 10, color: waTealDark, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
        onPressed: () {
          _messageController.text = text;
          _messageFocusNode.requestFocus();
        },
      ),
    );
  }

  Widget _buildMessageBubble(WhatsAppMessageModel msg) {
    final isOutgoing = msg.isOutgoing;
    final screenWidth = MediaQuery.of(context).size.width;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth >= 680 ? 460 : screenWidth * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isOutgoing ? waOutgoingBubble : waIncomingBubble,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: Radius.circular(isOutgoing ? 8 : 0),
              bottomRight: Radius.circular(isOutgoing ? 0 : 8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  msg.text,
                  style: const TextStyle(fontSize: 12.5, color: waDarkText, height: 1.25),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.timestamp),
                    style: const TextStyle(fontSize: 9.5, color: waMutedText),
                  ),
                  if (isOutgoing) ...[
                    const SizedBox(width: 3),
                    _buildStatusIcon(msg.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'READ':
        return const Icon(Icons.done_all_rounded, size: 13, color: waCheckBlue);
      case 'DELIVERED':
        return const Icon(Icons.done_all_rounded, size: 13, color: waMutedText);
      case 'SENT':
        return const Icon(Icons.check_rounded, size: 13, color: waMutedText);
      case 'FAILED':
        return const Icon(Icons.error_outline_rounded, size: 13, color: Colors.red);
      default:
        return const Icon(Icons.access_time_rounded, size: 11, color: waMutedText);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      return _formatTime(dt);
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
