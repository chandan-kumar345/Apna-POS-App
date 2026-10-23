import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/whatsapp_chat_service.dart';

class WhatsAppTemplatePickerDialog extends StatefulWidget {
  final WhatsAppChatModel? chat;
  final String? customerPhone;
  final String? customerName;
  final String businessName;
  final Function(WhatsAppMessageModel message)? onTemplateSent;
  final Function(String renderedText, WhatsAppTemplateModel template, List<String> parameters)? onTemplateSelected;

  const WhatsAppTemplatePickerDialog({
    super.key,
    this.chat,
    this.customerPhone,
    this.customerName,
    required this.businessName,
    this.onTemplateSent,
    this.onTemplateSelected,
  });

  /// Open dialog to send template directly to an existing conversation
  static Future<void> show({
    required BuildContext context,
    required WhatsAppChatModel chat,
    required String businessName,
    required Function(WhatsAppMessageModel message) onTemplateSent,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WhatsAppTemplatePickerDialog(
        chat: chat,
        businessName: businessName,
        onTemplateSent: onTemplateSent,
      ),
    );
  }

  /// Open dialog to pick and configure an approved template (e.g. for New Chat creation)
  static Future<void> pick({
    required BuildContext context,
    String? customerPhone,
    String? customerName,
    required String businessName,
    required Function(String renderedText, WhatsAppTemplateModel template, List<String> parameters) onSelected,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WhatsAppTemplatePickerDialog(
        customerPhone: customerPhone,
        customerName: customerName,
        businessName: businessName,
        onTemplateSelected: onSelected,
      ),
    );
  }

  @override
  State<WhatsAppTemplatePickerDialog> createState() => _WhatsAppTemplatePickerDialogState();
}

class _WhatsAppTemplatePickerDialogState extends State<WhatsAppTemplatePickerDialog> {
  final WhatsAppChatService _chatService = WhatsAppChatService();

  List<WhatsAppTemplateModel> _templates = [];
  WhatsAppTemplateModel? _selectedTemplate;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  final Map<String, TextEditingController> _paramControllers = {};

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _chatService.getApprovedTemplates();
      if (!mounted) return;

      setState(() {
        _templates = list;
        _isLoading = false;
        if (list.isNotEmpty) {
          _selectTemplate(list.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load Meta templates: $e';
      });
    }
  }

  void _selectTemplate(WhatsAppTemplateModel tmpl) {
    setState(() {
      _selectedTemplate = tmpl;
      _initParamControllers(tmpl);
    });
  }

  void _initParamControllers(WhatsAppTemplateModel tmpl) {
    // Clear old controllers
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    _paramControllers.clear();

    final now = DateTime.now();
    final defaultDate = DateFormat('dd MMM yyyy').format(now);
    final invSuffix = now.millisecondsSinceEpoch.toString();
    final defaultInv = 'INV-${invSuffix.length >= 6 ? invSuffix.substring(invSuffix.length - 6) : invSuffix}';

    final effectiveCustName = widget.chat?.customerName.isNotEmpty == true
        ? widget.chat!.customerName
        : (widget.customerName?.isNotEmpty == true ? widget.customerName! : 'Valued Customer');

    for (int i = 0; i < tmpl.parameters.length; i++) {
      final p = tmpl.parameters[i];
      final key = p.key.isNotEmpty ? p.key : (i + 1).toString();
      String defaultValue = '';

      if (tmpl.name == 'apna_pos_auth_otp') {
        defaultValue = p.example.isNotEmpty ? p.example : '123456';
      } else if (tmpl.name == 'special_discount_offer') {
        if (i == 0) {
          defaultValue = effectiveCustName;
        } else if (i == 1) {
          defaultValue = '20';
        } else if (i == 2) {
          defaultValue = widget.businessName.isNotEmpty ? widget.businessName : 'Our Store';
        } else if (i == 3) {
          defaultValue = 'SAVE20';
        }
      } else if (tmpl.name == 'ebill_receipt') {
        if (i == 0) {
          defaultValue = effectiveCustName;
        } else if (i == 1) {
          defaultValue = widget.businessName.isNotEmpty ? widget.businessName : 'Our Store';
        } else if (i == 2) {
          defaultValue = defaultInv;
        } else if (i == 3) {
          defaultValue = defaultDate;
        } else if (i == 4) {
          defaultValue = '250.00';
        } else if (i == 5) {
          defaultValue = 'Paid';
        } else if (i == 6) {
          defaultValue = 'UPI';
        }
      } else {
        if (p.example.isNotEmpty) {
          defaultValue = p.example;
        } else if (i == 0 && effectiveCustName.isNotEmpty && effectiveCustName != 'Valued Customer') {
          defaultValue = effectiveCustName;
        } else if (i == 1 && widget.businessName.isNotEmpty) {
          defaultValue = widget.businessName;
        }
      }

      final controller = TextEditingController(text: defaultValue);
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      _paramControllers[key] = controller;
    }
  }

