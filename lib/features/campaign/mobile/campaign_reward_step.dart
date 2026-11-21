part of 'campaign_editor.dart';

extension _RewardForm on _CampaignEditorState {
  void toggleOrder(String key) => change(() {
    if (d.orders.contains(key)) {
      d.orders.remove(key);
    } else {
      d.orders.add(key);
    }
    d.orders = campaignOrders.keys.where(d.orders.contains).toList();
  });

  Widget rewardStep() {
    final style = rewardStyles[d.reward];
    final products = {
      for (final p in options.products) p['id'] as String: p['name'] as String,
    };
    final date = d.expiry;
    return _stack([
      const CampaignLabel('Order type'),
      _picker(
        d.orders.isEmpty ? 'Select order type' : d.orderLabel,
        () => change(() => ordersOpen = !ordersOpen),
        open: ordersOpen,
      ),
      if (ordersOpen)
        Container(
          decoration: campaignCard(),
          child: _stack([
            for (final e in campaignOrders.entries)
              CheckboxListTile(
                dense: true,
                value: d.orders.contains(e.key),
                title: Text(e.value),
                onChanged: (_) => toggleOrder(e.key),
              ),
          ]),
        ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final (i, e) in campaignOrders.entries.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                selected: d.orders.contains(e.key),
                button: true,
                child: InkWell(
                  onTap: () => toggleOrder(e.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 37,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: campaignCard(
                      radius: 12,
                      color: d.orders.contains(e.key)
                          ? const Color(0xFFCBE9FF)
                          : Colors.white,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          Icon(
                            d.orders.contains(e.key)
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: d.orders.contains(e.key)
                                ? const Color(0xFF086DBD)
                                : muted,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(e.value, style: campaignText(13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      _gap,
      const CampaignLabel('Reward type'),
      _picker(
        style?.$1 ?? 'Select reward type',
        () => change(() => rewardOpen = !rewardOpen),
        open: rewardOpen,
        leading: style == null
            ? null
            : CampaignIconTile(style.$2, style.$4, style.$3, size: 28),
      ),
      if (rewardOpen) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: campaignCard(),
          child: _stack([
            for (final e in rewardStyles.entries)
              InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => change(() {
                  if (d.reward != e.key) {
                    d.amount = '';
                    d.cap = '';
                    d.minimum = '';
                    d.buy = '';
                    d.gift = '';
                    d.buyQty = 1;
                    d.giftQty = 1;
                    d.headline = '';
                    d.details = '';
                    d.terms = '';
                  }
                  d.reward = e.key;
                  rewardOpen = false;
                }),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: d.reward == e.key ? e.value.$4 : Colors.transparent,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      CampaignIconTile(
                        e.value.$2,
                        e.value.$4,
                        e.value.$3,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(e.value.$1, style: campaignText(15)),
                      ),
                      if (d.reward == e.key)
                        const Icon(Icons.check, size: 16, color: teal),
                    ],
                  ),
                ),
              ),
          ]),
        ),
      ],
      if (style == null) ...[
        const SizedBox(height: 22),
        _notice(
          Icons.card_giftcard_outlined,
          'Select a reward to configure its details.',
          const Color(0xFFDCEFFB),
          teal,
        ),
      ] else ...[
        _gap,
        KeyedSubtree(
          key: ValueKey(d.reward),
          child: _panel(style.$4, [
            Text(switch (d.reward) {
              'percentage' => 'Percentage discount',
              'flat_discount' => 'Flat discount details',
              'free_gift' => 'Free gift details',
              'bogo' => 'Buy one, get one',
              _ => 'Promotion details',
            }, style: campaignText(17, weight: FontWeight.w800)),
            const SizedBox(height: 9),
            if (d.reward == 'percentage' || d.reward == 'flat_discount') ...[
              CampaignField(
                d.reward == 'percentage'
                    ? 'Discount (%)'
                    : 'Discount amount (₹)',
                d.amount,
                (s) => change(() => d.amount = s),
                numeric: true,
              ),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _minimum()),
                  if (d.reward == 'percentage') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: CampaignField(
                        'Maximum discount (₹)',
                        d.cap,
                        (s) => change(() => d.cap = s),
                        numeric: true,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (d.reward == 'bogo') ...[
              CampaignSelect(
                'Buy item',
                d.buy,
                products,
                (s) => change(() => d.buy = s),
                hint: 'Choose menu item',
              ),
              _quantity(
                'Buy quantity',
                d.buyQty,
                (n) => change(() => d.buyQty = n),
              ),
              const SizedBox(height: 6),
            ],
            if (d.reward == 'free_gift' || d.reward == 'bogo') ...[
              CampaignSelect(
                d.reward == 'bogo' ? 'Get item' : 'Gift item',
                d.gift,
                products,
                (s) => change(() => d.gift = s),
                hint: products.isEmpty
                    ? 'No available menu items'
                    : 'Choose menu item',
              ),
              _quantity(
                d.reward == 'bogo' ? 'Free quantity' : 'Gift quantity',
                d.giftQty,
                (n) => change(() => d.giftQty = n),
              ),
              if (d.reward == 'free_gift') _minimum(),
            ],
            if (d.reward == 'promotional') ...[
              CampaignField(
                'Promotion headline',
                d.headline,
                (s) => change(() => d.headline = s),
              ),
              const SizedBox(height: 8),
              CampaignField(
                'Offer details',
                d.details,
                (s) => change(() => d.details = s),
                lines: 2,
                limit: 800,
              ),
              const SizedBox(height: 8),
              CampaignField(
                'Terms / eligibility',
                d.terms,
                (s) => change(() => d.terms = s),
                limit: 500,
              ),
            ],
          ]),
        ),
        _gap,
        CampaignField(
          'Coupon code',
          d.coupon,
          (s) => change(() => d.coupon = s),
          limit: 32,
          hint: 'e.g. WEEKEND20',
          suffix: IconButton(
            tooltip: 'Copy coupon code',
            iconSize: 18,
            icon: const Icon(Icons.copy_rounded),
            onPressed: d.coupon.trim().isEmpty
                ? null
                : () => Clipboard.setData(
                    ClipboardData(text: d.coupon.trim().toUpperCase()),
                  ),
          ),
        ),
        _gap,
        if (d.reward == 'percentage') ...[
          const CampaignLabel('Expiry date & time'),
          _picker(
            date == null ? 'Choose expiry' : campaignTime(date),
            () => chooseDate(false),
            leading: const Icon(Icons.calendar_month_outlined, size: 19),
          ),
          const SizedBox(height: 4),
          Text(
            'India time (IST)',
            style: campaignText(12, color: muted, weight: FontWeight.w400),
          ),
        ] else
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _stack([
                  const CampaignLabel('Expiry date'),
                  _picker(
                    date == null
                        ? 'Select date'
                        : DateFormat('d MMM yyyy').format(indiaClock(date)),
                    () => chooseDate(false, onlyDay: true),
                    leading: const Icon(
                      Icons.calendar_month_outlined,
                      size: 17,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _stack([
                  const CampaignLabel('Expiry time · IST'),
                  _picker(
                    date == null
                        ? 'Select time'
                        : DateFormat('h:mm a').format(indiaClock(date)),
                    () => chooseDate(false, onlyTime: true),
                  ),
                ]),
              ),
            ],
          ),
        _gap,
        _notice(
          style.$2,
          d.summary(options),
          d.reward == 'percentage' ? const Color(0xFFD0F4E1) : style.$4,
          d.reward == 'percentage' ? const Color(0xFF166634) : style.$3,
        ),
      ],
    ]);
  }

  Widget _minimum() => CampaignField(
    'Minimum order (₹)',
    d.minimum,
    (s) => change(() => d.minimum = s),
    numeric: true,
  );
}

Widget _picker(
  String text,
  VoidCallback tap, {
  Widget? leading,
  bool open = false,
}) => InkWell(
  onTap: tap,
  borderRadius: BorderRadius.circular(13),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: campaignCard(radius: 13, color: const Color(0xFFF9FCFF)),
    child: Row(
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 8)],
        Expanded(
          child: Text(text, style: campaignText(15, weight: FontWeight.w500)),
        ),
        Icon(
          open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          size: 21,
          color: ink,
        ),
      ],
    ),
  ),
);

Widget _quantity(String label, int value, ValueChanged<int> change) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Row(
    children: [
      Expanded(child: Text(label, style: campaignText(14))),
      Container(
        decoration: campaignCard(radius: 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Decrease $label',
              visualDensity: VisualDensity.compact,
              onPressed: value <= 1 ? null : () => change(value - 1),
              icon: const Icon(Icons.remove, size: 17),
            ),
            Text('$value', style: campaignText(14)),
            IconButton(
              tooltip: 'Increase $label',
              visualDensity: VisualDensity.compact,
              onPressed: value >= 999 ? null : () => change(value + 1),
              icon: const Icon(Icons.add, size: 17),
            ),
          ],
        ),
      ),
    ],
  ),
);
