part of 'campaign_editor.dart';

const _actionIcons = {
  'URL': Icons.link_rounded,
  'PHONE_NUMBER': Icons.call_outlined,
  'QUICK_REPLY': Icons.chat_bubble_outline_rounded,
};

extension _MessageForm on _CampaignEditorState {
  Widget messageStep() => _stack([
    CampaignSelect(
      'Meta channel',
      d.channel,
      {
        for (final c in options.channels)
          c['id'] as String:
              'WhatsApp · ${c['name']}${c['connected'] == true ? '' : ' (disconnected)'}',
      },
      (s) => change(() => d.channel = s),
      hint: 'Select WhatsApp channel',
    ),
    _gap,
    CampaignSelect(
      'Message category',
      d.category,
      campaignCategories,
      (s) => change(() => d.category = s),
    ),
    if (d.category == 'AUTHENTICATION') ...[
      _gap,
      _notice(
        Icons.key_rounded,
        'Meta uses a standard message and a Copy code button for verification codes.',
        const Color(0xFFFFF2CC),
        const Color(0xFF7A5413),
      ),
    ],
    _gap,
    CampaignField(
      'Campaign title',
      d.title,
      (s) => change(() => d.title = s),
      hint: 'Weekend Pizza Offer',
      limit: 100,
    ),
    _gap,
    if (d.category == 'AUTHENTICATION')
      _notice(
        Icons.key_rounded,
        '•••••• is your verification code.',
        const Color(0xFFE1F4E9),
        teal,
      )
    else ...[
      CampaignField(
        'Campaign description',
        d.body,
        (s) => change(() => d.body = s),
        lines: 4,
        limit: 1024,
        hint: 'Hi {{name}} 👋\nEnter your campaign message',
      ),
      _gap,
      const CampaignLabel('Campaign image'),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: campaignCard(),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 86,
                  child: d.image.isEmpty
                      ? ColoredBox(
                          color: const Color(0xFFE3EEF6),
                          child: const Center(
                            child: Icon(
                              Icons.photo_outlined,
                              size: 32,
                              color: muted,
                            ),
                          ),
                        )
                      : _campaignImage(d.image),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextButton(
                onPressed: uploading ? null : pickImage,
                child: Column(
                  children: [
                    if (uploading)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.file_upload_outlined,
                        size: 24,
                        color: teal,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      uploading
                          ? 'Uploading…'
                          : d.image.isEmpty
                          ? 'Add image'
                          : 'Change image',
                      textAlign: TextAlign.center,
                      style: campaignText(13),
                    ),
                  ],
                ),
              ),
            ),
            if (d.image.isNotEmpty)
              IconButton(
                tooltip: 'Remove image',
                onPressed: uploading ? null : () => change(() => d.image = ''),
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    ],
  ]);

  void addAction(String type) {
    if (d.actions.length < 3) {
      change(() => d.actions.add(MessageAction(type: type)));
    }
  }

  Widget actionStep() => d.category == 'AUTHENTICATION'
      ? _panel(const Color(0xFFDCF7E5), [
          const CampaignLabel('Verification button'),
          _notice(Icons.copy_rounded, 'Copy code', Colors.white, teal),
        ])
      : _stack([
          Text(
            'Make your message actionable',
            style: campaignText(19, weight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            'Add buttons for customers to respond.',
            style: campaignText(14, color: muted, weight: FontWeight.w400),
          ),
          _gap,
          for (final (i, a) in d.actions.indexed) ...[
            KeyedSubtree(
              key: ObjectKey(a),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: campaignCard(),
                child: _stack([
                  Row(
                    children: [
                      CampaignIconTile(
                        _actionIcons[a.type]!,
                        i == 1
                            ? const Color(0xFFD8F6DF)
                            : const Color(0xFFDCEEFF),
                        i == 1 ? const Color(0xFF227140) : teal,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            'Primary action',
                            'Secondary action',
                            'Third action',
                          ][i],
                          style: campaignText(17, weight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove action ${i + 1}',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => change(() => d.actions.removeAt(i)),
                        icon: const Icon(Icons.close, size: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  CampaignSelect(
                    'Action type',
                    a.type,
                    campaignActions,
                    (s) => change(() {
                      a.type = s;
                      a.value = '';
                    }),
                    inline: true,
                  ),
                  const SizedBox(height: 7),
                  CampaignField(
                    'Button text',
                    a.text,
                    (s) => change(() => a.text = s),
                    inline: true,
                    limit: 25,
                    hint: switch (a.type) {
                      'URL' => 'Order now',
                      'PHONE_NUMBER' => 'Call store',
                      _ => 'Reply',
                    },
                  ),
                  if (a.type != 'QUICK_REPLY') ...[
                    const SizedBox(height: 7),
                    CampaignField(
                      a.type == 'URL' ? 'Website URL' : 'Phone number',
                      a.value,
                      (s) => change(() => a.value = s),
                      inline: true,
                      hint: a.type == 'URL' ? 'https://…' : '+91…',
                      limit: a.type == 'URL' ? 1024 : 32,
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (d.actions.length < 3) ...[
            OutlinedButton.icon(
              onPressed: () => addAction(
                d.actions.isEmpty
                    ? 'URL'
                    : d.actions.length == 1
                    ? 'PHONE_NUMBER'
                    : 'QUICK_REPLY',
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add action'),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 5,
              runSpacing: 4,
              children: [
                for (final e in campaignActions.entries)
                  ActionChip(
                    avatar: Icon(_actionIcons[e.key], size: 15, color: teal),
                    label: Text(e.value, style: campaignText(12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFFE0EFFB),
                    onPressed: () => addAction(e.key),
                  ),
              ],
            ),
          ],
          if (d.actions.isNotEmpty) ...[
            _gap,
            _panel(const Color(0xFFDCF7E5), [
              Text(
                'Preview buttons',
                style: campaignText(16, weight: FontWeight.w800),
              ),
              for (final a in d.actions) _previewAction(a),
            ]),
          ],
        ]);

  Widget reviewStep() {
    final style = rewardStyles[d.reward]!;
    final name =
        options.channels
            .where((c) => c['id'] == d.channel)
            .firstOrNull?['name'] ??
        '';
    final groupCount = options.group(d.group)?['count'] as int? ?? 0;
    final manualCount = extractNormalizedPhones(manualPhones.text).length;
    final totalCount = groupCount + manualCount;
    final label = campaignCategories[d.category] ?? '';
    final cost = totalCount * (d.category == 'UTILITY' ? .21 : .90) * 1.18;
    return _stack([
      Container(
        padding: const EdgeInsets.all(12),
        decoration: campaignCard(),
        child: _stack([
          Row(
            children: [
              CampaignIconTile(style.$2, style.$4, style.$3, size: 35),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.title,
                  style: campaignText(19, weight: FontWeight.w800),
                ),
              ),
              if (!widget.approved)
                IconButton(
                  tooltip: 'Edit reward',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => go(0),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
            ],
          ),
          const Divider(color: borderBlue, height: 12),
          _reviewLine('Order type', d.orderLabel),
          _reviewLine('Reward', d.summary(options)),
          if (d.minimum.isNotEmpty)
            _reviewLine('Minimum order', '₹${d.minimum}'),
          _reviewLine('Coupon', d.coupon.toUpperCase()),
          _reviewLine('Expires', '${campaignTime(d.expiry!)} IST'),
          _reviewLine('Channel', 'WhatsApp · $name · $label'),
        ]),
      ),
      _gap,
      if (d.category != 'AUTHENTICATION')
        CampaignSelect(
          'Audience',
          d.group,
          {
            for (final g in options.groups)
              g['id'] as String: '${g['name']} · ${g['count']} contacts',
          },
          (s) => change(() {
            d.group = s;
          }),
          hint: options.groups.isEmpty
              ? 'No audience groups yet'
              : 'Select audience group',
        ),
      if (d.category != 'AUTHENTICATION' && options.groups.isEmpty)
        Text(
          'Create an audience group in Customers.',
          style: campaignText(12, color: muted),
        ),

      // Enter mobile number (phone numbers text area with internal 91 prefix)
      if (widget.approved && d.category != 'AUTHENTICATION') ...[
        const SizedBox(height: 14),
        Text(
          'Enter mobile number',
          style: campaignText(15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF29B6F6),
              width: 1.4,
            ),
          ),
          child: Stack(
            children: [
              TextField(
                controller: manualPhones,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                onChanged: (_) => change(() {}),
                style: campaignText(14, weight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText:
                      'Enter mobile numbers\n(e.g. 9876543210, 9123456780)',
                  hintStyle: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    height: 1.35,
                  ),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Icon(
                      Icons.phone_outlined,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(12, 14, 28, 14),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Icon(
                  Icons.signal_cellular_alt_rounded,
                  size: 14,
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Add multiple numbers separated by commas (,) or line breaks.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$manualCount ${manualCount == 1 ? "number" : "numbers"}',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ],
      if (!widget.approved) const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: campaignCard(color: const Color(0xFFDCF6DD)),
        child: _stack([
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.category != 'AUTHENTICATION' && d.image.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 82,
                    height: 94,
                    child: _campaignImage(d.image),
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  d.category == 'AUTHENTICATION'
                      ? '•••••• is your verification code.'
                      : d.body.replaceAll('{{name}}', 'Rahul'),
                  style: campaignText(14, weight: FontWeight.w500),
                ),
              ),
              if (!widget.approved)
                IconButton(
                  tooltip: 'Edit message',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => go(1),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                ),
            ],
          ),
          if (d.category == 'AUTHENTICATION')
            _notice(Icons.copy, 'Copy code', Colors.white, teal)
          else
            for (final a in d.actions) _previewAction(a),
          if (d.category != 'AUTHENTICATION' &&
              d.actions.isNotEmpty &&
              !widget.approved)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => go(2),
                child: const Text('Edit buttons'),
              ),
            ),
        ]),
      ),
      _gap,
      if (widget.approved)
        Container(
          decoration: campaignCard(),
          child: Row(
            children: [
              for (final e in const {
                false: 'Send now',
                true: 'Schedule',
              }.entries)
                Expanded(
                  child: InkWell(
                    onTap: () => change(() => d.later = e.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            d.later == e.key
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: d.later == e.key
                                ? const Color(0xFF0978C8)
                                : muted,
                          ),
                          const SizedBox(width: 6),
                          Text(e.value, style: campaignText(14)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (widget.approved && d.later) ...[
        const SizedBox(height: 8),
        _picker(
          d.sendAt == null
              ? 'Choose sending time (IST)'
              : '${campaignTime(d.sendAt!)} IST',
          () => chooseDate(true),
          leading: const Icon(Icons.schedule, size: 18),
        ),
      ],
      const SizedBox(height: 9),
      Text(
        d.category == 'AUTHENTICATION'
            ? 'Approval is for individual, customer-requested verification codes.'
            : !widget.approved
            ? 'After Meta approves your template, choose when to send it from Campaigns.'
            : totalCount > 0
            ? '$totalCount contacts · Estimated wallet charge ₹${cost.toStringAsFixed(2)} including GST.'
            : 'Select an option for audience to send.',
        style: campaignText(12, color: muted, weight: FontWeight.w400),
      ),
      if (widget.approved && d.category != 'AUTHENTICATION') ...[
        const SizedBox(height: 10),
        CheckboxListTile(
          value: optedIn,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            'I confirm that recipients have consented to receive messages.',
            style: campaignText(12, color: muted),
          ),
          onChanged: (v) => change(() => optedIn = v ?? false),
        ),
      ],
      if (d.later &&
          d.sendAt != null &&
          launchError?.startsWith('Choose a sending') == true) ...[
        const SizedBox(height: 6),
        Text(
          launchError!,
          style: campaignText(12, color: const Color(0xFF943E2D)),
        ),
      ],
    ]);
  }
}

Widget _campaignImage(String url) => Image.network(
  url,
  fit: BoxFit.cover,
  errorBuilder: (_, _, _) => const ColoredBox(
    color: Color(0xFFE3EEF6),
    child: Center(child: Icon(Icons.broken_image_outlined, color: muted)),
  ),
);
Widget _previewAction(MessageAction a) => Container(
  margin: const EdgeInsets.only(top: 6),
  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
  decoration: BoxDecoration(
    border: Border.all(color: const Color(0xFF80B2A1)),
    borderRadius: BorderRadius.circular(9),
    color: const Color(0xFFF3FCF4),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(_actionIcons[a.type], size: 15, color: teal),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          a.text.isEmpty ? campaignActions[a.type]! : a.text,
          style: campaignText(14),
        ),
      ),
    ],
  ),
);
Widget _reviewLine(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 2, child: Text(label, style: campaignText(13))),
      Expanded(
        flex: 3,
        child: Text(value, style: campaignText(13, weight: FontWeight.w500)),
      ),
    ],
  ),
);
