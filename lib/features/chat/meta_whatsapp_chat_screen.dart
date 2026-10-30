import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/whatsapp_chat_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/widgets/glass_company_name_badge.dart';
import '../../core/widgets/connection_status_badge.dart';
import 'widgets/whatsapp_template_picker_dialog.dart';

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

  /// Tracks the currently open conversation ID globally so notifications are suppressed while reading
  static String? activeChatId;

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
  bool _useAndroidPhoneMockup = true; // Authentic Android Phone Mockup frame for chat screen

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  double _previousBottomInset = 0.0;
  int? _unreadMarkerIndex;

  Timer? _pollingTimer;
  Timer? _searchDebounce;
  StreamSubscription<WhatsAppMessageModel>? _messageSub;
  StreamSubscription<List<WhatsAppChatModel>>? _chatsSub;

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
      if (_selectedChat != null && (_selectedChat!.id == msg.chatId || _isMatchingPhone(_selectedChat!.customerPhone, msg.customerPhone))) {
        final alreadyPresent = _messages.any((m) =>
            m.id == msg.id ||
            (m.whatsappMessageId.isNotEmpty && m.whatsappMessageId == msg.whatsappMessageId));
        if (!alreadyPresent) {
          setState(() {
            _messages.add(msg);
            _selectedChat = _selectedChat!.copyWith(
              lastMessage: msg.messageType == 'image' ? '📷 Photo' : (msg.text.isNotEmpty ? msg.text : 'New message'),
              lastMessageAt: msg.timestamp,
              lastMessageDirection: msg.direction,
            );
            final idx = _chats.indexWhere((c) => c.id == _selectedChat!.id);
            if (idx != -1) {
              _chats[idx] = _selectedChat!;
            }
          });
          _scrollToBottom();
          // Real-time audio feedback for incoming chat message
          SoundService.playNotificationSound();
          // Silently mark as read in background
          _chatService.markRead(msg.chatId);
        }
      } else {
        final idx = _chats.indexWhere((c) => c.id == msg.chatId || _isMatchingPhone(c.customerPhone, msg.customerPhone));
        if (idx != -1) {
          setState(() {
            _chats[idx] = _chats[idx].copyWith(
              lastMessage: msg.messageType == 'image' ? '📷 Photo' : (msg.text.isNotEmpty ? msg.text : 'New message'),
              lastMessageAt: msg.timestamp,
              lastMessageDirection: msg.direction,
              unreadCount: msg.isIncoming ? _chats[idx].unreadCount + 1 : _chats[idx].unreadCount,
            );
            final item = _chats.removeAt(idx);
            _chats.insert(0, item);
          });
        }
      }
    });

    _chatsSub = _chatService.onChatsUpdated.listen((updatedChats) {
      if (!mounted) return;
      setState(() {
        _chats = updatedChats;
        if (_selectedChat != null) {
          final found = updatedChats.where((c) => c.id == _selectedChat!.id || _isMatchingPhone(c.customerPhone, _selectedChat!.customerPhone)).firstOrNull;
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

    // Fast fallback polling every 2 seconds for WhatsApp-grade real-time responsiveness
    if (widget.enablePolling) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (mounted) {
          _refreshSilently();
        }
      });
    }
  }

  @override
  void dispose() {
    MetaWhatsAppChatScreen.activeChatId = null;
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
      // Avoid background UI rebuilds while merchant is actively typing!
      if (_messageFocusNode.hasFocus || _messageController.text.isNotEmpty) return;

      final freshChats = await _chatService.getChats(search: _searchQuery);
      if (!mounted) return;

      // Smart diff check: only trigger setState if chat list actually changed
      bool chatsChanged = freshChats.length != _chats.length;
      if (!chatsChanged) {
        for (int i = 0; i < freshChats.length; i++) {
          if (freshChats[i].id != _chats[i].id ||
              freshChats[i].unreadCount != _chats[i].unreadCount ||
              freshChats[i].lastMessageAt != _chats[i].lastMessageAt) {
            chatsChanged = true;
            break;
          }
        }
      }

      if (chatsChanged) {
        setState(() => _chats = freshChats);
      }

      if (_selectedChat != null) {
        final updatedChat = freshChats.where((c) => c.id == _selectedChat!.id).firstOrNull;
        if (updatedChat != null && updatedChat.lastMessageAt != _selectedChat!.lastMessageAt) {
          _selectedChat = updatedChat;
        }

        final msgs = await _chatService.getChatMessages(_selectedChat!.id, forceRefresh: true);
        if (!mounted) return;

        final bool hasChanged = msgs.length != _messages.length ||
            (msgs.isNotEmpty && _messages.isNotEmpty && msgs.last.id != _messages.last.id) ||
            (msgs.isNotEmpty && _messages.isNotEmpty && msgs.last.status != _messages.last.status);

        if (hasChanged) {
          setState(() {
            _messages = msgs;
            if (msgs.isNotEmpty) {
              final latest = msgs.last;
              _selectedChat = _selectedChat!.copyWith(
                lastMessage: latest.messageType == 'image'
                    ? '📷 Photo'
                    : (latest.text.isNotEmpty ? latest.text : 'New message'),
                lastMessageAt: latest.timestamp,
                lastMessageDirection: latest.direction,
              );
              final idx = _chats.indexWhere((c) => c.id == _selectedChat!.id);
              if (idx != -1) {
                _chats[idx] = _selectedChat!;
              }
            }
          });
          // Only scroll down if merchant is already viewing recent messages
          if (_scrollController.hasClients &&
              _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
            _scrollToBottom();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _selectChat(WhatsAppChatModel chat) async {
    MetaWhatsAppChatScreen.activeChatId = chat.id;
    final int unreadCountAtOpen = chat.unreadCount;

    // Instant synchronous 0ms render from memory cache or last message preview
    final cachedMsgs = _chatService.getCachedMessages(chat.id);
    final initialMsgs = (cachedMsgs != null && cachedMsgs.isNotEmpty)
        ? List<WhatsAppMessageModel>.from(cachedMsgs)
        : (chat.lastMessage.isNotEmpty
            ? [
                WhatsAppMessageModel(
                  id: 'init_${chat.id}',
                  chatId: chat.id,
                  customerPhone: chat.customerPhone,
                  direction: chat.lastMessageDirection,
                  text: chat.lastMessage,
                  status: 'DELIVERED',
                  timestamp: chat.lastMessageAt,
                ),
              ]
            : <WhatsAppMessageModel>[]);

    setState(() {
      _selectedChat = chat;
      _messages = initialMsgs;
      _isLoadingMessages = initialMsgs.isEmpty;
    });

    if (initialMsgs.isNotEmpty) {
      _scrollToBottom(immediate: true);
    }

    // Background silent DP sync if chat currently has no avatar
    if (_resolveChatAvatar(chat) == null || _resolveChatAvatar(chat)!.isEmpty) {
      _chatService.syncChatDp(chat.id).then((resolvedAvatar) {
        if (resolvedAvatar != null && resolvedAvatar.isNotEmpty && mounted) {
          setState(() {
            if (_selectedChat?.id == chat.id) {
              _selectedChat = _selectedChat!.copyWith(avatarUrl: resolvedAvatar);
            }
            final idx = _chats.indexWhere((c) => c.id == chat.id);
            if (idx != -1) {
              _chats[idx] = _chats[idx].copyWith(avatarUrl: resolvedAvatar);
            }
          });
        }
      }).catchError((_) {});
    }

    try {
      // Fetch fresh messages from server so latest messages (e.g. 2:20 AM Checkout / cart) are always synchronized
      final freshMsgs = await _chatService.getChatMessages(chat.id, forceRefresh: true);
      if (mounted) {
        final effectiveMsgs = freshMsgs.isNotEmpty ? freshMsgs : _messages;

        setState(() {
          _messages = effectiveMsgs;
          _isLoadingMessages = false;

          // Keep selected chat and chat list preview strictly up to date with the newest message in the conversation
          if (effectiveMsgs.isNotEmpty) {
            final latest = effectiveMsgs.last;
            final updatedChat = chat.copyWith(
              lastMessage: latest.messageType == 'image'
                  ? '📷 Photo'
                  : (latest.text.isNotEmpty ? latest.text : 'New message'),
              lastMessageAt: latest.timestamp,
              lastMessageDirection: latest.direction,
              unreadCount: 0,
            );
            _selectedChat = updatedChat;
            final idx = _chats.indexWhere((c) => c.id == chat.id);
            if (idx != -1) {
              _chats[idx] = updatedChat;
            }
          }
        });

        // Smart scroll algorithm:
        // If there were unread messages, scroll smoothly to the first unread message so the merchant sees what was sent!
        // If all messages were already read, scroll smoothly to the bottom to show the latest message.
        int? unreadMarker;
        if (unreadCountAtOpen > 0 && effectiveMsgs.isNotEmpty) {
          unreadMarker = (effectiveMsgs.length - unreadCountAtOpen).clamp(0, effectiveMsgs.length - 1);
          _scrollToIndex(unreadMarker);
        } else {
          _scrollToBottom();
        }
        _unreadMarkerIndex = unreadMarker;

        // Notify backend that conversation has been read
        _chatService.markRead(chat.id);

        // Clear unread badge in list locally
        final index = _chats.indexWhere((c) => c.id == chat.id);
        if (index != -1 && _chats[index].unreadCount > 0) {
          setState(() {
            _chats[index] = _chats[index].copyWith(unreadCount: 0);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  void _scrollToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || _messages.isEmpty) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;
      final ratio = (index / _messages.length).clamp(0.0, 1.0);
      final target = (ratio * maxExtent).clamp(0.0, maxExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Checks whether phone numbers refer to the same customer contact
  bool _isMatchingPhone(String a, String b) {
    final cleanA = a.replaceAll(RegExp(r'\D'), '');
    final cleanB = b.replaceAll(RegExp(r'\D'), '');
    if (cleanA.isEmpty || cleanB.isEmpty) return false;
    if (cleanA == cleanB) return true;
    final last10A = cleanA.length >= 10 ? cleanA.substring(cleanA.length - 10) : cleanA;
    final last10B = cleanB.length >= 10 ? cleanB.substring(cleanB.length - 10) : cleanB;
    return last10A == last10B;
  }

  /// Checks whether the Meta 24-hour customer service window is OPEN for a given chat
  bool _isChat24HourWindowActive(WhatsAppChatModel chat, [List<WhatsAppMessageModel>? msgs]) {
    // 1. Check messages in current conversation
    if (msgs != null && msgs.isNotEmpty) {
      final incoming = msgs.reversed.where((m) => m.isIncoming).firstOrNull;
      if (incoming != null) {
        final diff = DateTime.now().difference(incoming.timestamp.toLocal());
        if (diff.isNegative) return true; // Clock skew protection
        return diff < const Duration(hours: 24);
      }
    }

    // 2. Check cached messages in memory
    final cached = _chatService.getCachedMessages(chat.id);
    if (cached != null && cached.isNotEmpty) {
      final incoming = cached.reversed.where((m) => m.isIncoming).firstOrNull;
      if (incoming != null) {
        final diff = DateTime.now().difference(incoming.timestamp.toLocal());
        if (diff.isNegative) return true;
        return diff < const Duration(hours: 24);
      }
    }

    // 3. Check chat.lastIncomingAt (persisted across AI/outgoing bot replies!)
    if (chat.lastIncomingAt != null) {
      final diff = DateTime.now().difference(chat.lastIncomingAt!.toLocal());
      if (diff.isNegative) return true;
      return diff < const Duration(hours: 24);
    }

    // 4. Check backend calculated status if available
    if (chat.is24HourWindowActive != null) {
      return chat.is24HourWindowActive!;
    }

    // 5. Fall back to chat model's lastMessageDirection & lastMessageAt
    if (chat.lastMessageDirection.toUpperCase() == 'INCOMING') {
      final diff = DateTime.now().difference(chat.lastMessageAt.toLocal());
      if (diff.isNegative) return true;
      return diff < const Duration(hours: 24);
    }

    return false;
  }

  bool get _is24HourWindowActive {
    if (_selectedChat == null) return true;
    return _isChat24HourWindowActive(_selectedChat!, _messages);
  }

  bool get _is24HourWindowClosed => !_is24HourWindowActive;

  void _openTemplatePicker() {
    if (_selectedChat == null) return;
    final bName = _db.restaurant?.name ?? _db.currentUser?.companyName ?? 'Our Store';
    WhatsAppTemplatePickerDialog.show(
      context: context,
      chat: _selectedChat!,
      businessName: bName,
      onTemplateSent: (sentMsg) {
        if (mounted) {
          setState(() {
            _messages.add(sentMsg);
          });
          _scrollToBottom();
          _showSuccessSnackBar('Approved Meta template dispatched successfully!');
        }
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
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

  void _scrollToBottom({bool immediate = false}) {
    void doScroll() {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;
      if (immediate) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(
          max + 120,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doScroll();
      Future.delayed(const Duration(milliseconds: 60), doScroll);
      Future.delayed(const Duration(milliseconds: 180), doScroll);
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

  bool _isMetaSecretError(String errorStr) {
    final lower = errorStr.toLowerCase();
    return lower.contains('appsecret_proof') ||
        lower.contains('app secret') ||
        lower.contains('require app secret');
  }

  bool _is24HourWindowError(String errorStr) {
    final lower = errorStr.toLowerCase();
    return lower.contains('24-hour') || lower.contains('24 hour') || lower.contains('131047');
  }

  void _showErrorSnackBar(String message) {
    final isPhoneIdError = _isMetaPhoneIdError(message);
    final isSecretError = _isMetaSecretError(message);
    final is24HrError = _is24HourWindowError(message);

    String displayMsg = message;
    if (isSecretError) {
      displayMsg = "Meta 'appsecret_proof' required: Provide App Secret in settings or turn OFF 'Require App Secret' in Meta Console.";
    } else if (isPhoneIdError) {
      displayMsg = 'Invalid Phone Number ID. Please update your Meta API credentials.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayMsg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: is24HrError
            ? SnackBarAction(
                label: 'Send Template',
                textColor: Colors.amberAccent,
                onPressed: _openTemplatePicker,
              )
            : (isPhoneIdError || isSecretError)
                ? SnackBarAction(
                    label: 'Fix',
                    textColor: Colors.white,
                    onPressed: _showConfigureCredentialsDialog,
                  )
                : null,
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: (isPhoneIdError || isSecretError || is24HrError)
            ? const Duration(seconds: 7)
            : const Duration(seconds: 4),
      ),
    );
  }

  /// Redesigned New WhatsApp Chat Bottom Sheet Modal matching reference image with Meta Template Support & High-Contrast Typography
  void _showNewChatDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final msgCtrl = TextEditingController(text: 'Hello! How can we help you today?');
    bool isSubmitting = false;
    WhatsAppTemplateModel? selectedTemplate;
    List<String> selectedTemplateParams = [];
    String? selectedTemplateLang;

    void openTemplatePickerModal(StateSetter setSheetState) {
      final bName = _db.restaurant?.name ?? _db.currentUser?.companyName ?? 'Our Store';
      final phone = phoneCtrl.text.trim();
      final name = nameCtrl.text.trim();

      WhatsAppTemplatePickerDialog.pick(
        context: context,
        customerPhone: phone.isNotEmpty ? phone : null,
        customerName: name.isNotEmpty ? name : null,
        businessName: bName,
        onSelected: (renderedText, template, parameters) {
          setSheetState(() {
            selectedTemplate = template;
            selectedTemplateParams = parameters;
            selectedTemplateLang = template.language;
            msgCtrl.text = renderedText;
          });
        },
      );
    }

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

                          // 2. Header Row: Squircle App Icon + Title + Subtitle
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
                                        fontSize: 11,
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Quick Customer Picker from Store Customers (High-Contrast Text)
                          if (_db.customers.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Select Store Customer',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${_db.customers.length} saved',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
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
                                    label: Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A), // High contrast deep navy text
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 0.8),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    onPressed: () {
                                      phoneCtrl.text = cust.phone;
                                      nameCtrl.text = cust.name;
                                      setSheetState(() {});
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
                                  color: Color(0xFF0F172A),
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
                                        fontWeight: FontWeight.w800,
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
                                      fontWeight: FontWeight.w700,
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
                              color: Color(0xFF0F172A),
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
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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

                          // 5. Initial WhatsApp Message Field with Character Counter & Approved Template Picker
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Flexible(
                                      child: Text(
                                        'Initial WhatsApp Message',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
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
                              ),
                              const SizedBox(width: 8),
                              // Header Action Pill to Pick Approved Template
                              InkWell(
                                onTap: () => openTemplatePickerModal(setSheetState),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: selectedTemplate != null ? const Color(0xFFDCFCE7) : const Color(0xFFE8FDF2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedTemplate != null ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                                      width: selectedTemplate != null ? 1.2 : 0.9,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.dashboard_customize_rounded,
                                        size: 13,
                                        color: selectedTemplate != null ? const Color(0xFF059669) : const Color(0xFF00A884),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        selectedTemplate != null ? 'Template' : 'Template',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF065F46),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Selected Template Confirmation Banner
                          if (selectedTemplate != null) ...[
                            Container(
                              margin: const EdgeInsets.only(top: 6, bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF065F46)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Meta Template: ${selectedTemplate!.name} (${selectedTemplate!.category})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Tooltip(
                                    message: 'Remove template and use custom text',
                                    child: GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          selectedTemplate = null;
                                          selectedTemplateParams = [];
                                          selectedTemplateLang = null;
                                          msgCtrl.text = 'Hello! How can we help you today?';
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(2.0),
                                        child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF065F46)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 6),
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: selectedTemplate != null ? const Color(0xFFF0FDF4) : const Color(0xFFFAFDFA),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selectedTemplate != null ? const Color(0xFF10B981) : const Color(0xFFA7F3D0),
                                    width: 1.2,
                                  ),
                                ),
                                padding: const EdgeInsets.fromLTRB(14, 12, 44, 8),
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (selectedTemplate != null)
                                          const Text(
                                            'Meta Template (24h Window Bypass)',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: Color(0xFF059669),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        else
                                          const SizedBox.shrink(),
                                        Text(
                                          '${msgCtrl.text.length}/1024',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Dedicated Circular (+) Button matching user's red circle!
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Tooltip(
                                  message: 'Send Approved Meta Template',
                                  child: InkWell(
                                    onTap: () => openTemplatePickerModal(setSheetState),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8FDF2),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF00A884), width: 1.2),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x1A00A884),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.add, size: 18, color: Color(0xFF00A884)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
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
                                              templateName: selectedTemplate?.name,
                                              languageCode: selectedTemplateLang ?? selectedTemplate?.language,
                                              parameters: selectedTemplate != null ? selectedTemplateParams : null,
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
    final initialSecret = (_connectionInfo?.appSecret.isNotEmpty == true)
        ? _connectionInfo!.appSecret
        : '';

    final phoneIdCtrl = TextEditingController(text: initialPhoneId);
    final phoneNumCtrl = TextEditingController(text: initialPhoneNum);
    final tokenCtrl = TextEditingController(text: initialToken);
    final secretCtrl = TextEditingController(text: initialSecret);
    bool isSaving = false;
    bool obscureToken = true;
    bool obscureSecret = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2A000000),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Icon, Title and Close Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3325D366),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Meta API Credentials',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Configure WhatsApp Cloud API connection',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(dialogCtx),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Helper Hint Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pre-configured server integration is active. You do not need to fill access tokens or app secrets.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // WhatsApp Mobile Number Field
                  const Text(
                    'WhatsApp Business Number',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneNumCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. +91 73036 32949',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                      prefixIcon: const Icon(Icons.phone_rounded, size: 19, color: Color(0xFF128C7E)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF128C7E), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Advanced Developer Settings (Collapsed by default so regular users never have to see or fill it)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                      title: const Text(
                        'Advanced Developer Settings (Optional)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      subtitle: const Text(
                        'Leave empty to use official server credentials',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                      children: [
                        // Phone Number ID Field
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Phone Number ID (Optional)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: phoneIdCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Default: 1284061438133660',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.tag_rounded, size: 17, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Access Token Field (Optional)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Custom Access Token (Optional)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: tokenCtrl,
                          obscureText: obscureToken,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Server default token is used if blank',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.vpn_key_rounded, size: 17, color: Color(0xFF64748B)),
                            suffixIcon: IconButton(
                              icon: Icon(obscureToken ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 17, color: const Color(0xFF64748B)),
                              onPressed: () => setDialogState(() => obscureToken = !obscureToken),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // App Secret Field (Optional)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Meta App Secret (Optional)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: secretCtrl,
                          obscureText: obscureSecret,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Server default secret is used if blank',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.shield_outlined, size: 17, color: Color(0xFF64748B)),
                            suffixIcon: IconButton(
                              icon: Icon(obscureSecret ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 17, color: const Color(0xFF64748B)),
                              onPressed: () => setDialogState(() => obscureSecret = !obscureSecret),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons (Cancel / Save)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setDialogState(() => isSaving = true);
                                    try {
                                      await _chatService.saveConnection(
                                        phoneNumberId: phoneIdCtrl.text.trim(),
                                        phoneNumber: phoneNumCtrl.text.trim(),
                                        accessToken: tokenCtrl.text.trim(),
                                        appSecret: secretCtrl.text.trim(),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF128C7E),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Save & Connect',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectedChat != null) {
          MetaWhatsAppChatScreen.activeChatId = null;
          setState(() => _selectedChat = null);
          return;
        }
        MetaWhatsAppChatScreen.activeChatId = null;
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.transparent,
      child: Row(
        children: [
          // Circular Back / Home Button
          InkWell(
            onTap: () {
              MetaWhatsAppChatScreen.activeChatId = null;
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

          // COMPANY NAME BADGE
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
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ONLINE / OFFLINE STATUS DOT INDICATOR (Same as POS)
          const GlassConnectionStatusBadge(isDarkTheme: true, compact: true),
          const SizedBox(width: 10),

          // Glass circular action button: Refresh Chats
          _buildGlassHeaderButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Chats',
            onTap: _loadConnectionAndChats,
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
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
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
              child: _buildWhatsAppMobileChatList(isEmbedded: false),
            ),
          ),
          // Right Column: Active Conversation inside Simulated Android Phone Mockup or Desktop Empty State
          Expanded(
            child: _selectedChat != null
                ? Container(
                    color: const Color(0xFFF1F5F9), // Soft slate background emphasizing phone mockup
                    child: LayoutBuilder(
                      builder: (context, chatConstraints) {
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: _useAndroidPhoneMockup
                                  ? Center(
                                      child: _buildAndroidPhoneMockup(
                                        maxHeight: chatConstraints.maxHeight,
                                        maxWidth: (chatConstraints.maxWidth - 32).clamp(360.0, 480.0),
                                        child: _buildChatConversationView(isMobile: true),
                                      ),
                                    )
                                  : _buildChatConversationView(isMobile: false),
                            ),
                            Positioned(
                              top: 12,
                              right: 16,
                              child: _buildMockupTogglePill(),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                : _buildDesktopEmptyChatState(),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredPhoneLayout(BoxConstraints constraints) {
    if (_selectedChat != null) {
      if (constraints.maxWidth >= 520 && _useAndroidPhoneMockup) {
        return Container(
          color: const Color(0xFFF1F5F9),
          child: Center(
            child: _buildAndroidPhoneMockup(
              maxHeight: constraints.maxHeight,
              maxWidth: (constraints.maxWidth - 24).clamp(340.0, 480.0),
              child: _buildChatConversationView(isMobile: true),
            ),
          ),
        );
      }
      return _buildChatConversationView(isMobile: true);
    }
    return _buildWhatsAppMobileChatList(isEmbedded: false);
  }

  Widget _buildMockupTogglePill() {
    return InkWell(
      onTap: () => setState(() => _useAndroidPhoneMockup = !_useAndroidPhoneMockup),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _useAndroidPhoneMockup ? Icons.phone_android_rounded : Icons.fullscreen_rounded,
              size: 14,
              color: const Color(0xFF0F172A),
            ),
            const SizedBox(width: 5),
            Text(
              _useAndroidPhoneMockup ? 'Android Phone' : 'Full Screen',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Authentic Android Device Mockup Frame with Punch-Hole Camera, Curved Line, and Sleek Borders.
  /// Designed specifically for the chat conversation view.
  Widget _buildAndroidPhoneMockup({
    required Widget child,
    required double maxHeight,
    double? maxWidth,
  }) {
    final double targetWidth = (maxWidth ?? 440.0).clamp(350.0, 470.0);
    final double targetHeight = (maxHeight - 20.0).clamp(540.0, 920.0);

    return Container(
      width: targetWidth,
      height: targetHeight,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark Android Titanium / Obsidian chassis
        borderRadius: BorderRadius.circular(38),
        border: Border.all(
          color: const Color(0xFF334155), // Sleek metallic phone bezel
          width: 7.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 16),
            blurRadius: 32,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            offset: const Offset(-1, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: const Color(0xFFEFEAE2),
          child: Column(
            children: [
              // 1. Android Status Bar with Real-time Clock, Centered Punch-Hole Camera, and Status Icons
              _buildAndroidStatusBar(),

              // 2. Chat Conversation Content
              Expanded(child: child),

              // 3. Android Home Gesture Bar Indicator
              _buildAndroidNavigationBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// Android Status Bar with Clock, Centered Punch-Hole Camera, and System Indicators
  Widget _buildAndroidStatusBar() {
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm').format(now);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Android Time on left
          SizedBox(
            width: 55,
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // Android Centered Punch-Hole Camera
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF334155),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 3.5,
                height: 3.5,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Android System Icons: 5G, Wi-Fi, Battery
          const SizedBox(
            width: 65,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '5G',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.wifi_rounded, size: 14, color: Color(0xFF475569)),
                SizedBox(width: 4),
                Icon(Icons.battery_5_bar_rounded, size: 15, color: Color(0xFF475569)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Android Gesture Navigation Bar pill
  Widget _buildAndroidNavigationBar() {
    final hasKeyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    if (hasKeyboard) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFFEFEAE2),
      height: 14,
      alignment: Alignment.center,
      child: Container(
        width: 76,
        height: 3.5,
        decoration: BoxDecoration(
          color: const Color(0xFF94A3B8),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildDesktopEmptyChatState() {
    return Container(
      color: const Color(0xFFF0F2F5), // Authentic WhatsApp Web desktop surface
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FDF2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14059669), blurRadius: 20, offset: Offset(0, 6)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.chat_bubble_rounded, size: 48, color: Color(0xFF00A884)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'WhatsApp Web',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF41525D),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send and receive real-time messages with your customers via Meta Cloud API.\nSelect any chat from the left panel or start a new conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Color(0xFF667781), height: 1.5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_rounded, size: 13, color: Color(0xFF8696A0)),
                  SizedBox(width: 6),
                  Text(
                    'End-to-end encrypted via Meta Cloud API',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8696A0), fontWeight: FontWeight.w500),
                  ),
                ],
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
            icon: Icons.phone_rounded,
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

  /// Resolves the contact's profile photo path/URL (from chat model or local database match)
  String? _resolveChatAvatar(WhatsAppChatModel chat) {
    if (chat.avatarUrl != null && chat.avatarUrl!.trim().isNotEmpty) {
      return chat.avatarUrl!.trim();
    }
    return _db.getProfilePhotoByPhone(chat.customerPhone);
  }

  /// Resolves the contact's friendly display name (from chat model or customer database)
  String _resolveChatDisplayName(WhatsAppChatModel chat) {
    if (chat.customerName.isNotEmpty && !chat.customerName.startsWith('Customer ')) {
      return chat.customerName;
    }
    final cust = _db.getCustomerByPhone(chat.customerPhone);
    if (cust != null && cust.name.isNotEmpty && cust.name != 'Customer') {
      return cust.name;
    }
    return chat.displayName;
  }

  /// Resolves initials from customer name or phone
  String _resolveInitials(WhatsAppChatModel chat) {
    final dispName = _resolveChatDisplayName(chat);
    if (dispName.isNotEmpty && !dispName.startsWith('Customer ') && !dispName.startsWith('+')) {
      final parts = dispName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }
    return chat.avatarInitials;
  }

  /// Builds a dynamic avatar circle displaying the number's DP if available, falling back to initials
  Widget _buildChatAvatar(
    WhatsAppChatModel chat, {
    double size = 46,
    bool isSelected = false,
    double? fontSize,
    VoidCallback? onTap,
  }) {
    final rawPhoto = _resolveChatAvatar(chat);
    final photo = ApiEndpoints.resolveMediaUrl(rawPhoto);
    final initials = _resolveInitials(chat);
    final effectiveFontSize = fontSize ?? (size * 0.38);
    Widget avatarContent;

    if (photo.isNotEmpty) {
      if (photo.startsWith('data:image') || photo.startsWith('data:') || (photo.length > 80 && !photo.contains('/') && !photo.contains('\\'))) {
        try {
          final commaIdx = photo.indexOf(',');
          final cleanBase64 = commaIdx != -1 ? photo.substring(commaIdx + 1) : photo;
          final bytes = base64Decode(cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim());
          avatarContent = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(
              initials,
              size: size,
              isSelected: isSelected,
              fontSize: effectiveFontSize,
            ),
          );
        } catch (_) {
          avatarContent = _buildAvatarFallback(
            initials,
            size: size,
            isSelected: isSelected,
            fontSize: effectiveFontSize,
          );
        }
      } else if (photo.startsWith('http://') || photo.startsWith('https://')) {
        avatarContent = Image.network(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(
            initials,
            size: size,
            isSelected: isSelected,
            fontSize: effectiveFontSize,
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              color: isSelected ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
              child: Center(
                child: SizedBox(
                  width: size * 0.45,
                  height: size * 0.45,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00A884),
                  ),
                ),
              ),
            );
          },
        );
      } else if (photo.startsWith('assets/')) {
        avatarContent = Image.asset(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(
            initials,
            size: size,
            isSelected: isSelected,
            fontSize: effectiveFontSize,
          ),
        );
      } else if (!photo.contains('_selected') && File(photo).existsSync()) {
        avatarContent = Image.file(
          File(photo),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(
            initials,
            size: size,
            isSelected: isSelected,
            fontSize: effectiveFontSize,
          ),
        );
      } else {
        avatarContent = _buildAvatarFallback(
          initials,
          size: size,
          isSelected: isSelected,
          fontSize: effectiveFontSize,
        );
      }
    } else {
      avatarContent = _buildAvatarFallback(
        initials,
        size: size,
        isSelected: isSelected,
        fontSize: effectiveFontSize,
      );
    }

    final avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipOval(child: avatarContent),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatarWidget,
      );
    }
    return avatarWidget;
  }

  /// Fallback circle with initials when no DP exists or image fails to load
  Widget _buildAvatarFallback(
    String initials, {
    required double size,
    required bool isSelected,
    required double fontSize,
  }) {
    return Container(
      width: size,
      height: size,
      color: isSelected ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            color: isSelected ? const Color(0xFF065F46) : const Color(0xFF334155),
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  /// Displays the full Contact Profile bottom sheet with DP zoom, CRM details, and option to update photo
  void _showContactProfileSheet(WhatsAppChatModel chat) {
    final cust = _db.getCustomerByPhone(chat.customerPhone);
    final dispName = _resolveChatDisplayName(chat);
    bool isUploadingPhoto = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentPhoto = _resolveChatAvatar(chat);

          Future<void> pickPhoto(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 800);
              if (picked == null) return;

              setSheetState(() => isUploadingPhoto = true);

              final file = File(picked.path);
              String? uploadedUrl;
              try {
                uploadedUrl = await UploadService().uploadImage(file, folder: 'profiles');
              } catch (e) {
                debugPrint('[ContactProfile] Upload failed, falling back to local file: $e');
              }

              final effectivePath = (uploadedUrl != null && uploadedUrl.isNotEmpty) ? uploadedUrl : file.path;

              // Save to customer in DatabaseService
              await _db.saveCustomer(
                name: (cust != null && cust.name.isNotEmpty && cust.name != 'Customer')
                    ? cust.name
                    : (chat.customerName.isNotEmpty && !chat.customerName.startsWith('Customer ')
                        ? chat.customerName
                        : 'Customer'),
                phone: chat.customerPhone,
                avatarUrl: effectivePath,
                email: cust?.email,
                address: cust?.address,
              );

              // Update backend MongoDB
              _chatService.updateChatAvatar(chat.id, effectivePath);

              // Update active chat object
              final updated = chat.copyWith(avatarUrl: effectivePath);
              final idx = _chats.indexWhere((c) => c.id == chat.id || c.customerPhone == chat.customerPhone);
              if (idx >= 0) {
                _chats[idx] = _chats[idx].copyWith(avatarUrl: effectivePath);
              }
              if (_selectedChat != null &&
                  (_selectedChat!.id == chat.id || _selectedChat!.customerPhone == chat.customerPhone)) {
                _selectedChat = updated;
              }

              setSheetState(() => isUploadingPhoto = false);
              setState(() {});

              if (mounted && sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  const SnackBar(
                    content: Text('Profile photo updated successfully!'),
                    backgroundColor: Color(0xFF00A884),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (err) {
              setSheetState(() => isUploadingPhoto = false);
              debugPrint('[ContactProfile] Error picking photo: $err');
            }
          }

          bool isSyncingDp = false;

          Future<void> syncWhatsAppDp() async {
            setSheetState(() => isSyncingDp = true);
            try {
              final newAvatar = await _chatService.syncChatDp(chat.id);
              if (newAvatar != null && newAvatar.isNotEmpty) {
                // Update local customer
                await _db.saveCustomer(
                  name: (cust != null && cust.name.isNotEmpty && cust.name != 'Customer')
                      ? cust.name
                      : (chat.customerName.isNotEmpty && !chat.customerName.startsWith('Customer ')
                          ? chat.customerName
                          : 'Customer'),
                  phone: chat.customerPhone,
                  avatarUrl: newAvatar,
                  email: cust?.email,
                  address: cust?.address,
                );

                final updated = chat.copyWith(avatarUrl: newAvatar);
                final idx = _chats.indexWhere((c) => c.id == chat.id || c.customerPhone == chat.customerPhone);
                if (idx >= 0) {
                  _chats[idx] = _chats[idx].copyWith(avatarUrl: newAvatar);
                }
                if (_selectedChat != null &&
                    (_selectedChat!.id == chat.id || _selectedChat!.customerPhone == chat.customerPhone)) {
                  _selectedChat = updated;
                }

                setSheetState(() => isSyncingDp = false);
                setState(() {});

                if (mounted && sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('WhatsApp DP updated successfully!'),
                        ],
                      ),
                      backgroundColor: Color(0xFF00A884),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                setSheetState(() => isSyncingDp = false);
                if (mounted && sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    const SnackBar(
                      content: Text('No public WhatsApp DP found for this contact. You can set a custom photo.'),
                      backgroundColor: Color(0xFF475569),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            } catch (err) {
              setSheetState(() => isSyncingDp = false);
              debugPrint('[ContactProfile] Error syncing DP: $err');
            }
          }

          void showUrlInputDialog() {
            final urlCtrl = TextEditingController();
            showDialog(
              context: sheetCtx,
              builder: (dCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Enter Image URL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                content: TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/photo.jpg',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final url = urlCtrl.text.trim();
                      if (url.isEmpty) return;
                      Navigator.pop(dCtx);
                      setSheetState(() => isUploadingPhoto = true);
                      await _db.saveCustomer(
                        name: (cust != null && cust.name.isNotEmpty && cust.name != 'Customer')
                            ? cust.name
                            : (chat.customerName.isNotEmpty && !chat.customerName.startsWith('Customer ')
                                ? chat.customerName
                                : 'Customer'),
                        phone: chat.customerPhone,
                        avatarUrl: url,
                        email: cust?.email,
                        address: cust?.address,
                      );
                      await _chatService.updateChatAvatar(chat.id, url);
                      final updated = chat.copyWith(avatarUrl: url);
                      final idx = _chats.indexWhere((c) => c.id == chat.id || c.customerPhone == chat.customerPhone);
                      if (idx >= 0) {
                        _chats[idx] = _chats[idx].copyWith(avatarUrl: url);
                      }
                      if (_selectedChat != null &&
                          (_selectedChat!.id == chat.id || _selectedChat!.customerPhone == chat.customerPhone)) {
                        _selectedChat = updated;
                      }
                      setSheetState(() => isUploadingPhoto = false);
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          }

          void showPhotoSourceDialog() {
            showModalBottomSheet(
              context: sheetCtx,
              backgroundColor: Colors.transparent,
              builder: (ctx) => Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                      ),
                      const Text(
                        'Set Profile Picture',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8FDF2),
                          child: Icon(Icons.sync_rounded, color: Color(0xFF00A884)),
                        ),
                        title: const Text('Sync WhatsApp DP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Fetch active profile picture from WhatsApp', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        onTap: () {
                          Navigator.pop(ctx);
                          syncWhatsAppDp();
                        },
                      ),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEFF6FF),
                          child: Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB)),
                        ),
                        title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        onTap: () {
                          Navigator.pop(ctx);
                          pickPhoto(ImageSource.gallery);
                        },
                      ),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2FE),
                          child: Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7)),
                        ),
                        title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        onTap: () {
                          Navigator.pop(ctx);
                          pickPhoto(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF1F5F9),
                          child: Icon(Icons.link_rounded, color: Color(0xFF475569)),
                        ),
                        title: const Text('Paste Image URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        onTap: () {
                          Navigator.pop(ctx);
                          showUrlInputDialog();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Color(0x26000000), blurRadius: 28, offset: Offset(0, -8)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 4.5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
                          ),
                        ),

                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Contact Info',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(sheetCtx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Large DP with Camera Badge
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              GestureDetector(
                                onTap: showPhotoSourceDialog,
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF10B981), width: 2.5),
                                    boxShadow: const [
                                      BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
                                    ],
                                  ),
                                  child: isUploadingPhoto
                                      ? const Center(
                                          child: SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: CircularProgressIndicator(color: Color(0xFF00A884), strokeWidth: 3),
                                          ),
                                        )
                                      : _buildChatAvatar(
                                          chat,
                                          size: 96,
                                          isSelected: true,
                                          fontSize: 32,
                                        ),
                                ),
                              ),
                              GestureDetector(
                                onTap: showPhotoSourceDialog,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00A884),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Contact Name
                        Text(
                          dispName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),

                        // Phone Number
                        Text(
                          chat.customerPhone.startsWith('+') ? chat.customerPhone : '+${chat.customerPhone}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Badges Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8FDF2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
                                  SizedBox(width: 4),
                                  Text(
                                    'WhatsApp Verified',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                                  ),
                                ],
                              ),
                            ),
                            if (cust != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF2563EB)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Store Customer',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (cust != null) ...[
                          const SizedBox(height: 18),
                          // Stats Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text('Orders', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${cust.totalOrders}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text('Total Spent', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${cust.totalSpent.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF00A884)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Action Buttons: Sync WhatsApp DP + Add/Change Photo + Done
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isSyncingDp ? null : syncWhatsAppDp,
                                    icon: isSyncingDp
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
                                          )
                                        : const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF00A884)),
                                    label: Text(
                                      isSyncingDp ? 'Syncing...' : 'Sync WhatsApp DP',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00A884)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF00A884), width: 1.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: showPhotoSourceDialog,
                                    icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF0284C7)),
                                    label: Text(
                                      currentPhoto != null && currentPhoto.isNotEmpty ? 'Change Photo' : 'Add Photo',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00A884),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text('Done', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
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

  /// Floating Neumorphic Chat Card matching reference image
  Widget _buildChatCard(WhatsAppChatModel chat) {
    final isSelected = _selectedChat != null && _selectedChat!.id == chat.id;
    final isWindowOpen = _isChat24HourWindowActive(chat, isSelected ? _messages : null);
    final dotColor = isWindowOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F2F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (isSelected)
            const BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
        ],
        border: Border.all(
          color: isSelected ? const Color(0xFFCBD5E1) : const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectChat(chat),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Soft avatar circle with DP support (profile badge dot removed per user request)
                _buildChatAvatar(chat, size: 46, isSelected: isSelected),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _resolveChatDisplayName(chat),
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
                                // 24-hour window status dot (Green if open, Red if closed)
                                Tooltip(
                                  message: isWindowOpen
                                      ? '24h Window OPEN (Green dot)'
                                      : '24h Window CLOSED (Red dot - Template required)',
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: dotColor.withValues(alpha: 0.6),
                                          blurRadius: 3,
                                          spreadRadius: 0.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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

    if (bottomInset > 0 && _previousBottomInset == 0) {
      // Keyboard just opened! Animate smoothly to bottom once without disrupting manual scrolling
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 20,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _previousBottomInset = bottomInset;

    return Container(
      color: const Color(0xFFEFEAE2), // Authentic WhatsApp Wallpaper background color
      child: Column(
        children: [
          // 1. WhatsApp Conversation Header
          _buildConversationHeader(),

          // 2. Message List over WhatsApp Doodle Wallpaper
          Expanded(
            child: Stack(
              children: [
                // Authentic WhatsApp Doodle Wallpaper Pattern
                const Positioned.fill(
                  child: CustomPaint(
                    painter: WhatsAppDoodlePainter(),
                  ),
                ),
                Positioned.fill(
                  child: _isLoadingMessages
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A884), strokeWidth: 2.5))
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
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final bool isFirst = index == 0;
                                final bool showDateDivider = isFirst || !_isSameDay(_messages[index - 1].timestamp, msg.timestamp);
                                final bool isUnreadMarker = _unreadMarkerIndex != null && index == _unreadMarkerIndex;

                                final messageContent = Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isUnreadMarker) _buildUnreadDivider(),
                                    _buildMessageBubble(msg),
                                  ],
                                );

                                if (showDateDivider) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildDateDivider(_getDateDividerText(msg.timestamp)),
                                      messageContent,
                                    ],
                                  );
                                }
                                return messageContent;
                              },
                            ),
                ),
              ],
            ),
          ),

          // 2.5 Meta 24-Hour Service Window Notice (shown when window is closed)
          if (_is24HourWindowClosed)
            _build24HourWindowBanner(),

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
      ),
    );
  }

  Widget _buildUnreadDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mark_chat_unread_rounded, size: 14, color: Color(0xFF0284C7)),
          SizedBox(width: 6),
          Text(
            'Unread Messages',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
          ),
        ],
      ),
    );
  }

  Widget _build24HourWindowBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_toggle_off_rounded, size: 18, color: Color(0xFFD97706)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Meta 24-Hour Window Closed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Under Meta policy, send an approved template to interact with this customer.',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFFB45309)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _openTemplatePicker,
            icon: const Icon(Icons.send_rounded, size: 12, color: Colors.white),
            label: const Text(
              'Send Template',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              visualDensity: VisualDensity.compact,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Conversation screen header matching authentic WhatsApp UI
  Widget _buildConversationHeader() {
    final phoneDisplay = _selectedChat!.customerPhone.startsWith('+')
        ? _selectedChat!.customerPhone
        : '+${_selectedChat!.customerPhone}';
    final isWindowOpen = _is24HourWindowActive;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Back Button
          _buildNeumorphicCircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back to chats',
            onTap: () {
              MetaWhatsAppChatScreen.activeChatId = null;
              setState(() => _selectedChat = null);
            },
          ),
          const SizedBox(width: 8),

          // Contact Avatar (Tap to view/update profile DP)
          GestureDetector(
            onTap: () => _showContactProfileSheet(_selectedChat!),
            child: _buildChatAvatar(_selectedChat!, size: 40),
          ),
          const SizedBox(width: 10),

          // Contact Name & Phone / Status
          Expanded(
            child: InkWell(
              onTap: () => _showContactProfileSheet(_selectedChat!),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _resolveChatDisplayName(_selectedChat!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: isWindowOpen ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          phoneDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
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
            if (val == 'contact_info') _showContactProfileSheet(_selectedChat!);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'contact_info',
              child: Row(
                children: const [
                  Icon(Icons.account_circle_outlined, size: 17, color: Color(0xFF0F172A)),
                  SizedBox(width: 10),
                  Text(
                    'Contact Profile & DP',
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

  /// Floating date divider pill ("Today", "Yesterday", or formatted date)
  Widget _buildDateDivider(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();
    return aLocal.year == bLocal.year && aLocal.month == bLocal.month && aLocal.day == bLocal.day;
  }

  String _getDateDividerText(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final msgDate = DateTime(local.year, local.month, local.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(local).inDays < 7 && msgDate.isAfter(DateTime(now.year, now.month, now.day - 7))) {
      return DateFormat('EEEE').format(local);
    } else if (local.year == now.year) {
      return DateFormat('d MMMM').format(local);
    } else {
      return DateFormat('d MMMM yyyy').format(local);
    }
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
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Send Approved Template',
                  child: GestureDetector(
                    onTap: _openTemplatePicker,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _is24HourWindowClosed ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.dashboard_customize_rounded,
                        size: 19,
                        color: _is24HourWindowClosed ? const Color(0xFFD97706) : const Color(0xFF059669),
                      ),
                    ),
                  ),
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
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showImageUrlDialog();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.dashboard_customize_rounded,
                  label: 'Template',
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openTemplatePicker();
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

  /// Authentic WhatsApp message bubble with speech tails, compact time, and blue double ticks
  Widget _buildMessageBubble(WhatsAppMessageModel msg) {
    final isOutgoing = msg.isOutgoing;
    final screenWidth = MediaQuery.of(context).size.width;
    final hasMedia = msg.messageType == 'image' || msg.mediaUrl.isNotEmpty;
    final isSingleShortLine = !hasMedia && !msg.text.contains('\n') && msg.text.length <= 26;
    final hasError = msg.status.toUpperCase() == 'FAILED' || (msg.error != null && msg.error!.isNotEmpty);

    final double maxBubbleWidth = (screenWidth >= 900
        ? 340.0
        : (screenWidth >= 680 ? 320.0 : screenWidth * 0.74)).clamp(210.0, 320.0);

    final timeWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _formatTime(msg.timestamp),
          style: TextStyle(
            fontSize: 10.5,
            color: isOutgoing ? const Color(0xFF166534) : const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isOutgoing) ...[
          const SizedBox(width: 3.5),
          _buildStatusIcon(msg.status),
        ],
      ],
    );

    final Color bubbleColor = isOutgoing ? const Color(0xFFD9FDD3) : Colors.white;

    final bubbleBody = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(isOutgoing ? 12 : 2),
          bottomRight: Radius.circular(isOutgoing ? 2 : 12),
        ),
        border: Border.all(
          color: isOutgoing
              ? const Color(0xFFC7EBC1).withValues(alpha: 0.6)
              : const Color(0xFFE2E8F0),
          width: 0.7,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            offset: Offset(0, 1),
            blurRadius: 3,
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
                if (msg.messageType == 'template') ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.dashboard_customize_rounded, size: 11, color: Color(0xFF065F46)),
                          SizedBox(width: 4),
                          Text(
                            'Meta Approved Template',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                  GestureDetector(
                    onTap: () => _showReEngagementHelpDialog(msg.error!),
                    child: Container(
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
                              _formatErrorMessage(msg.error!),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_isReEngagementError(msg.error!)) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.help_outline_rounded, size: 11, color: Color(0xFFDC2626)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: bubbleBody,
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'READ':
        return const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF53BDEB));
      case 'DELIVERED':
        return const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF8696A0));
      case 'SENT':
        return const Icon(Icons.check_rounded, size: 15, color: Color(0xFF8696A0));
      case 'FAILED':
        return const Icon(Icons.error_outline_rounded, size: 14, color: Colors.red);
      default:
        return const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF8696A0));
    }
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final msgDate = DateTime(local.year, local.month, local.day);

    if (msgDate == today) {
      return _formatTime(local);
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(local).inDays < 7 && msgDate.isAfter(DateTime(now.year, now.month, now.day - 7))) {
      return DateFormat('EEEE').format(local);
    } else {
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  bool _isReEngagementError(String err) {
    final lower = err.toLowerCase();
    return lower.contains('re-engagement') ||
        lower.contains('24-hour') ||
        lower.contains('24 hour') ||
        lower.contains('131047');
  }

  String _formatErrorMessage(String rawError) {
    if (_isReEngagementError(rawError)) {
      return '24-hr window expired (Tap for info)';
    }
    if (rawError.contains('131030') || rawError.toLowerCase().contains('sandbox')) {
      return 'Meta sandbox: recipient not whitelisted';
    }
    return rawError;
  }

  void _showReEngagementHelpDialog(String rawError) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '24-Hour Policy Window',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meta WhatsApp Cloud API enforces a strict 24-hour customer service window rule:',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Text(
                '• Free-form text messages can only be sent within 24 hours of the customer\'s last reply.\n• Since >24 hours have passed without customer reply, Meta blocked regular text to protect users from spam.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'How to re-open the conversation:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              '1. Ask the customer to reply with any message (e.g. "Hi") from their WhatsApp. This reopens the 24-hour window immediately for free-form replies.\n\n2. Or send an approved Meta Message Template (like an eBill or utility template) from the POS.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Authentic WhatsApp chat bubble speech tail
class WhatsAppBubbleTail extends StatelessWidget {
  final bool isOutgoing;
  final Color color;

  const WhatsAppBubbleTail({
    super.key,
    required this.isOutgoing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(6, 10),
      painter: _WhatsAppBubbleTailPainter(isOutgoing: isOutgoing, color: color),
    );
  }
}

class _WhatsAppBubbleTailPainter extends CustomPainter {
  final bool isOutgoing;
  final Color color;

  _WhatsAppBubbleTailPainter({required this.isOutgoing, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isOutgoing) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.quadraticBezierTo(size.width * 0.3, size.height * 0.5, 0, size.height);
      path.close();
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.quadraticBezierTo(size.width * 0.7, size.height * 0.5, size.width, size.height);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WhatsAppBubbleTailPainter oldDelegate) =>
      oldDelegate.isOutgoing != isOutgoing || oldDelegate.color != color;
}

/// Vector WhatsApp Doodle Wallpaper Painter
/// Draws authentic WhatsApp icons (speech bubble, coffee cup, clock, notes, camera, smiley)
/// tiled seamlessly with subtle ~5% opacity on top of #EFEAE2 wallpaper.
class WhatsAppDoodlePainter extends CustomPainter {
  final Color doodleColor;

  const WhatsAppDoodlePainter({
    this.doodleColor = const Color(0x0C000000), // ~5% soft black on warm cream
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = doodleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = doodleColor
      ..style = PaintingStyle.fill;

    const double stepX = 130.0;
    const double stepY = 130.0;

    int col = 0;
    for (double y = 18; y < size.height + 40; y += stepY) {
      int row = 0;
      final double offsetX = (col % 2 == 1) ? stepX / 2 : 0.0;
      for (double x = -20 + offsetX; x < size.width + 40; x += stepX) {
        final int patternIndex = (row + col * 3) % 8;
        _drawDoodle(canvas, x, y, patternIndex, strokePaint, fillPaint);
        row++;
      }
      col++;
    }
  }

  void _drawDoodle(Canvas canvas, double x, double y, int pattern, Paint strokePaint, Paint fillPaint) {
    switch (pattern) {
      case 0:
        // Speech Bubble
        final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 22, 16), const Radius.circular(5));
        canvas.drawRRect(rrect, strokePaint);
        final tail = Path()
          ..moveTo(x + 5, y + 16)
          ..lineTo(x + 2, y + 21)
          ..lineTo(x + 10, y + 16)
          ..close();
        canvas.drawPath(tail, strokePaint);
        canvas.drawCircle(Offset(x + 7, y + 8), 1.2, fillPaint);
        canvas.drawCircle(Offset(x + 11, y + 8), 1.2, fillPaint);
        canvas.drawCircle(Offset(x + 15, y + 8), 1.2, fillPaint);
        break;
      case 1:
        // Coffee Cup
        final cup = Path()
          ..moveTo(x, y + 4)
          ..lineTo(x + 16, y + 4)
          ..lineTo(x + 14, y + 16)
          ..arcToPoint(Offset(x + 2, y + 16), radius: const Radius.circular(4), clockwise: true)
          ..close();
        canvas.drawPath(cup, strokePaint);
        final handle = Path()
          ..moveTo(x + 15, y + 6)
          ..arcToPoint(Offset(x + 15, y + 13), radius: const Radius.circular(4), clockwise: false);
        canvas.drawPath(handle, strokePaint);
        canvas.drawLine(Offset(x + 5, y + 2), Offset(x + 5, y), strokePaint);
        canvas.drawLine(Offset(x + 11, y + 2), Offset(x + 11, y), strokePaint);
        break;
      case 2:
        // Clock
        canvas.drawCircle(Offset(x + 9, y + 9), 9, strokePaint);
        canvas.drawLine(Offset(x + 9, y + 9), Offset(x + 9, y + 4), strokePaint);
        canvas.drawLine(Offset(x + 9, y + 9), Offset(x + 13, y + 9), strokePaint);
        break;
      case 3:
        // Musical Note
        final note = Path()
          ..moveTo(x + 12, y)
          ..lineTo(x + 12, y + 12)
          ..lineTo(x + 4, y + 15)
          ..moveTo(x + 4, y + 3)
          ..lineTo(x + 12, y);
        canvas.drawPath(note, strokePaint);
        canvas.drawCircle(Offset(x + 3, y + 15), 3, fillPaint);
        canvas.drawCircle(Offset(x + 11, y + 12), 3, fillPaint);
        break;
      case 4:
        // Heart
        final heart = Path()
          ..moveTo(x + 8, y + 14)
          ..cubicTo(x, y + 9, x, y + 2, x + 8, y + 6)
          ..cubicTo(x + 16, y + 2, x + 16, y + 9, x + 8, y + 14)
          ..close();
        canvas.drawPath(heart, strokePaint);
        break;
      case 5:
        // Camera
        final cam = RRect.fromRectAndRadius(Rect.fromLTWH(x, y + 4, 18, 12), const Radius.circular(3));
        canvas.drawRRect(cam, strokePaint);
        final topBit = Path()
          ..moveTo(x + 5, y + 4)
          ..lineTo(x + 7, y + 1)
          ..lineTo(x + 11, y + 1)
          ..lineTo(x + 13, y + 4);
        canvas.drawPath(topBit, strokePaint);
        canvas.drawCircle(Offset(x + 9, y + 10), 3.5, strokePaint);
        break;
      case 6:
        // Shopping Bag
        final bag = RRect.fromRectAndRadius(Rect.fromLTWH(x, y + 5, 16, 14), const Radius.circular(3));
        canvas.drawRRect(bag, strokePaint);
        final bagHandle = Path()
          ..moveTo(x + 4, y + 5)
          ..arcToPoint(Offset(x + 12, y + 5), radius: const Radius.circular(4), clockwise: false);
        canvas.drawPath(bagHandle, strokePaint);
        break;
      case 7:
        // Smiley Face
        canvas.drawCircle(Offset(x + 9, y + 9), 8.5, strokePaint);
        canvas.drawCircle(Offset(x + 6, y + 7), 1, fillPaint);
        canvas.drawCircle(Offset(x + 12, y + 7), 1, fillPaint);
        final smile = Path()
          ..moveTo(x + 6, y + 11)
          ..arcToPoint(Offset(x + 12, y + 11), radius: const Radius.circular(3.5), clockwise: false);
        canvas.drawPath(smile, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant WhatsAppDoodlePainter oldDelegate) => false;
}
