import 'package:flutter/material.dart';
import 'mobile_campaign_data.dart';
import 'campaign_style.dart';

class CampaignAudienceDialog extends StatefulWidget {
  const CampaignAudienceDialog({
    super.key,
    required this.api,
    required this.campaign,
    required this.options,
    required this.resend,
  });

  final MobileCampaignApi api;
  final CampaignJson campaign;
  final CampaignOptions? options;
  final bool resend;

  @override
  State<CampaignAudienceDialog> createState() => _AudienceState();
}

class _AudienceState extends State<CampaignAudienceDialog> {
  final phones = TextEditingController();
  final requestId = MobileCampaignDraft().id;
  List<CampaignJson> groups = [];
  String? group, error, groupError;
  late String mode;
  // Opted-in internally by default; checkbox is hidden from UI per user request
  bool consent = true;
  bool busy = false;
  CampaignJson? quote;

  @override
  void initState() {
    super.initState();
    mode = widget.resend
        ? ((widget.campaign['stats']?['failed'] ?? 0) > 0 ? 'failed' : 'all')
        : 'new';
    groups = widget.options?.groups ?? [];
    if (!widget.resend) loadGroups();
  }

  Future<void> loadGroups() async {
    try {
      final options = await widget.api.options();
      if (mounted) {
        setState(() {
          groups = options.groups;
          groupError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => groupError = 'Could not refresh groups.');
    }
  }

  @override
  void dispose() {
    phones.dispose();
    super.dispose();
  }

  void edit(VoidCallback fn) => setState(() {
    fn();
    quote = null;
    error = null;
  });

  /// Normalizes phone numbers:
  /// - Strips spaces, dashes, parentheses, non-digits
  /// - Automatically prepends '91' for 10-digit Indian numbers internally
  /// - Handles 11-digit numbers starting with 0
  /// - Preserves already formatted 91XXXXXXXXXX numbers without duplicating 91
  /// - Deduplicates and filters valid length numbers
  List<String> _extractNormalizedPhones(String input) {
    if (input.trim().isEmpty) return const [];
    final tokens = input.split(RegExp(r'[,;\n\r\t]+'));
    final Set<String> normalized = {};
    for (final raw in tokens) {
      final clean = raw.replaceAll(RegExp(r'[^0-9+]'), '');
      if (clean.isEmpty) continue;
      String digits = clean;
      if (digits.startsWith('+')) {
        digits = digits.substring(1);
      }
      if (digits.startsWith('0') && digits.length == 11) {
        digits = digits.substring(1);
      }
      if (digits.length == 10) {
        // Prepend 91 internally so user does not need to type 91
        digits = '91$digits';
      }
      if (digits.length >= 10 && digits.length <= 15) {
        normalized.add(digits);
      }
    }
    return normalized.toList();
  }

  Future<void> submit() async {
    if (busy) return;
    final confirm = quote != null;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final normalizedPhones = _extractNormalizedPhones(phones.text);
      final result = await widget.api.followUp(
        (widget.campaign['id'] ?? widget.campaign['_id']).toString(),
        {
          'mode': mode,
          'groupId': (group ?? '').isEmpty ? null : group,
          'requestId': requestId,
          // Opt-in confirmed internally
          'confirmedOptIn': true,
          'phones': normalizedPhones,
          'preview': !confirm,
          'confirmedCount': quote?['count'],
        },
      );
      if (!mounted) return;
      if (confirm) {
        Navigator.pop(context, true);
      } else {
        setState(() => quote = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          quote = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedPhones = _extractNormalizedPhones(phones.text);
    final phoneCount = normalizedPhones.length;
    final bool hasSelectedGroup = (group != null && group!.isNotEmpty && group != '');
    final bool canSubmit = !busy &&
        (widget.resend || phoneCount > 0 || hasSelectedGroup);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.white,
                ),
                child: Stack(
                  children: [
                    // Decorative top-right curved mint backdrop
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topRight,
                            radius: 0.9,
                            colors: [
                              const Color(0xFFE8F5E9).withValues(alpha: 0.8),
                              const Color(0xFFF0FDF4).withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Drag Handle
                          Center(
                            child: Container(
                              width: 36,
                              height: 3.5,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Header Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Green rounded badge
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  widget.resend
                                      ? Icons.replay_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  color: const Color(0xFF00A86B),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Title & Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.resend
                                          ? 'Resend campaign'
                                          : 'Send to new customers',
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 1.5),
                                    Text(
                                      widget.resend
                                          ? 'Resend to previous or failed recipients'
                                          : 'Add customers to send this campaign',
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Top-right Paper Airplane Graphic
                              const _PaperPlaneFlightGraphic(),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Resend mode vs New customers mode
                          if (widget.resend) ...[
                            const Text(
                              'Recipients',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              initialValue: mode,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              menuMaxHeight: 220,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF1E293B),
                                size: 20,
                              ),
                              selectedItemBuilder: (BuildContext context) {
                                return const [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Failed recipients only',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 12,
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'All previous recipients',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 12,
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ];
                              },
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00A86B),
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFCFDFD),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'failed',
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: mode == 'failed' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: mode == 'failed' ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          mode == 'failed' ? Icons.check_circle_rounded : Icons.replay_rounded,
                                          size: 15,
                                          color: mode == 'failed' ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Failed recipients only',
                                            style: TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 12,
                                              color: mode == 'failed' ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                                              fontWeight: mode == 'failed' ? FontWeight.w700 : FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: mode == 'all' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: mode == 'all' ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          mode == 'all' ? Icons.check_circle_rounded : Icons.people_outline_rounded,
                                          size: 15,
                                          color: mode == 'all' ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'All previous recipients',
                                            style: TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 12,
                                              color: mode == 'all' ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                                              fontWeight: mode == 'all' ? FontWeight.w700 : FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: busy ? null : (v) => edit(() => mode = v!),
                            ),
                          ] else ...[
                            // "Phone numbers" Text Field
                            TextField(
                              controller: phones,
                              enabled: !busy,
                              minLines: 2,
                              maxLines: 4,
                              onChanged: (_) => edit(() {}),
                              keyboardType: TextInputType.multiline,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Phone numbers',
                                labelStyle: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                hintText:
                                    'Enter phone numbers\ne.g. 9876543210, 9123456780, 9988776655',
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8).withValues(alpha: 0.9),
                                  height: 1.35,
                                  fontWeight: FontWeight.w400,
                                ),
                                contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00A86B),
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFCFDFD),
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Helper row: info icon + note on left, live counter on right
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 13,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text(
                                    'Add multiple numbers separated by commas (,) or line breaks.',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$phoneCount ${phoneCount == 1 ? "number" : "numbers"}',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Customer group Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: group,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              menuMaxHeight: 250,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF1E293B),
                                size: 20,
                              ),
                              selectedItemBuilder: (BuildContext context) {
                                return [
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Select customer group',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  for (final g in groups)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        g['name'].toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 12,
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ];
                              },
                              decoration: InputDecoration(
                                labelText: 'Customer group',
                                labelStyle: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                prefixIcon: const Icon(
                                  Icons.people_outline_rounded,
                                  color: Color(0xFF475569),
                                  size: 18,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00A86B),
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFCFDFD),
                              ),
                              hint: const Text(
                                'Select customer group',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: '',
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: (group == null || group == '')
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: (group == null || group == '')
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.people_outline_rounded,
                                          size: 15,
                                          color: Color(0xFF64748B),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Select customer group',
                                            style: TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                for (final g in groups)
                                  DropdownMenuItem(
                                    value: g['id'].toString(),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: group == g['id'].toString()
                                            ? const Color(0xFFF0FDF4)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: group == g['id'].toString()
                                              ? const Color(0xFF86EFAC)
                                              : const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            group == g['id'].toString()
                                                ? Icons.check_circle_rounded
                                                : Icons.group_rounded,
                                            size: 15,
                                            color: group == g['id'].toString()
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              g['name'].toString(),
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 12,
                                                color: group == g['id'].toString()
                                                    ? const Color(0xFF15803D)
                                                    : const Color(0xFF0F172A),
                                                fontWeight: group == g['id'].toString()
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: busy ? null : (v) => edit(() => group = v),
                            ),
                            if (groupError != null) ...[
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: loadGroups,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 22),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  '$groupError Tap to retry',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 11,
                                    color: Color(0xFF00A86B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],

                          // Quote Summary Card
                          if (quote != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${quote!['count']} recipients ready",
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                        Text(
                                          "₹${(quote!['totalAmount'] as num).toStringAsFixed(2)} total cost including GST",
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 10.5,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Error message banner
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      error!,
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 11,
                                        color: Color(0xFFB91C1C),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Action Buttons: Cancel & Check audience / Confirm send
                          Row(
                            children: [
                              // Cancel button
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 40,
                                  child: Material(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: busy
                                          ? null
                                          : () => Navigator.pop(context),
                                      child: const Center(
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Primary Action Button
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 40,
                                  child: Material(
                                    color: canSubmit
                                        ? const Color(0xFF00A86B)
                                        : const Color(0xFFCBD5E1),
                                    borderRadius: BorderRadius.circular(20),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: canSubmit ? submit : null,
                                      child: Center(
                                        child: busy
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Transform.rotate(
                                                    angle: -0.4,
                                                    child: const Icon(
                                                      Icons.send_rounded,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    quote == null
                                                        ? 'Check audience'
                                                        : 'Confirm send',
                                                    style: const TextStyle(
                                                      fontFamily: 'Roboto',
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                      letterSpacing: 0.1,
                                                    ),
                                                  ),
                                                ],
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paper airplane with dotted flight loop path graphic matching the design mockup
class _PaperPlaneFlightGraphic extends StatelessWidget {
  const _PaperPlaneFlightGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedFlightTrailPainter(),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Transform.rotate(
              angle: 0.25,
              child: const Icon(
                Icons.send_rounded,
                color: Color(0xFF00A86B),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedFlightTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00A86B).withValues(alpha: 0.7)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.05, size.height * 0.82);
    path.cubicTo(
      size.width * 0.18,
      size.height * 1.05,
      size.width * 0.42,
      size.height * 0.7,
      size.width * 0.38,
      size.height * 0.45,
    );
    path.cubicTo(
      size.width * 0.34,
      size.height * 0.18,
      size.width * 0.58,
      size.height * 0.16,
      size.width * 0.76,
      size.height * 0.22,
    );

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashLength = 3.2;
      const spaceLength = 3.2;
      while (distance < metric.length) {
        final extractLength = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + extractLength);
        canvas.drawPath(extract, paint);
        distance += dashLength + spaceLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
