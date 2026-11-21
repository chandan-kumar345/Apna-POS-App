import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/services/upload_service.dart';
import 'campaign_style.dart';
import 'mobile_campaign_data.dart';

part 'campaign_reward_step.dart';
part 'campaign_message_steps.dart';

class CampaignEditor extends StatefulWidget {
  final MobileCampaignDraft draft;
  final CampaignOptions options;
  final MobileCampaignApi api;
  final bool approved;
  const CampaignEditor({
    super.key,
    required this.draft,
    required this.options,
    required this.api,
    this.approved = false,
  });
  @override
  State<CampaignEditor> createState() => _CampaignEditorState();
}

class _CampaignEditorState extends State<CampaignEditor> {
  MobileCampaignDraft get d => widget.draft;
  CampaignOptions get options => widget.options;
  final scroll = ScrollController();
  int step = 0;
  bool busy = false,
      uploading = false,
      optedIn = false,
      rewardOpen = false,
      ordersOpen = false;
  String? error;
  static const titles = [
    'Create campaign',
    'Campaign message',
    'Interactive actions',
    'Review campaign',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.approved) step = 3;
    if (d.channel.isEmpty) {
      final channel = options.channels
          .where((c) => c['connected'] == true)
          .firstOrNull;
      d.channel = channel?['id'] ?? '';
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void change(VoidCallback update) => setState(() {
    update();
    error = null;
  });
  void go(int target) {
    FocusManager.instance.primaryFocus?.unfocus();
    change(() => step = target);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void back() {
    if (step > 0 && !widget.approved) {
      go(step - 1);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> chooseDate(
    bool schedule, {
    bool onlyDay = false,
    bool onlyTime = false,
  }) async {
    final local = indiaClock(
      (schedule ? d.sendAt : d.expiry) ??
          DateTime.now().add(const Duration(hours: 1)),
    );
    final now = indiaClock(DateTime.now());
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year + 10, 12, 31);
    final day = DateTime(local.year, local.month, local.day);
    final date = onlyTime
        ? day
        : await showDatePicker(
            context: context,
            helpText: schedule ? 'Schedule date · IST' : 'Expiry date · IST',
            initialDate: day.isBefore(first)
                ? first
                : day.isAfter(last)
                ? last
                : day,
            firstDate: first,
            lastDate: last,
          );
    if (date == null || !mounted) return;
    final currentTime = TimeOfDay(hour: local.hour, minute: local.minute);
    final time = onlyDay
        ? currentTime
        : await showTimePicker(
            context: context,
            helpText: 'India time (IST)',
            initialTime: currentTime,
          );
    if (time == null || !mounted) return;
    final instant = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).subtract(istOffset);
    change(() {
      if (schedule) {
        d.sendAt = instant;
      } else {
        d.expiry = instant;
      }
    });
  }

  Future<void> pickImage() async {
    change(() => uploading = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final url = await UploadService().uploadImageBytes(
        await file.readAsBytes(),
        fileName: file.name,
        folder: 'campaigns',
      );
      if (url == null || url.isEmpty) {
        throw StateError('Image upload failed. Please try again.');
      }
      if (mounted) change(() => d.image = url);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  String? get launchError {
    if (widget.approved && d.category == 'AUTHENTICATION') {
      return 'Auth is for customer-requested verification codes. Choose Marketing or Utility to send this campaign.';
    }
    if (!options.channels.any(
      (c) => c['id'] == d.channel && c['connected'] == true,
    )) {
      return 'Connect the selected WhatsApp channel before sending.';
    }
    if (!widget.approved) {
      return d.rewardError ?? d.messageError ?? d.actionError;
    }
    if ((options.group(d.group)?['count'] ?? 0) == 0) {
      return 'Select an audience with WhatsApp contacts.';
    }
    if (!optedIn) return 'Confirm that the selected contacts opted in.';
    if (d.later &&
        (d.sendAt?.isAfter(DateTime.now()) != true ||
            !d.sendAt!.isBefore(d.expiry!))) {
      return 'Choose a sending time before the offer expires.';
    }
    return d.rewardError ?? d.messageError ?? d.actionError;
  }

  Future<void> persist({bool launch = false}) async {
    if (busy || uploading) return;
    change(() => busy = true);
    try {
      if (widget.approved) {
        await widget.api.launch(d, options.group(d.group)!['count'] as int);
      } else {
        final saved = await widget.api.save(d);
        d.revision = saved['mobileStudio']['revision'];
        if (launch) await widget.api.submit(d);
      }
      if (mounted) {
        Navigator.pop(
          context,
          widget.approved
              ? (d.later ? 'Campaign scheduled' : 'Campaign queued for sending')
              : launch
              ? 'Campaign queued for Meta review'
              : 'Draft saved',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = switch (step) {
      0 => d.rewardError,
      1 => d.messageError,
      2 => d.actionError,
      _ => launchError,
    };
    final next = [
      'Next',
      'Next: Actions',
      'Review campaign',
      !widget.approved
          ? 'Submit for review'
          : d.later
          ? 'Schedule campaign'
          : 'Send campaign',
    ][step];
    return PopScope(
      canPop: (widget.approved || step == 0) && !busy,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && !busy && step > 0 && !widget.approved) go(step - 1);
      },
      child: CampaignShell(
        header: SizedBox(
          height: 54,
          child: Row(
            children: [
              IconButton(
                onPressed: busy ? null : back,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  widget.approved ? 'Send approved campaign' : titles[step],
                  style: campaignText(
                    21,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (step == 1 || step == 2)
                IconButton(
                  tooltip: 'Save draft',
                  onPressed: busy || uploading ? null : persist,
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 5),
              child: _Progress(step: step),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: AbsorbPointer(
                  absorbing: busy,
                  child: switch (step) {
                    0 => rewardStep(),
                    1 => messageStep(),
                    2 => actionStep(),
                    _ => reviewStep(),
                  },
                ),
              ),
            ),
          ],
        ),
        footer: Container(
          padding: const EdgeInsets.fromLTRB(15, 9, 15, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF5FAFD),
            border: Border(top: BorderSide(color: borderBlue)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    error!,
                    style: campaignText(13, color: const Color(0xFF9D3229)),
                  ),
                ),
              Row(
                children: [
                  TextButton(
                    onPressed: busy || uploading
                        ? null
                        : (widget.approved
                              ? back
                              : step == 0 || step == 3
                              ? persist
                              : back),
                    child: Text(
                      widget.approved
                          ? 'Close'
                          : step == 0 || step == 3
                          ? 'Save draft'
                          : 'Back',
                      style: campaignText(
                        14,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 3,
                    child: CampaignPrimary(
                      busy ? 'Saving…' : next,
                      icon: step == 3
                          ? Icons.send_outlined
                          : Icons.arrow_forward_rounded,
                      trailing: step != 3,
                      onTap: issue != null || busy || uploading
                          ? null
                          : () => step == 3
                                ? persist(launch: true)
                                : go(step + 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final int step;
  const _Progress({required this.step});
  @override
  Widget build(BuildContext context) {
    final stage = step == 0
        ? 0
        : step == 3
        ? 2
        : 1;
    return Row(
      children: [
        for (final (i, label) in const [
          'Reward',
          'Message',
          'Review',
        ].indexed) ...[
          if (i > 0)
            const Expanded(
              child: Divider(color: Color(0xFFA6BDCF), indent: 3, endIndent: 3),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(5, 5, 8, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: stage == i ? teal : const Color(0xFFE1EEF7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white,
                  child: stage > i
                      ? const Icon(Icons.check_rounded, size: 14, color: teal)
                      : Text('${i + 1}', style: campaignText(13)),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: campaignText(
                    12,
                    weight: FontWeight.w600,
                    color: stage == i ? Colors.white : ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

const _gap = SizedBox(height: 9);
Widget _stack(List<Widget> items) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
Widget _panel(Color tint, List<Widget> children) => Container(
  padding: const EdgeInsets.all(11),
  decoration: campaignCard(color: tint, shadow: false),
  child: _stack(children),
);
Widget _notice(IconData icon, String text, Color tint, Color fg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  decoration: BoxDecoration(
    color: tint,
    borderRadius: BorderRadius.circular(13),
  ),
  child: Row(
    children: [
      Icon(icon, size: 21, color: fg),
      const SizedBox(width: 9),
      Expanded(
        child: Text(text, style: campaignText(13, color: fg)),
      ),
    ],
  ),
);
