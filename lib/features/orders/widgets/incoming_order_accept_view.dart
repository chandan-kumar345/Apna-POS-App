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

// Ultra-clean design system tokens
const _primaryGreen = Color(0xFF059669); // Emerald 600
const _darkInk = Color(0xFF0F172A); // Slate 900
const _slateMuted = Color(0xFF64748B); // Slate 500
const _cardBorder = Color(0xFFE2E8F0); // Slate 200
const _bgSurface = Color(0xFFF8FAFC); // Slate 50
const _dangerRed = Color(0xFFE11D48); // Rose 600

/// Clean, high-conversion presentation for incoming orders; action and table state stay in the screen.
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
    backgroundColor: _bgSurface,
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _overviewCard(),
                      const SizedBox(height: 14),
                      _itemsCard(),
                      const SizedBox(height: 14),
                      _billCard(),
                      const SizedBox(height: 14),
                      _preparationCard(),
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

  Widget _topBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Close order',
          onPressed: processing ? null : onClose,
          icon: const Icon(Icons.close_rounded, size: 22, color: _darkInk),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: _cardBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(8),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Incoming order',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _darkInk,
              letterSpacing: -0.3,
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
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: urgent ? const Color(0xFFFEF2F2) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: urgent ? const Color(0xFFFECACA) : _cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: urgent ? _dangerRed : _slateMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${seconds}s',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: urgent ? _dangerRed : _darkInk,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: muted ? 'Unmute order alert' : 'Mute order alert',
          onPressed: onMute,
          icon: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            size: 20,
            color: muted ? _dangerRed : _slateMuted,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: _cardBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    ),
  );

  Widget _overviewCard() {
    final title = tableOrder
        ? (tableNumber == null ? 'Dine-in order' : 'Table $tableNumber')
        : (delivery ? 'Delivery order' : 'Takeaway order');

    final normalizedSource = source.trim().toLowerCase();
    final sourceLabel = const {
      'whatsapp': 'WhatsApp', 'storefront': 'Storefront', 'profile': 'Storefront',
      'online': 'Online', 'store': 'Store', 'qr': 'Table QR', 'table_qr': 'Table QR',
    }[normalizedSource] ?? source;
    final badgeLabel = tableOrder
        ? (normalizedSource.contains('qr') || normalizedSource == 'storefront'
            ? 'TABLE QR ORDER'
            : 'DINE-IN ORDER')
        : (delivery ? 'DELIVERY ORDER' : 'TAKEAWAY ORDER');

    final name =
        customerName.trim().isEmpty || customerName.trim().toLowerCase() == 'customer'
            ? 'Guest Customer'
            : customerName.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upper Header Section with soft green gradient
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A059669),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        tableOrder
                            ? Icons.table_restaurant_rounded
                            : (delivery
                                ? Icons.delivery_dining_rounded
                                : Icons.shopping_bag_outlined),
                        color: _primaryGreen,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.0,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            title,
                            key: const ValueKey('incoming-order-table'),
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              color: _darkInk,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (sourceLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(sourceLabel, key: const ValueKey('incoming-order-source'),
                              style: const TextStyle(fontSize: 11, color: _slateMuted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (tableOrder && tableNumber == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Table number not provided',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      orderNumber.startsWith('#') ? orderNumber : '#$orderNumber',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _darkInk,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      DateFormat('h:mm a · d MMM').format(createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _slateMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Customer Details Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _darkInk,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _darkInk,
                        ),
                      ),
                      if (customerPhone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            customerPhone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _slateMuted,
                              fontWeight: FontWeight.w500,
                            ),
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
                    const Color(0xFF2563EB),
                    const Color(0xFFEFF6FF),
                  ),
                  const SizedBox(width: 8),
                  _contactButton(
                    Icons.chat_bubble_outline_rounded,
                    'Message customer',
                    onChat,
                    _primaryGreen,
                    const Color(0xFFECFDF5),
                  ),
                ],
              ],
            ),
          ),
          if (delivery && address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: _slateMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          color: _darkInk,
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
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
    width: 38,
    height: 38,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: color,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 18),
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _cardBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x060F172A),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _darkInk,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: _slateMuted,
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
              style: TextStyle(color: _slateMuted, fontSize: 13),
            ),
          ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _cardBorder),
            ),
          _line(items[i]),
        ],
      ],
    ),
  );

  Widget _line(IncomingOrderLine item) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (item.isVeg != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(
                color: item.isVeg! ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.isVeg! ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: _darkInk,
              ),
            ),
            if (item.variant.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  item.variant,
                  style: const TextStyle(color: _slateMuted, fontSize: 12),
                ),
              ),
            if (item.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Note: ${item.note}',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            money(item.unitPrice * item.quantity),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: _darkInk,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                color: _slateMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _billCard() {
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
            const SizedBox(height: 10),
            _billRow('Taxes & charges', '+${money(charges)}'),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: _cardBorder),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total amount',
                  style: TextStyle(
                    color: _darkInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                money(totalAmount),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: _primaryGreen,
                  letterSpacing: -0.5,
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
        child: Text(
          title,
          style: const TextStyle(fontSize: 13, color: _slateMuted, fontWeight: FontWeight.w500),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _darkInk,
        ),
      ),
    ],
  );

  Widget _preparationCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule_rounded, color: _primaryGreen, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Preparation time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _darkInk,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
                    color: selected ? _primaryGreen : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: processing ? null : () => onPrepTime(time),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? _primaryGreen : _cardBorder,
                            width: selected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$time mins',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : _darkInk,
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
      14,
      16,
      14 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _cardBorder)),
      boxShadow: [
        BoxShadow(
          color: Color(0x060F172A),
          blurRadius: 10,
          offset: Offset(0, -3),
        ),
      ],
    ),
    child: Row(
      children: [
        SizedBox(
          width: 105,
          height: 52,
          child: OutlinedButton(
            onPressed: processing ? null : onDecline,
            style: OutlinedButton.styleFrom(
              foregroundColor: _dangerRed,
              side: const BorderSide(color: Color(0xFFFECDD3), width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Decline',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: processing ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryGreen.withValues(alpha: .65),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 1,
              ),
              child: processing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
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
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tableOrder
                                ? 'Accept & send to kitchen'
                                : 'Accept order',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
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
