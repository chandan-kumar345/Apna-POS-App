import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/database/database_service.dart';
import '../../core/network/api_endpoints.dart';
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
  Timer? _searchDebounce;
  StreamSubscription<WhatsAppMessageModel>? _messageSub;
  StreamSubscription<List<WhatsAppChatModel>>? _chatsSub;

  // WhatsApp Branding Colors
  static const Color waTeal = Color(0xFF128C7E);

  @override
  void initState() {
    super.initState();
    if (widget.initialChats != null) {
      _chats = List.from(widget.initialChats!);
      _isLoadingChats = false;
    }

    // Attach real-time reactive WebSocket stream for sub-50ms message arrival
    _messageSub = _chatService.onMessageReceived.listen((msg) {
      if (!mounted) return;
      if (_selectedChat != null && _selectedChat!.id == msg.chatId) {
        final alreadyPresent = _messages.any((m) =>
            m.id == msg.id ||
            (m.whatsappMessageId.isNotEmpty && m.whatsappMessageId == msg.whatsappMessageId));
        if (!alreadyPresent) {
          setState(() {
            _messages.add(msg);
          });
          _scrollToBottom();
        }
      }
    });

    _chatsSub = _chatService.onChatsUpdated.listen((updatedChats) {
      if (!mounted) return;
      setState(() {
        _chats = updatedChats;
        if (_selectedChat != null) {
          final found = updatedChats.where((c) => c.id == _selectedChat!.id).firstOrNull;
          if (found != null) {
            _selectedChat = found;
          }
        }
      });
    });

    if (widget.autoLoad) {
      _loadConnectionAndChats();
    } else {
      _isLoadingChats = false;
    }

    // Silent fallback polling every 6 seconds to ensure perfect consistency
    if (widget.enablePolling) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) {
          _refreshSilently();
        }
      });
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _chatsSub?.cancel();
    _pollingTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConnectionAndChats() async {
    // 1. Instant Cached Load (0ms UI render from SharedPreferences & memory)
    final cached = await _chatService.getChats(search: _searchQuery);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _chats = cached;
        _isLoadingChats = false;
      });
    } else {
      setState(() => _isLoadingChats = true);
    }

    try {
      final results = await Future.wait([
        _chatService.getConnectionStatus(),
        _chatService.getChats(search: _searchQuery, forceRefresh: true),
      ]);
      final conn = results[0] as WhatsAppConnectionInfo?;
      final chats = results[1] as List<WhatsAppChatModel>;

      if (mounted) {
        setState(() {
          _connectionInfo = conn;
          _chats = chats;
          _isLoadingChats = false;
        });

        // Ensure database & local cache immediately hold restored WhatsApp credentials
        if (conn != null && (conn.phoneNumberId.isNotEmpty || conn.phoneNumber.isNotEmpty)) {
          _db.saveWhatsAppIntegrationSettings(
            enabled: conn.connected,
            provider: 'meta_cloud',
            phoneNumber: conn.phoneNumber,
            phoneId: conn.phoneNumberId,
            wabaId: conn.wabaId,
            accessToken: conn.accessToken.isNotEmpty ? conn.accessToken : _db.whatsAppAccessToken,
            webhookToken: _db.whatsAppWebhookToken,
          );
        }

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

  /// Returns true if the error string indicates an invalid Meta Phone Number ID
  bool _isMetaPhoneIdError(String errorStr) {
    final lower = errorStr.toLowerCase();
    return lower.contains('unsupported post request') ||
        lower.contains('does not exist') ||
        lower.contains('missing permissions') ||
        lower.contains('graph api') ||
        lower.contains('phonenumberid') ||
        lower.contains('phone_number_id');
  }

  void _showErrorSnackBar(String message) {
    final isCredentialError = _isMetaPhoneIdError(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCredentialError
                    ? 'Invalid Phone Number ID. Please update your Meta API credentials.'
                    : message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: isCredentialError
            ? SnackBarAction(
                label: 'Fix',
                textColor: Colors.white,
                onPressed: _showConfigureCredentialsDialog,
              )
            : null,
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: isCredentialError
            ? const Duration(seconds: 6)
            : const Duration(seconds: 4),
      ),
    );
  }

  /// Redesigned New WhatsApp Chat Bottom Sheet Modal matching reference image
  void _showNewChatDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final msgCtrl = TextEditingController(text: 'Hello! How can we help you today?');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
          return Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedPadding(
              padding: EdgeInsets.only(bottom: bottomInset),
              duration: const Duration(milliseconds: 150),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 28,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Centered Drag Handle
                          Center(
                            child: Container(
                              width: 44,
                              height: 4.5,
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          // 2. Header Row: Squircle App Icon + Title + Subtitle (NO CROSS BUTTON per user request)
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8FDF2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.chat_bubble_rounded,
                                    color: Color(0xFF00A884),
                                    size: 21,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'New WhatsApp Chat',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Start a 2-way conversation via Meta API',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Quick Customer Picker from Store Customers
                          if (_db.customers.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Select Store Customer',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${_db.customers.length} saved',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _db.customers.take(15).length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (ctx, idx) {
                                  final cust = _db.customers[idx];
                                  final displayName = cust.name.isNotEmpty ? cust.name : cust.phone;
                                  return ActionChip(
                                    avatar: const CircleAvatar(
                                      backgroundColor: Color(0xFF00A884),
                                      radius: 10,
                                      child: Icon(Icons.person, size: 12, color: Colors.white),
                                    ),
                                    label: Text(displayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 0.8),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    onPressed: () {
                                      phoneCtrl.text = cust.phone;
                                      nameCtrl.text = cust.name;
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // 3. Recipient Phone Number Field
                          Row(
                            children: const [
                              Text(
                                'Recipient Phone Number',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '*',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            child: Row(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text('🇮🇳', style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 3),
                                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                                    SizedBox(width: 6),
                                    Text(
                                      '+91',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 20,
                                  width: 1,
                                  color: const Color(0xFFCBD5E1),
                                  margin: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '9876543210',
                                      hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 4. Customer Name (Optional) Field
                          const Text(
                            'Customer Name (Optional)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: nameCtrl,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Rahul Sharma',
                                      hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 5. Initial WhatsApp Message Field with Character Counter
                          Row(
                            children: const [
                              Text(
                                'Initial WhatsApp Message',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '*',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFDFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: msgCtrl,
                                  minLines: 3,
                                  maxLines: 4,
                                  onChanged: (_) => setSheetState(() {}),
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.3),
                                  decoration: const InputDecoration(
                                    hintText: 'Type initial message...',
                                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${msgCtrl.text.length}/1024',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // 6. Action Buttons: Cancel and Start Chat
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => Navigator.pop(sheetCtx),
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: InkWell(
                                  onTap: isSubmitting
                                      ? null
                                      : () async {
                                          final rawPhone = phoneCtrl.text.trim();
                                          if (rawPhone.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Please enter a phone number')),
                                            );
                                            return;
                                          }
                                          var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
                                          if (digits.startsWith('0') && digits.length == 11) {
                                            digits = digits.substring(1);
                                          }
                                          final phone = digits.length == 10 ? '91$digits' : digits;
                                          setSheetState(() => isSubmitting = true);
                                          try {
                                            final chat = await _chatService.startNewChat(
                                              customerPhone: phone,
                                              customerName: nameCtrl.text.trim(),
                                              initialMessage: msgCtrl.text.trim(),
                                            );
                                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                            if (chat != null && mounted) {
                                              _selectChat(chat);
                                              _loadConnectionAndChats();
                                            }
                                          } catch (e) {
                                            setSheetState(() => isSubmitting = false);
                                            if (mounted) {
                                              final errStr = e.toString();
                                              if (errStr.contains('131030') || errStr.toLowerCase().contains('not in allowed list')) {
                                                _showErrorSnackBar(
                                                  'Meta Sandbox: In Development Mode, messages can only be sent to verified test numbers. In Meta Console, add this number to "To" phone numbers, or switch App to Live Mode.',
                                                );
                                              } else if (_isMetaPhoneIdError(errStr)) {
                                                // Close the sheet and show fix prompt
                                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                                _showErrorSnackBar(errStr);
                                              } else {
                                                _showErrorSnackBar('Could not start chat: $e');
                                              }
                                            }
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x3310B981),
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: isSubmitting
                                        ? const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.near_me_rounded, color: Colors.white, size: 16),
                                              SizedBox(width: 6),
                                              Text(
                                                'Start Chat',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showConfigureCredentialsDialog() {
    final initialPhoneId = (_connectionInfo?.phoneNumberId.isNotEmpty == true)
        ? _connectionInfo!.phoneNumberId
        : _db.whatsAppPhoneId;
    final initialPhoneNum = (_connectionInfo?.phoneNumber.isNotEmpty == true)
        ? _connectionInfo!.phoneNumber
        : _db.whatsAppPhoneNumber;
    final initialToken = (_connectionInfo?.accessToken.isNotEmpty == true)
        ? _connectionInfo!.accessToken
        : _db.whatsAppAccessToken;

    final phoneIdCtrl = TextEditingController(text: initialPhoneId);
    final phoneNumCtrl = TextEditingController(text: initialPhoneNum);
    final tokenCtrl = TextEditingController(text: initialToken);
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⚠️ Helper hint banner
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Get your Phone Number ID from:\nmeta.com → WhatsApp → API Setup\n(It is a ~15-digit number, not your phone number)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
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
        resizeToAvoidBottomInset: false,
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
    return Container(
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column: Modern WhatsApp Chat List
          SizedBox(
            width: 380,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: _buildWhatsAppMobileChatList(isEmbedded: true),
            ),
          ),
          // Right Column: Active Conversation or Desktop Empty State
          Expanded(
            child: _selectedChat != null
                ? _buildChatConversationView(isMobile: false)
                : _buildDesktopEmptyChatState(),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredPhoneLayout(BoxConstraints constraints) {
    if (_selectedChat != null) {
      return _buildChatConversationView(isMobile: true);
    }
    return _buildWhatsAppMobileChatList(isEmbedded: false);
  }

  Widget _buildDesktopEmptyChatState() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(28),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FDF2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14059669), blurRadius: 18, offset: Offset(0, 6)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.chat_bubble_rounded, size: 44, color: Color(0xFF00A884)),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Apna POS WhatsApp Live Chat',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send and receive real-time messages with your customers via Meta Cloud API.\nSelect any chat from the left panel or start a new conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showNewChatDialog,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Start New Customer Chat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// WhatsApp Mobile View: Chat List Screen matching uploaded reference image
  Widget _buildWhatsAppMobileChatList({bool isEmbedded = false}) {
    final int unreadTotal = _chats.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Column(
      children: [
        // 1. WhatsApp Top Header (Bold green WhatsApp title, Circular Neumorphic Camera & 3-Dots Menu)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
          child: Row(
            children: [
              const Text(
                'WhatsApp',
                style: TextStyle(
                  color: Color(0xFF059669), // Vivid WhatsApp emerald green
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // Circular Neumorphic Camera Button
              _buildNeumorphicHeaderButton(
                icon: Icons.camera_alt_outlined,
                tooltip: 'Camera',
                onTap: () {},
              ),
              const SizedBox(width: 8),
              // Circular Neumorphic 3-Dots Menu Button (Visible text & pure white card)
              _buildNeumorphicMenuButton(),
            ],
          ),
        ),

        // 2. Search Bar with iridescent Meta AI gradient ring in floating neumorphic pill
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: Color(0x80FFFFFF),
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildMetaAiRing(),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                        _chatService.getChats(search: val).then((chats) {
                          if (mounted) setState(() => _chats = chats);
                        });
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Ask Meta AI or Search',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 15, color: Color(0xFF64748B)),
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

        // 3. Category Filter Pills: All (selected lime/mint glow), Unread, Groups (floating white pills)
        _buildFilterPills(unreadTotal),

        // 4. Chat List Body with Circular Green FAB
        Expanded(
          child: Stack(
            children: [
              _buildChatListColumn(),

              // Circular Emerald Green WhatsApp Floating Action Button (FAB)
              Positioned(
                bottom: 16,
                right: 18,
                child: GestureDetector(
                  onTap: _showNewChatDialog,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x4410B981),
                          offset: Offset(0, 5),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 5. WhatsApp Bottom Navigation Bar (Chats, Updates, Communities, Calls)
        if (!isEmbedded) _buildWhatsAppBottomNavBar(unreadTotal),
      ],
    );
  }

  /// Circular neumorphic button for Camera / Header action
  Widget _buildNeumorphicHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0x80FFFFFF),
                blurRadius: 4,
                offset: Offset(-1, -1),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
          ),
        ),
      ),
    );
  }

  /// Circular neumorphic button for 3-dots popup menu (Pure white background + dark slate visible text)
  Widget _buildNeumorphicMenuButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0x80FFFFFF),
            blurRadius: 4,
            offset: Offset(-1, -1),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          popupMenuTheme: const PopupMenuThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 19, color: Color(0xFF1E293B)),
          padding: EdgeInsets.zero,
          tooltip: 'More options',
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: const Color(0x33000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          onSelected: (val) {
            if (val == 'new_chat') _showNewChatDialog();
            if (val == 'credentials') _showConfigureCredentialsDialog();
            if (val == 'refresh') _loadConnectionAndChats();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'new_chat',
              child: Row(
                children: const [
                  Icon(Icons.person_add_outlined, size: 17, color: Color(0xFF0F172A)),
                  SizedBox(width: 10),
                  Text(
                    'New chat',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: const [
                  Icon(Icons.refresh_rounded, size: 17, color: Color(0xFF0F172A)),
                  SizedBox(width: 10),
                  Text(
                    'Refresh chats',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'credentials',
              child: Row(
                children: const [
                  Icon(Icons.tune_rounded, size: 17, color: Color(0xFF0F172A)),
                  SizedBox(width: 10),
                  Text(
                    'Settings / Credentials',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
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

  /// Iridescent Meta AI Ring icon matching official WhatsApp UI
  Widget _buildMetaAiRing() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF0064E0),
            Color(0xFF00B2FE),
            Color(0xFF9333EA),
            Color(0xFFEC4899),
            Color(0xFF0064E0),
          ],
        ),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Category Filter Pills row (All, Unread, Groups)
  Widget _buildFilterPills(int unreadTotal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
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
    );
  }

  /// Filter pill chip (All with lime-mint glow, Unread and Groups as floating white pills)
  Widget _buildFilterPill(String title, {int badgeCount = 0}) {
    final bool isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? null : Colors.white,
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF86EFAC), Color(0xFFA7F3D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          border: isSelected ? null : Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            if (isSelected)
              const BoxShadow(
                color: Color(0x3310B981),
                blurRadius: 8,
                offset: Offset(0, 3),
              )
            else
              const BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (badgeCount > 0 && !isSelected) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
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

  /// WhatsApp 4-Tab Bottom Navigation Bar (Elevated curved container matching reference UI)
  Widget _buildWhatsAppBottomNavBar(int unreadCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 16,
            offset: Offset(0, -3),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(
            index: 0,
            label: 'Chats',
            icon: Icons.chat_bubble_rounded,
            badgeCount: unreadCount > 0 ? unreadCount : 1,
            isSelected: _selectedBottomNavIndex == 0,
          ),
          _buildBottomNavItem(
            index: 1,
            label: 'Updates',
            icon: Icons.donut_large_rounded,
            isSelected: _selectedBottomNavIndex == 1,
          ),
          _buildBottomNavItem(
            index: 2,
            label: 'Communities',
            icon: Icons.groups_rounded,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFBBF7D0) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
                ),
                if (badgeCount > 0 && isSelected)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF047857),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
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
              color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF059669), strokeWidth: 2.5));
    }

    if (filtered.isEmpty) {
      return _buildEmptyChatList();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final chat = filtered[index];
        return _buildChatCard(chat);
      },
    );
  }

  /// Floating Neumorphic Chat Card matching reference image
  Widget _buildChatCard(WhatsAppChatModel chat) {
    final isSelected = _selectedChat != null && _selectedChat!.id == chat.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectChat(chat),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Soft avatar circle
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      chat.avatarInitials,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isSelected ? const Color(0xFF065F46) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Chat Info
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
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTimestamp(chat.lastMessageAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                              color: chat.unreadCount > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (chat.lastMessageDirection == 'OUTGOING') ...[
                            const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              chat.lastMessage.isNotEmpty ? chat.lastMessage : 'No messages',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: chat.unreadCount > 0 ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (chat.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              child: Text(
                                '${chat.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
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
      ),
    );
  }

  Widget _buildEmptyChatList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(Icons.mark_chat_unread_outlined, size: 28, color: Color(0xFF059669)),
              ),
              const SizedBox(height: 12),
              const Text(
                'No chats yet',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Customer replies will appear here in real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _showNewChatDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildChatConversationView({bool isMobile = false}) {
    if (_selectedChat == null) return const SizedBox();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    if (bottomInset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    return Column(
      children: [
        // 1. Redesigned Conversation Header (Matching Reference Image)
        _buildConversationHeader(),

        // 2. Message List with "Today" pill and Neumorphic Bubble styling
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFAFCFA),
                  Color(0xFFF1FAF5),
                  Color(0xFFF8FAFC),
                ],
              ),
            ),
            child: Column(
              children: [
                _buildDateDivider(),
                Expanded(
                  child: _isLoadingMessages
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669), strokeWidth: 2.5))
                      : _messages.isEmpty
                          ? Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3)),
                                  ],
                                ),
                                child: const Text(
                                  'No messages yet',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageBubble(_messages[index]);
                              },
                            ),
                ),
              ],
            ),
          ),
        ),

        // 3. Bottom Input Bar: Only plus, text box, and send button lift up on keyboard open, and smoothly drop down on keyboard close
        AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            color: Colors.transparent,
            child: _buildConversationInputBar(),
          ),
        ),
      ],
    );
  }

  /// Conversation screen header matching uploaded reference image (Call and Video call buttons removed per request)
  Widget _buildConversationHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      color: Colors.transparent,
      child: Row(
        children: [
          // Circular Back Button
          _buildNeumorphicCircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back to chats',
            onTap: () => setState(() => _selectedChat = null),
          ),
          const SizedBox(width: 8),

          // Contact Avatar
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _selectedChat!.avatarInitials,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Contact Name & Phone / Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedChat!.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _selectedChat!.customerPhone.startsWith('+')
                            ? _selectedChat!.customerPhone
                            : '+${_selectedChat!.customerPhone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3-Dots Menu Button (Call and Video buttons removed per user instruction)
          _buildConversationMenuButton(),
        ],
      ),
    );
  }

  /// 3-Dots Menu button inside conversation view with visible white card and dark text
  Widget _buildConversationMenuButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0x80FFFFFF),
            blurRadius: 4,
            offset: Offset(-1, -1),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          popupMenuTheme: const PopupMenuThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 19, color: Color(0xFF1E293B)),
          padding: EdgeInsets.zero,
          tooltip: 'Chat options',
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: const Color(0x33000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          onSelected: (val) {
            if (val == 'refresh') _loadMessages(_selectedChat!.id);
            if (val == 'new_chat') _showNewChatDialog();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: const [
                  Icon(Icons.refresh_rounded, size: 17, color: Color(0xFF0F172A)),
                  SizedBox(width: 10),
                  Text(
                    'Refresh messages',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'new_chat',
              child: Row(
                children: const [
                  Icon(Icons.person_add_outlined, size: 17, color: Color(0xFF0F172A)),
                  SizedBox(width: 10),
                  Text(
                    'New chat',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
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

  Widget _buildNeumorphicCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0x80FFFFFF),
                blurRadius: 4,
                offset: Offset(-1, -1),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
          ),
        ),
      ),
    );
  }

  /// Floating "Today" date divider pill
  Widget _buildDateDivider() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'Today',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }



  /// Redesigned input bar with plus button, pill input field with emoji & paperclip, and green send button
  Widget _buildConversationInputBar() {
    return Row(
      children: [
        // Plus (+) Attachment Button
        GestureDetector(
          onTap: _showAttachmentSheet,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0E000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: Color(0x80FFFFFF),
                  blurRadius: 4,
                  offset: Offset(-1, -1),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(Icons.add_rounded, color: Color(0xFF0F172A), size: 22),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Elongated White Pill Input Container with Smiley and Paperclip inside
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: Color(0x80FFFFFF),
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(fontSize: 14.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.sentiment_satisfied_rounded, size: 20, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showAttachmentSheet,
                  child: const Icon(Icons.attach_file_rounded, size: 20, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Vibrant Green Circular Send Button
        GestureDetector(
          onTap: _isSending ? null : _sendMessage,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x4010B981),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  void _showAttachmentSheet() {
    if (_selectedChat == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Send WhatsApp Image',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF3E8FF),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.link_rounded,
                  label: 'Image URL',
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showImageUrlDialog();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        _showImagePreviewDialog(
          imagePath: pickedFile.path,
          pickedBytes: bytes,
          fileName: pickedFile.name,
          isLocal: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Could not pick image: $e');
      }
    }
  }

  void _showImageUrlDialog() {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send Image URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: urlCtrl,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.jpg',
            hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx);
                _showImagePreviewDialog(
                  imagePath: url,
                  pickedBytes: null,
                  fileName: null,
                  isLocal: false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Preview', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showImagePreviewDialog({
    required String imagePath,
    Uint8List? pickedBytes,
    String? fileName,
    required bool isLocal,
  }) {
    final captionCtrl = TextEditingController();
    bool isSendingImage = false;

    showDialog(
      context: context,
      builder: (previewCtx) => StatefulBuilder(
        builder: (context, setPreviewState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.image_rounded, size: 15, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Send Image',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'WhatsApp Media',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(previewCtx),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Image Thumbnail Preview with clean wrapped rounded frame
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                    ),
                    child: pickedBytes != null && pickedBytes.isNotEmpty
                        ? Image.memory(
                            pickedBytes,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image_rounded, size: 36, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : (isLocal && !kIsWeb
                            ? Image.file(
                                File(imagePath),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image_rounded, size: 36, color: Color(0xFF94A3B8)),
                                ),
                              )
                            : Image.network(
                                imagePath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image_rounded, size: 36, color: Color(0xFF94A3B8)),
                                ),
                              )),
                  ),
                ),
                const SizedBox(height: 10),

                // Caption Field (compact, smaller texts)
                TextField(
                  controller: captionCtrl,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Add a caption... (optional)',
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    prefixIcon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF94A3B8)),
                    prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF059669), width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Action Buttons (Cancel / Send)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: isSendingImage ? null : () => Navigator.pop(previewCtx),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 0.8),
                            backgroundColor: const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: isSendingImage
                              ? null
                              : () async {
                                  setPreviewState(() => isSendingImage = true);
                                  try {
                                    final caption = captionCtrl.text.trim();
                                    String finalMediaUrl = imagePath;

                                    // 1. If local image, upload first to server storage to obtain public URL
                                    if (isLocal) {
                                      final uploadedUrl = await _chatService.uploadChatImage(
                                        filePath: imagePath,
                                        fileBytes: pickedBytes,
                                        fileName: fileName,
                                      );
                                      if (uploadedUrl == null || uploadedUrl.isEmpty) {
                                        throw Exception('Could not upload image to server storage.');
                                      }
                                      finalMediaUrl = uploadedUrl;
                                    }

                                    // 2. Send outgoing WhatsApp message with the verified media URL
                                    final msg = await _chatService.sendMessage(
                                      _selectedChat!.id,
                                      caption,
                                      messageType: 'image',
                                      mediaUrl: finalMediaUrl,
                                    );

                                    if (previewCtx.mounted) Navigator.pop(previewCtx);
                                    if (msg != null && mounted) {
                                      setState(() {
                                        _messages.add(msg);
                                      });
                                      _scrollToBottom();
                                    }
                                  } catch (e) {
                                    setPreviewState(() => isSendingImage = false);
                                    if (mounted) _showErrorSnackBar('Failed to send image: $e');
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 1.5,
                            shadowColor: const Color(0x33059669),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: isSendingImage
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.8),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Sending...',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.send_rounded, size: 13, color: Colors.white),
                                    SizedBox(width: 5),
                                    Text(
                                      'Send',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveImageUrl(String mediaUrl) {
    if (mediaUrl.isEmpty) return '';
    if (mediaUrl.startsWith('/')) {
      final base = ApiEndpoints.baseUrl.replaceAll('/api/v1', '');
      return '$base$mediaUrl';
    }
    return mediaUrl;
  }

  void _openFullScreenImage(String mediaUrl, [String caption = '']) {
    if (mediaUrl.isEmpty) return;
    final resolvedUrl = _resolveImageUrl(mediaUrl);
    final isLocalFile = !kIsWeb && !resolvedUrl.startsWith('http://') && !resolvedUrl.startsWith('https://');
    final displayCaption = (caption == '[Photo]' || caption == '📷 Photo' || caption == '📷 Image') ? '' : caption;

    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Full Screen Image',
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                // Interactive pinch-to-zoom and pan image
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    child: isLocalFile
                        ? Image.file(
                            File(resolvedUrl),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image_rounded,
                              size: 64,
                              color: Colors.white54,
                            ),
                          )
                        : Image.network(
                            resolvedUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF10B981),
                                  strokeWidth: 2.5,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image_rounded,
                              size: 64,
                              color: Colors.white54,
                            ),
                          ),
                  ),
                ),

                // Top bar with close button
                Positioned(
                  top: 12,
                  right: 14,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      tooltip: 'Close full screen',
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ),
                ),

                // Bottom caption if present
                if (displayCaption.isNotEmpty)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        displayCaption,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBubbleImage(String mediaUrl) {
    if (mediaUrl.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        padding: const EdgeInsets.all(16),
        child: const Icon(Icons.image_rounded, size: 40, color: Color(0xFF94A3B8)),
      );
    }
    final resolvedUrl = _resolveImageUrl(mediaUrl);
    if (!kIsWeb && !resolvedUrl.startsWith('http://') && !resolvedUrl.startsWith('https://')) {
      final file = File(resolvedUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image_rounded, size: 30, color: Colors.grey),
        );
      }
    }
    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 120,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFF1F5F9),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.broken_image_rounded, size: 28, color: Color(0xFF94A3B8)),
            SizedBox(height: 4),
            Text('Image attachment', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  /// Word-adaptive message bubble: bubble hugs short single-line messages tightly
  /// and wraps multiline messages naturally up to max width without artificial spacers.
  Widget _buildMessageBubble(WhatsAppMessageModel msg) {
    final isOutgoing = msg.isOutgoing;
    final screenWidth = MediaQuery.of(context).size.width;
    final hasMedia = msg.messageType == 'image' || msg.mediaUrl.isNotEmpty;
    final isSingleShortLine = !hasMedia && !msg.text.contains('\n') && msg.text.length <= 26;
    final hasError = msg.status.toUpperCase() == 'FAILED' || (msg.error != null && msg.error!.isNotEmpty);

    final double maxBubbleWidth = (screenWidth >= 900
        ? 520.0
        : (screenWidth >= 680 ? 420.0 : screenWidth * 0.78)).clamp(220.0, 560.0);

    final timeWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _formatTime(msg.timestamp),
          style: TextStyle(
            fontSize: 10.5,
            color: isOutgoing ? const Color(0xFF475569) : const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isOutgoing) ...[
          const SizedBox(width: 3.5),
          _buildStatusIcon(msg.status),
        ],
      ],
    );

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxBubbleWidth,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3.5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isOutgoing ? const Color(0xFFD9FDD3) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
              bottomRight: Radius.circular(isOutgoing ? 4 : 16),
            ),
            border: Border.all(
              color: isOutgoing
                  ? const Color(0xFFBBF7D0).withValues(alpha: 0.8)
                  : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isOutgoing ? const Color(0x0C000000) : const Color(0x0E000000),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: isSingleShortLine && !hasError
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        msg.text,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A),
                          height: 1.4,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: timeWidget,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasMedia) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220, minWidth: 180),
                          child: GestureDetector(
                            onTap: msg.mediaUrl.isNotEmpty
                                ? () => _openFullScreenImage(msg.mediaUrl, msg.text)
                                : null,
                            child: MouseRegion(
                              cursor: msg.mediaUrl.isNotEmpty
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              child: _buildBubbleImage(msg.mediaUrl),
                            ),
                          ),
                        ),
                      ),
                      if (msg.text.isNotEmpty) const SizedBox(height: 6),
                    ],
                    if (msg.text.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          msg.text,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                            height: 1.4,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    const SizedBox(height: 3),
                    timeWidget,
                    if (hasError && msg.error != null && msg.error!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFFDC2626)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                msg.error!,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'READ':
        return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF38BDF8));
      case 'DELIVERED':
        return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF94A3B8));
      case 'SENT':
        return const Icon(Icons.check_rounded, size: 14, color: Color(0xFF94A3B8));
      case 'FAILED':
        return const Icon(Icons.error_outline_rounded, size: 14, color: Colors.red);
      default:
        return const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8));
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
