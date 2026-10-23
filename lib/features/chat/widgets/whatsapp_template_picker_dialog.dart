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

      if (tmpl.name == 'ebill_receipt') {
        if (i == 0) {
          defaultValue = effectiveCustName;
        } else if (i == 1) {
          defaultValue = widget.businessName.isNotEmpty ? widget.businessName : 'Our Store';
        } else if (i == 2) {
          defaultValue = defaultInv;
        } else if (i == 3) {
          defaultValue = defaultDate;
        } else if (i == 4) {
          defaultValue = '0.00';
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 500;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: media.size.height * 0.88,
        ),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header
              _buildHeader(),

              // Error banner if any
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),

              // Scrollable Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: Color(0xFF059669),
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 24-hr Policy Info Pill
                            _build24HrPolicyNotice(),
                            const SizedBox(height: 16),

                            // Template Selector
                            const Text(
                              'SELECT APPROVED TEMPLATE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTemplateChips(),
                            const SizedBox(height: 18),

                            // Message Live Preview Box
                            if (_selectedTemplate != null) ...[
                              const Text(
                                'MESSAGE PREVIEW (AS CUSTOMER SEES IT)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildLivePreviewCard(_selectedTemplate!),
                              const SizedBox(height: 18),

                              // Parameter Inputs (if applicable)
                              if (_selectedTemplate!.parameters.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Text(
                                      'FILL TEMPLATE VARIABLES',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${_selectedTemplate!.parameters.length} params',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0369A1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildParameterFields(_selectedTemplate!),
                              ],
                            ],
                          ],
                        ),
                      ),
              ),

              // Bottom Actions Bar
              _buildBottomActions(isCompact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final recipientTitle = widget.chat?.customerName.isNotEmpty == true
        ? widget.chat!.customerName
        : (widget.customerName?.isNotEmpty == true
            ? widget.customerName!
            : (widget.chat?.customerPhone ?? widget.customerPhone ?? 'New Customer'));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Meta Approved Template',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '24-hr Bypass',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Send to $recipientTitle',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _build24HrPolicyNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.verified_rounded, size: 18, color: Color(0xFF16A34A)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Meta WhatsApp allows sending approved templates at any time, even outside the 24-hour service window. Once the customer replies, regular chatting re-opens.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF15803D),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateChips() {
    if (_templates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'No approved templates found on your Meta Business Account.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _templates.map((tmpl) {
        final isSelected = _selectedTemplate?.id == tmpl.id;
        return InkWell(
          onTap: () => _selectTemplate(tmpl),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? const [BoxShadow(color: Color(0x1A059669), blurRadius: 4, offset: Offset(0, 2))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 15,
                  color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  tmpl.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tmpl.language.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLivePreviewCard(WhatsAppTemplateModel tmpl) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFEAE2), // WhatsApp wallpaper tone
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFD9FDD3), // WhatsApp outbound light green bubble
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(3),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              if (tmpl.header.isNotEmpty) ...[
                Text(
                  tmpl.header,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // Body
              Text(
                _renderPreviewBody(tmpl),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                  height: 1.35,
                ),
              ),

              // Footer
              if (tmpl.footer.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  tmpl.footer,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF475569),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              // Timestamp & Double-Check
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'Just now',
                    style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF0284C7)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterFields(WhatsAppTemplateModel tmpl) {
    return Column(
      children: tmpl.parameters.map((p) {
        final key = p.key.isNotEmpty ? p.key : (tmpl.parameters.indexOf(p) + 1).toString();
        final controller = _paramControllers[key];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  p.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: p.example.isNotEmpty ? p.example : 'Enter value',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActions(bool isCompact) {
    final isPickMode = widget.onTemplateSelected != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSending ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: (_isSending || _selectedTemplate == null) ? null : _sendOrSelectTemplate,
            icon: _isSending
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(
                    isPickMode ? Icons.check_circle_rounded : Icons.send_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
            label: Text(
              _isSending
                  ? 'Sending Template...'
                  : (isPickMode ? 'Use Approved Template' : 'Send to Customer'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
            ),
          ),
        ],
      ),
    );
  }
}
