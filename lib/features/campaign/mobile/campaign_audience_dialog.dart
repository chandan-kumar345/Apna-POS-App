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
  bool consent = false, busy = false;
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
      if (mounted)
        setState(() {
          groups = options.groups;
          groupError = null;
        });
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

  Future<void> submit() async {
    if (busy) return;
    final confirm = quote != null;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.followUp(
        (widget.campaign['id'] ?? widget.campaign['_id']).toString(),
        {
          'mode': mode,
          'groupId': group,
          'requestId': requestId,
          'confirmedOptIn': consent,
          'phones': phones.text
              .split(RegExp(r'[,;\n]'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList(),
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
      if (mounted)
        setState(() {
          error = e.toString();
          quote = null;
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = ThemeData.light(useMaterial3: true);
    return Theme(
      data: light.copyWith(
        colorScheme: light.colorScheme.copyWith(primary: teal),
      ),
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        title: Text(
          widget.resend ? 'Resend campaign' : 'Send to new customers',
          style: campaignText(18, color: ink, weight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.resend)
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Recipients'),
                  items: const [
                    DropdownMenuItem(
                      value: 'failed',
                      child: Text('Failed recipients only'),
                    ),
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All previous recipients'),
                    ),
                  ],
                  onChanged: busy ? null : (v) => edit(() => mode = v!),
                )
              else ...[
                TextField(
                  controller: phones,
                  enabled: !busy,
                  minLines: 3,
                  maxLines: 5,
                  onChanged: (_) => edit(() {}),
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Phone numbers',
                    hintText: 'One per line, or separated by commas',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: group,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Customer group',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('No group')),
                    for (final g in groups)
                      DropdownMenuItem(
                        value: g['id'].toString(),
                        child: Text(
                          g['name'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy ? null : (v) => edit(() => group = v),
                ),
                if (groupError != null)
                  TextButton(
                    onPressed: loadGroups,
                    child: Text('$groupError Retry'),
                  ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: consent,
                title: const Text(
                  'These customers opted in to WhatsApp messages.',
                ),
                onChanged: busy ? null : (v) => edit(() => consent = v == true),
              ),
              if (quote != null)
                Text(
                  "${quote!['count']} recipients · ₹${(quote!['totalAmount'] as num).toStringAsFixed(2)} including GST",
                  style: campaignText(14),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Color(0xFF9B241B))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed:
                busy ||
                    !consent ||
                    (mode == 'new' &&
                        phones.text.trim().isEmpty &&
                        (group ?? '').isEmpty)
                ? null
                : submit,
            child: Text(
              busy
                  ? 'Please wait…'
                  : quote == null
                  ? 'Check audience'
                  : 'Confirm send',
            ),
          ),
        ],
      ),
    );
  }
}
