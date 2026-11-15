import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class IncomingOrderLine {
  final String name, variant, note;
  final num quantity;
  final double unitPrice;
  final bool? isVeg;
  const IncomingOrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.variant = '',
    this.note = '',
    this.isVeg,
  });
}

const _green = Color(0xFF008764);
const _ink = Color(0xFF142B32);
const _muted = Color(0xFF71838B);
const _border = Color(0xFFE1E9EC);

/// Presentation for incoming orders; action and table state stay in the screen.
class IncomingOrderAcceptView extends StatelessWidget {
  final String orderNumber,
      customerName,
      customerPhone,
      address,
      orderType,
      source,
      currency;
  final String? tableNumber;
  final bool tableOrder, muted, processing;
  final DateTime createdAt;
  final double totalAmount;
  final List<IncomingOrderLine> items;
  final List<int> prepTimes;
  final int selectedPrepTime;
  final ValueListenable<int> secondsRemaining;
  final ValueChanged<int> onPrepTime;
  final VoidCallback onClose, onMute, onCall, onChat, onAccept, onDecline;

  const IncomingOrderAcceptView({
    super.key,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.orderType,
    required this.source,
    required this.currency,
    required this.tableNumber,
    required this.tableOrder,
    required this.muted,
    required this.processing,
    required this.createdAt,
    required this.totalAmount,
    required this.items,
    required this.prepTimes,
    required this.selectedPrepTime,
    required this.secondsRemaining,
    required this.onPrepTime,
    required this.onClose,
    required this.onMute,
    required this.onCall,
    required this.onChat,
    required this.onAccept,
    required this.onDecline,
  });

  bool get delivery =>
      !tableOrder && orderType.toLowerCase().contains('delivery');
  String money(double value) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: currency,
    decimalDigits: value % 1 == 0 ? 0 : 2,
  ).format(value);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F7F8),
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('incoming-order-scroll'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _overview(),
                      const SizedBox(height: 14),
                      _itemsCard(),
                      const SizedBox(height: 14),
                      _bill(),
                      const SizedBox(height: 14),
                      _preparation(),
                    ],
                  ),
                ),
              ),
              _actions(context),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Close order',
          onPressed: processing ? null : onClose,
          icon: const Icon(Icons.close_rounded, size: 21, color: _ink),
        ),
        const Expanded(
          child: Text(
            'Incoming order',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: secondsRemaining,
          builder: (_, seconds, child) {
            final urgent = seconds <= 30;
            return Semantics(
              label: '$seconds seconds remaining',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: urgent ? const Color(0xFFFFECEF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: urgent ? const Color(0xFFFDD4DB) : _border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: urgent ? const Color(0xFFCD3851) : _muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${seconds}s',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: urgent ? const Color(0xFFCD3851) : _ink,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: muted ? 'Unmute order alert' : 'Mute order alert',
          onPressed: onMute,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            size: 20,
            color: _muted,
          ),
        ),
      ],
    ),
  );

  Widget _overview() {
    final title = tableOrder
        ? (tableNumber == null ? 'Dine-in order' : 'Table $tableNumber')
        : (delivery ? 'Delivery order' : 'Takeaway order');
    final normalizedSource = source.trim().toLowerCase();
    final sourceLabel = normalizedSource.contains('whatsapp')
        ? 'WhatsApp'
        : ['pos', 'counter', 'local', 'store'].contains(normalizedSource)
        ? 'Store'
        : 'Online';
    final label = tableOrder
        ? (normalizedSource.contains('qr') || normalizedSource == 'storefront'
              ? 'TABLE QR ORDER'
              : 'DINE-IN ORDER')
        : '${sourceLabel.toUpperCase()} ORDER';
    final name =
        customerName.trim().isEmpty || customerName.trim() == 'Customer'
        ? 'Customer'
        : customerName.trim();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE6F6EF), Color(0xFFF5FBF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        tableOrder
                            ? Icons.table_restaurant_rounded
                            : (delivery
                                  ? Icons.delivery_dining_rounded
                                  : Icons.shopping_bag_outlined),
                        color: _green,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: _green,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            key: const ValueKey('incoming-order-table'),
                            style: const TextStyle(
                              fontSize: 27,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Source: $sourceLabel',
                  key: const ValueKey('incoming-order-source'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
                if (tableOrder && tableNumber == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Table number not provided',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 5,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      orderNumber.startsWith('#')
                          ? orderNumber
                          : '#$orderNumber',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      DateFormat('h:mm a · d MMM').format(createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFF0F4F6),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: _muted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      if (customerPhone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            customerPhone,
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ),
                    ],
                  ),
                ),
                if (customerPhone.isNotEmpty) ...[
                  _contactButton(
                    Icons.call_rounded,
                    'Call customer',
                    onCall,
                    const Color(0xFF2869BB),
                    const Color(0xFFEDF4FD),
                  ),
                  const SizedBox(width: 6),
                  _contactButton(
                    Icons.chat_bubble_outline_rounded,
                    'Message customer',
                    onChat,
                    _green,
                    const Color(0xFFECF9F2),
                  ),
                ],
              ],
            ),
          ),
          if (delivery && address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: _muted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _contactButton(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color,
    Color background,
  ) => SizedBox(
    width: 36,
    height: 36,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: color,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 17),
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _itemsCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Order items',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  fontSize: 10,
                  color: _muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Items are syncing...',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Divider(height: 1, color: _border),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _line(items[i]),
          ),
        ],
      ],
    ),
  );

  Widget _line(IncomingOrderLine item) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (item.isVeg != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.radio_button_checked,
            size: 15,
            color: item.isVeg!
                ? const Color(0xFF20AC70)
                : const Color(0xFFC95959),
          ),
        ),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            if (item.variant.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  item.variant,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            if (item.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  'Note: ${item.note}',
                  style: const TextStyle(
                    color: Color(0xFFAA751B),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            money(item.unitPrice * item.quantity),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${item.quantity}x',
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _bill() {
    var subtotal = items.fold(
      0.0,
      (total, item) => total + item.unitPrice * item.quantity,
    );
    if (subtotal <= 0 && totalAmount > 0) subtotal = totalAmount;
    final charges = (totalAmount - subtotal).clamp(0.0, double.infinity);
    return _card(
      Column(
        children: [
          _billRow('Item subtotal', money(subtotal)),
          if (charges > 0) ...[
            const SizedBox(height: 9),
            _billRow('Taxes & charges', '+${money(charges)}'),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: _border),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total amount',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tableOrder ? 'Pay at counter / table' : 'Pending payment',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                money(totalAmount),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: _green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(String title, String value) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontSize: 12, color: _muted)),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
    ],
  );

  Widget _preparation() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule_rounded, color: _green, size: 17),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Preparation time',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'How long will the kitchen need?',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, constraints) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prepTimes.map((time) {
              final selected = time == selectedPrepTime;
              return SizedBox(
                width: (constraints.maxWidth - 16) / 3,
                child: Semantics(
                  selected: selected,
                  button: true,
                  child: Material(
                    color: selected ? _green : const Color(0xFFF5F8F9),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: processing ? null : () => onPrepTime(time),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? _green : _border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$time mins',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : _ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );

  Widget _actions(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _border)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          height: 50,
          child: OutlinedButton(
            onPressed: processing ? null : onDecline,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCB4653),
              side: const BorderSide(color: Color(0xFFF0CDD2)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Decline',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: processing ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _green.withValues(alpha: .65),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tableOrder
                                ? Icons.soup_kitchen_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 17,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            tableOrder
                                ? 'Accept & send to kitchen'
                                : 'Accept order',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}