  String _renderPreviewBody(WhatsAppTemplateModel tmpl) {
    String text = tmpl.body;
    _paramControllers.forEach((key, controller) {
      final val = controller.text.trim().isNotEmpty ? controller.text.trim() : '{{$key}}';
      text = text.replaceAll('{{$key}}', val);
    });
    return text;
  }

  Future<void> _sendOrSelectTemplate() async {
    if (_selectedTemplate == null || _isSending) return;

    final params = <String>[];
    for (int i = 0; i < _selectedTemplate!.parameters.length; i++) {
      final p = _selectedTemplate!.parameters[i];
      final key = p.key.isNotEmpty ? p.key : (i + 1).toString();
      final val = _paramControllers[key]?.text.trim() ?? '';
      params.add(val.isNotEmpty ? val : (p.example.isNotEmpty ? p.example : '-'));
    }

    // If picking template for a new chat (not direct sending to existing chat)
    if (widget.onTemplateSelected != null) {
      final rendered = _renderPreviewBody(_selectedTemplate!);
      widget.onTemplateSelected!(rendered, _selectedTemplate!, params);
      Navigator.of(context).pop();
      return;
    }

    if (widget.chat == null) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final sent = await _chatService.sendTemplateMessage(
        chatId: widget.chat!.id,
        templateName: _selectedTemplate!.name,
        languageCode: _selectedTemplate!.language,
        parameters: params,
      );

      if (!mounted) return;
      setState(() => _isSending = false);

      if (sent != null) {
        widget.onTemplateSent?.call(sent);
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = 'Template dispatch was not accepted by Meta. Please check connection.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  /// Badge showing whether the template type is UTILITY, MARKETING, or AUTHENTICATION
  Widget _buildCategoryBadge(String category, {bool isSelected = false}) {
    final cat = category.toUpperCase().trim();
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    switch (cat) {
      case 'MARKETING':
        bg = const Color(0xFFFEF3C7); // Warm amber
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFB45309);
        icon = Icons.campaign_rounded;
        label = 'MARKETING';
        break;
      case 'AUTHENTICATION':
      case 'AUTH':
      case 'OTP':
        bg = const Color(0xFFF3E8FF); // Soft purple
        border = const Color(0xFFE9D5FF);
        text = const Color(0xFF7E22CE);
        icon = Icons.lock_outline_rounded;
        label = 'AUTH';
        break;
      case 'UTILITY':
      default:
        bg = const Color(0xFFE0F2FE); // Soft sky blue
        border = const Color(0xFFBAE6FD);
        text = const Color(0xFF0369A1);
        icon = Icons.tune_rounded;
        label = 'UTILITY';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: text),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: text,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 395,
          maxHeight: media.size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 36,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header matching design
              _buildHeader(),

              // Error banner if any
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Scrollable Wrapped Content
              Flexible(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00A884),
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. 24-hr Policy Info Pill Notice
                            _build24HrPolicyNotice(),
                            const SizedBox(height: 14),

                            // 2. Select Approved Template Section
                            const Text(
                              'SELECT APPROVED TEMPLATE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTemplateList(),
                            const SizedBox(height: 14),

                            // 3. Parameters Variable Input Section (compact inline)
                            if (_selectedTemplate != null && _selectedTemplate!.parameters.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Text(
                                    'FILL TEMPLATE VARIABLES',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_selectedTemplate!.parameters.length}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildParameterFields(_selectedTemplate!),
                              const SizedBox(height: 14),
                            ],

                            // 4. Message Preview Box (As Customer Sees It)
                            if (_selectedTemplate != null) ...[
                              const Text(
                                'MESSAGE PREVIEW (AS CUSTOMER SEES IT)',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildLivePreviewCard(_selectedTemplate!),
                            ],
                          ],
                        ),
                      ),
              ),

