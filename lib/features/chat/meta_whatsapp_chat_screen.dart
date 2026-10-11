import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/services/whatsapp_chat_service.dart';

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

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  Timer? _pollingTimer;

  // WhatsApp Branding Colors
  static const Color waTealDark = Color(0xFF075E54);
  static const Color waTeal = Color(0xFF128C7E);
  static const Color waGreen = Color(0xFF25D366);
  static const Color waChatBg = Color(0xFFEFEAE2);
  static const Color waOutgoingBubble = Color(0xFFD9FDD3);
  static const Color waIncomingBubble = Colors.white;
  static const Color waDarkText = Color(0xFF111B21);
  static const Color waMutedText = Color(0xFF667781);
  static const Color waCheckBlue = Color(0xFF53BDEB);

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
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6), // Apna POS Neumorphic Canvas
      appBar: _buildApnaPosAppBar(),
      body: SafeArea(
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
    );
  }

  PreferredSizeWidget _buildApnaPosAppBar() {
    final phoneId = _connectionInfo?.phoneNumberId ?? _db.whatsAppPhoneId;

    return AppBar(
      backgroundColor: const Color(0xFF0F172A), // Apna POS Slate Navy
      foregroundColor: Colors.white,
      elevation: 1,
      toolbarHeight: 54,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        tooltip: 'Back to Settings',
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _db.restaurant?.name ?? "Apna POS",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        phoneId.isNotEmpty ? 'WhatsApp Live • $phoneId' : 'WhatsApp Live',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w400),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh Chats',
          iconSize: 18,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadConnectionAndChats,
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'New WhatsApp Chat',
          iconSize: 18,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          onPressed: _showNewChatDialog,
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'API Credentials',
          iconSize: 18,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.tune_rounded, color: Colors.white),
          onPressed: _showConfigureCredentialsDialog,
        ),
        const SizedBox(width: 6),
      ],
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
    final double frameWidth = isMobile ? maxWidth : 400.0;
    final double frameHeight = isMobile ? maxHeight : maxHeight.clamp(560.0, 780.0);
    final double outerRadius = isMobile ? 22.0 : 38.0;
    final double innerRadius = isMobile ? 18.0 : 30.0;
    final double borderWidth = isMobile ? 4.0 : 7.5;

    return Center(
      child: Container(
        width: frameWidth,
        height: frameHeight,
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 4 : 8,
          vertical: isMobile ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Deep Slate Titanium Chassis
          borderRadius: BorderRadius.circular(outerRadius),
          border: Border.all(color: const Color(0xFF1E293B), width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: const Color(0x380F172A),
              offset: const Offset(0, 16),
              blurRadius: 32,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.85),
              offset: const Offset(-2, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: Column(
            children: [
              // Phone Top Status Bar & Dynamic Island
              Container(
                color: waTealDark,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Fake Phone Time
                    const Text(
                      '9:41',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    // Dynamic Island / Speaker notch
                    Container(
                      width: 68,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Phone Status Icons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.signal_cellular_4_bar_rounded, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Icon(Icons.wifi_rounded, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Icon(Icons.battery_5_bar_rounded, size: 13, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),

              // Mobile View Body
              Expanded(child: child),

              // Bottom Home Bar Indicator
              Container(
                color: const Color(0xFFF0F2F5),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(3),
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

  /// WhatsApp Mobile View: Chat List Screen with authentic header and FAB
  Widget _buildWhatsAppMobileChatList() {
    return Stack(
      children: [
        Column(
          children: [
            // WhatsApp Header inside phone
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: waTealDark,
              child: Row(
                children: [
                  const Text(
                    'WhatsApp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: 'Refresh',
                    onPressed: _loadConnectionAndChats,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: 'New Chat',
                    onPressed: _showNewChatDialog,
                  ),
                ],
              ),
            ),
            // Conversations list column
            Expanded(
              child: _buildChatListColumn(),
            ),
          ],
        ),
        // Green WhatsApp Floating Action Button
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingActionButton.small(
            backgroundColor: waGreen,
            foregroundColor: Colors.white,
            elevation: 3,
            tooltip: 'Start Chat',
            onPressed: _showNewChatDialog,
            child: const Icon(Icons.chat_bubble_rounded, size: 17),
          ),
        ),
      ],
    );
  }

  Widget _buildChatListColumn() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: const Color(0xFFF0F2F5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 12),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _chatService.getChats(search: val).then((chats) {
                  if (mounted) setState(() => _chats = chats);
                });
              },
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: const TextStyle(fontSize: 12, color: waMutedText),
                prefixIcon: const Icon(Icons.search_rounded, size: 17, color: waMutedText),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 15, color: waMutedText),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadConnectionAndChats();
                        },
                      )
                    : null,
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              ),
            ),
          ),
        ),
        // Conversations List
        Expanded(
          child: _isLoadingChats
              ? const Center(child: CircularProgressIndicator(color: waTeal, strokeWidth: 2.5))
              : _chats.isEmpty
                  ? _buildEmptyChatList()
                  : ListView.separated(
                      itemCount: _chats.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        final isSelected = _selectedChat?.id == chat.id;

                        return Material(
                          color: isSelected ? const Color(0xFFF0F2F5) : Colors.white,
                          child: InkWell(
                            onTap: () => _selectChat(chat),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 19,
                                    backgroundColor: const Color(0xFFCBD5E1),
                                    child: Text(
                                      chat.avatarInitials,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                                                  fontSize: 13,
                                                  color: waDarkText,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatTimestamp(chat.lastMessageAt),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                                color: chat.unreadCount > 0 ? waGreen : waMutedText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (chat.lastMessageDirection == 'OUTGOING') ...[
                                              const Icon(Icons.done_all_rounded, size: 13, color: waCheckBlue),
                                              const SizedBox(width: 3),
                                            ],
                                            Expanded(
                                              child: Text(
                                                chat.lastMessage.isNotEmpty ? chat.lastMessage : 'No messages',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: chat.unreadCount > 0 ? waDarkText : waMutedText,
                                                  fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            if (chat.unreadCount > 0)
                                              Container(
                                                margin: const EdgeInsets.only(left: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: const BoxDecoration(
                                                  color: waGreen,
                                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                                ),
                                                child: Text(
                                                  '${chat.unreadCount}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
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
                    ),
        ),
      ],
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
              child: const Icon(Icons.mark_chat_unread_outlined, size: 28, color: waTeal),
            ),
            const SizedBox(height: 10),
            const Text(
              'No chats yet',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: waDarkText),
            ),
            const SizedBox(height: 4),
            const Text(
              'Customer replies will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: waMutedText),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showNewChatDialog,
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('New Chat', style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: waTeal,
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