              // Bottom Actions Row (Cancel + Use Approved Template)
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  /// Refined Header with Squircle Emerald App Icon, Crisp Typography & Circular Close Button
  Widget _buildHeader() {
    final recipientTitle = widget.chat?.customerName.isNotEmpty == true
        ? widget.chat!.customerName
        : (widget.customerName?.isNotEmpty == true
            ? widget.customerName!
            : (widget.chat?.customerPhone ?? widget.customerPhone ?? 'Send to New Customer'));

    final displaySubtitle = recipientTitle.startsWith('Send to')
        ? recipientTitle
        : 'Send to $recipientTitle';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          // Squircle Emerald Icon Container with gentle glow
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00A884), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3800A884),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.widgets_rounded,
                color: Colors.white,
                size: 22,
              ),
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
                  'Meta Approved Template',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displaySubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Circular Close Button (soft gray circle)
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 24-Hour Policy Notice Banner matching reference screenshot
  Widget _build24HrPolicyNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FDF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0).withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(
              color: Color(0xFF00A884),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.info_outline_rounded, color: Colors.white, size: 14),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Meta WhatsApp allows sending approved templates at any time, even outside the 24-hour service window. Once the customer replies, the 24-hour service window will re-open.',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF065F46),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Vertical List of Embossed Soft Cards showing Category Type (UTILITY / MARKETING / AUTH)
  Widget _buildTemplateList() {
    if (_templates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No approved templates found on your Meta Business Account.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      );
    }

    return Column(
      children: _templates.map((tmpl) {
        final isSelected = _selectedTemplate?.id == tmpl.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: InkWell(
            onTap: () => _selectTemplate(tmpl),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8FDF2) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00A884) : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? const Color(0x1400A884) : const Color(0x06000000),
                    blurRadius: isSelected ? 6 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Radio button
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00A884) : const Color(0xFF94A3B8),
                        width: isSelected ? 5.5 : 1.5,
                      ),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Template name
                  Expanded(
                    child: Text(
                      tmpl.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Template Type Badge (UTILITY / MARKETING / AUTH)
                  _buildCategoryBadge(tmpl.category, isSelected: isSelected),
                  const SizedBox(width: 5),
                  // Language Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFBFF2DE) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tmpl.language.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Message Preview Card with Category Type Indicator
  Widget _buildLivePreviewCard(WhatsAppTemplateModel tmpl) {
    final previewText = _renderPreviewBody(tmpl);
    final footerText = tmpl.footer.isNotEmpty
        ? tmpl.footer
        : (widget.businessName.isNotEmpty ? 'Knowwu / ${widget.businessName}' : 'Knowwu / APNA POS');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8FDF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0).withValues(alpha: 0.7), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A00A884),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WhatsApp Bubble Icon
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFF25D366),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Type & Template Name Bar
                Row(
                  children: [
                    _buildCategoryBadge(tmpl.category, isSelected: true),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tmpl.name,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Rendered text with bold first parameter emphasis if OTP
                _buildFormattedPreview(tmpl, previewText),
                const SizedBox(height: 6),
                // Footer
                Text(
                  footerText,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds styled text for the preview highlighting OTP or code variables
  Widget _buildFormattedPreview(WhatsAppTemplateModel tmpl, String text) {
    if (tmpl.name.contains('otp')) {
      final match = RegExp(r'[“"״]?(\d{4,8})[”"״]?').firstMatch(text);
      if (match != null) {
        final code = match.group(1)!;
        final parts = text.split(match.group(0)!);
        return RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), height: 1.35, fontWeight: FontWeight.w500),
            children: [
              if (parts.isNotEmpty) TextSpan(text: parts[0]),
              TextSpan(
                text: '“$code”',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF047857), fontSize: 12),
              ),
              if (parts.length > 1) TextSpan(text: parts[1]),
            ],
          ),
        );
      }
    }

    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: Color(0xFF0F172A),
        height: 1.35,
      ),
    );
  }

  /// Compact parameters input form
  Widget _buildParameterFields(WhatsAppTemplateModel tmpl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: tmpl.parameters.map((p) {
          final key = p.key.isNotEmpty ? p.key : (tmpl.parameters.indexOf(p) + 1).toString();
          final controller = _paramControllers[key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 95,
                  child: Text(
                    p.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: p.example.isNotEmpty ? p.example : 'Enter value',
                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Bottom Actions Bar matching reference image
  Widget _buildBottomActions() {
    final isPickMode = widget.onTemplateSelected != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          // Cancel Button (soft rounded card)
          InkWell(
            onTap: _isSending ? null : () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Use / Send Approved Template Button
          Expanded(
            child: InkWell(
              onTap: (_isSending || _selectedTemplate == null) ? null : _sendOrSelectTemplate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A884), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300A884),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSending
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.near_me_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            isPickMode ? 'Use Approved Template' : 'Send Approved Template',
                            style: const TextStyle(
                              fontSize: 12,
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
    );
  }
}
