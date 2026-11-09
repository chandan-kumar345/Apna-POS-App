import sys

path = 'lib/features/orders/incoming_order_accept_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Add tableNumber to constructor
old_constructor = '''  final String source;
  final bool autoAccept;
  final bool autoReject;

  const IncomingOrderAcceptScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.customerPhone,
    required this.customerName,
    required this.totalAmount,
    this.orderType = 'takeaway',
    this.deliveryAddress = '',
    this.items = const [],
    required this.createdAt,
    this.source = 'whatsapp',
    this.autoAccept = false,
    this.autoReject = false,
  });'''

new_constructor = '''  final String source;
  final String? tableNumber;
  final bool autoAccept;
  final bool autoReject;

  const IncomingOrderAcceptScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.customerPhone,
    required this.customerName,
    required this.totalAmount,
    this.orderType = 'takeaway',
    this.deliveryAddress = '',
    this.items = const [],
    required this.createdAt,
    this.source = 'whatsapp',
    this.tableNumber,
    this.autoAccept = false,
    this.autoReject = false,
  });'''

assert old_constructor in text, 'constructor not found'
text = text.replace(old_constructor, new_constructor, 1)

# 2. Add tableNumber parameter to open()
old_open_sig = '''  static Future<void> open(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required String customerPhone,
    String? customerName,
    required double totalAmount,
    String? orderType,
    String? deliveryAddress,
    dynamic itemsPayload,
    DateTime? createdAt,
    String? source,
    bool autoAccept = false,
    bool autoReject = false,
  }) async {'''

new_open_sig = '''  static Future<void> open(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required String customerPhone,
    String? customerName,
    required double totalAmount,
    String? orderType,
    String? deliveryAddress,
    dynamic itemsPayload,
    DateTime? createdAt,
    String? source,
    String? tableNumber,
    bool autoAccept = false,
    bool autoReject = false,
  }) async {'''

assert old_open_sig in text, 'open signature not found'
text = text.replace(old_open_sig, new_open_sig, 1)

# 3. Pass tableNumber to IncomingOrderAcceptScreen in open()
old_open_call = '''            return IncomingOrderAcceptScreen(
              orderId: orderId,
              orderNumber: orderNumber,
              customerPhone: customerPhone,
              customerName: customerName ?? 'Customer',
              totalAmount: totalAmount,
              orderType: orderType ?? 'takeaway',
              deliveryAddress: deliveryAddress ?? '',
              items: parsedItems,
              createdAt: effectiveCreatedAt,
              source: source ?? 'whatsapp',
              autoAccept: autoAccept,
              autoReject: autoReject,
            );'''

new_open_call = '''            return IncomingOrderAcceptScreen(
              orderId: orderId,
              orderNumber: orderNumber,
              customerPhone: customerPhone,
              customerName: customerName ?? 'Customer',
              totalAmount: totalAmount,
              orderType: orderType ?? 'takeaway',
              deliveryAddress: deliveryAddress ?? '',
              items: parsedItems,
              createdAt: effectiveCreatedAt,
              source: source ?? 'whatsapp',
              tableNumber: tableNumber,
              autoAccept: autoAccept,
              autoReject: autoReject,
            );'''

assert old_open_call in text, 'open call not found'
text = text.replace(old_open_call, new_open_call, 1)

# 4. Extract tableNumber in openFromPayload
old_payload_parse = '''    final deliveryAddress = metadata['deliveryAddress']?.toString() ??
        data['deliveryAddress']?.toString() ??
        '';'''

new_payload_parse = '''    final deliveryAddress = metadata['deliveryAddress']?.toString() ??
        data['deliveryAddress']?.toString() ??
        '';
    final tableNumber = metadata['tableNumber']?.toString() ??
        data['tableNumber']?.toString() ??
        metadata['table']?.toString() ??
        data['table']?.toString();'''

assert old_payload_parse in text, 'payload parse not found'
text = text.replace(old_payload_parse, new_payload_parse, 1)

old_payload_call = '''      source: source,
      autoAccept: autoAccept,
      autoReject: autoReject,
    );'''

new_payload_call = '''      source: source,
      tableNumber: tableNumber,
      autoAccept: autoAccept,
      autoReject: autoReject,
    );'''

assert old_payload_call in text, 'payload call not found'
text = text.replace(old_payload_call, new_payload_call, 1)

# 5. Add getters to _IncomingOrderAcceptScreenState
old_state_start = '''class _IncomingOrderAcceptScreenState extends State<IncomingOrderAcceptScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final DatabaseService _db = DatabaseService();'''

new_state_start = '''class _IncomingOrderAcceptScreenState extends State<IncomingOrderAcceptScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final DatabaseService _db = DatabaseService();

  String? get _resolvedTableNumber {
    if (widget.tableNumber != null && widget.tableNumber!.trim().isNotEmpty) {
      final clean = widget.tableNumber!.trim();
      return clean.replaceAll(RegExp(r'(?i)table\\s*'), '').trim().toUpperCase();
    }
    if (widget.deliveryAddress.isNotEmpty) {
      final match = RegExp(r'(?:table|tbl|t)\\s*[:#\\-]?\\s*([0-9a-zA-Z]+)', caseSensitive: false)
          .firstMatch(widget.deliveryAddress);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.toUpperCase();
      }
      if (widget.deliveryAddress.toLowerCase().contains('table')) {
        final cleaned = widget.deliveryAddress.replaceAll(RegExp(r'(?i)table\\s*'), '').trim();
        if (cleaned.isNotEmpty) return cleaned.toUpperCase();
      }
    }
    final matchName = RegExp(r'\\((?:table|tbl|t)?\\s*([0-9a-zA-Z]+)\\)', caseSensitive: false)
        .firstMatch(widget.customerName);
    if (matchName != null && matchName.group(1) != null) {
      return matchName.group(1)!.toUpperCase();
    }
    return null;
  }

  bool get _isTableOrder {
    final cleanType = widget.orderType.toLowerCase();
    final cleanSource = widget.source.toLowerCase();
    return cleanType.contains('dine') ||
           cleanType.contains('table') ||
           cleanSource.contains('qr') ||
           cleanSource.contains('table') ||
           widget.deliveryAddress.toLowerCase().contains('table') ||
           _resolvedTableNumber != null;
  }'''

assert old_state_start in text, 'state start not found'
text = text.replace(old_state_start, new_state_start, 1)

# 6. Update _buildTopAlertBar
target_top_alert_start = '  Widget _buildTopAlertBar() {\n'
target_top_alert_end = '  Widget _buildOrderHeaderCard() {\n'
a_start = text.find(target_top_alert_start)
a_end = text.find(target_top_alert_end)
assert a_start != -1 and a_end != -1, 'Top alert bar boundaries not found'

new_top_alert = '''  Widget _buildTopAlertBar() {
    final isTable = _isTableOrder;
    final tableNum = _resolvedTableNumber;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isTable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTable ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTable ? Icons.table_restaurant_rounded : Icons.notifications_active_rounded,
            color: isTable ? const Color(0xFF059669) : const Color(0xFFE11D48),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isTable
                  ? 'Table ${tableNum ?? "Dine-In"} QR order requires your action'
                  : 'Incoming order requires your action',
              style: TextStyle(
                color: isTable ? const Color(0xFF065F46) : const Color(0xFF9F1239),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isTable ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: isTable ? const Color(0xFF059669) : const Color(0xFFE11D48),
                ),
                const SizedBox(width: 3),
                Text(
                  '${_secondsRemaining}s',
                  style: TextStyle(
                    color: isTable ? const Color(0xFF059669) : const Color(0xFFE11D48),
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

'''

text = text[:a_start] + new_top_alert + text[a_end:]

# 7. Update _buildOrderHeaderCard
h_start = text.find('  Widget _buildOrderHeaderCard() {\n')
h_end = text.find('  Widget _buildCustomerCard(bool isDelivery) {\n')
assert h_start != -1 and h_end != -1, 'Order header card boundaries not found'

new_order_header = '''  Widget _buildOrderHeaderCard() {
    final orderNumDisplay = widget.orderNumber.startsWith('#')
        ? widget.orderNumber
        : '#${widget.orderNumber}';

    final isTable = _isTableOrder;
    final tableNum = _resolvedTableNumber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTable ? const Color(0xFFA7F3D0) : _borderSubtle.withValues(alpha: 0.8),
          width: isTable ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Emblem Container: Table QR Icon or WhatsApp Icon
          if (isTable)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x28059669),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.table_restaurant_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            )
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF1EBE5D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2825D366),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/whatsapp_logo.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isTable ? 'TABLE QR ORDER' : widget.source.toUpperCase(),
                      style: TextStyle(
                        color: isTable ? const Color(0xFF059669) : _textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (isTable) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DINE-IN',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      orderNumDisplay,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _mintBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NEW ORDER',
                        style: TextStyle(
                          color: _mintBadgeText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (isTable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.table_restaurant_rounded, size: 11, color: Color(0xFF047857)),
                            const SizedBox(width: 3),
                            Text(
                              'TABLE ${tableNum ?? "DINE-IN"}',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.orderType.toLowerCase() == 'delivery'
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.orderType.toUpperCase(),
                          style: TextStyle(
                            color: widget.orderType.toLowerCase() == 'delivery'
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF7E22CE),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Received : ${DateFormat('h:mm a • d MMM, yyyy').format(widget.createdAt.toLocal())}',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 11,
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

'''

text = text[:h_start] + new_order_header + text[h_end:]

# 8. Update _buildCustomerCard
c_start = text.find('  Widget _buildCustomerCard(bool isDelivery) {\n')
c_end = text.find('  Widget _buildItemsCard(NumberFormat currencyFormatter) {\n')
assert c_start != -1 and c_end != -1, 'Customer card boundaries not found'

new_customer_card = '''  Widget _buildCustomerCard(bool isDelivery) {
    final isTable = _isTableOrder;
    final tableNum = _resolvedTableNumber;

    final customerInitial = widget.customerName.isNotEmpty
        ? widget.customerName[0].toUpperCase()
        : (isTable ? 'T' : 'U');

    String displayName = widget.customerName.isNotEmpty && widget.customerName != 'Customer'
        ? widget.customerName
        : (isTable ? 'Guest Customer' : 'unknown');

    if (displayName.toLowerCase().startsWith('guest') && tableNum != null) {
      displayName = 'Guest • Table $tableNum';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTable ? const Color(0xFFA7F3D0) : _borderSubtle.withValues(alpha: 0.8),
          width: isTable ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table QR Orders Callout Banner at top of customer card
          if (isTable) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.table_restaurant_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'DINING AT TABLE ${tableNum ?? "DINE-IN"}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF065F46),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'QR SCAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Customer scanned QR code & ordered from their table',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              // Avatar circle with mint/cyan background
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isTable ? const Color(0xFFDCFCE7) : _cyanBadgeBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isTable
                      ? const Icon(Icons.person_rounded, color: Color(0xFF059669), size: 20)
                      : Text(
                          customerInitial,
                          style: const TextStyle(
                            color: _cyanBadgeText,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFFEAB308),
                          size: 15,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPhone(widget.customerPhone),
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Call Button
              InkWell(
                onTap: _callCustomer,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderSubtle),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.call_rounded, color: Color(0xFF2563EB), size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // WhatsApp Chat Button
              InkWell(
                onTap: _openWhatsAppChat,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderSubtle),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.chat_outlined, color: Color(0xFF16A34A), size: 16),
                  ),
                ),
              ),
            ],
          ),
          if (isDelivery && widget.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.deliveryAddress,
                      style: const TextStyle(color: Color(0xFF334155), fontSize: 11.5, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

'''

text = text[:c_start] + new_customer_card + text[c_end:]

# 9. Update _buildBillCard
b_start = text.find('  Widget _buildBillCard(NumberFormat currencyFormatter) {\n')
b_end = text.find('  Widget _buildPrepTimeCard() {\n')
assert b_start != -1 and b_end != -1, 'Bill card boundaries not found'

new_bill_card = '''  Widget _buildBillCard(NumberFormat currencyFormatter) {
    double computedSubtotal = 0.0;
    for (final rawItem in widget.items) {
      final actualItem = (rawItem['item'] is Map)
          ? Map<String, dynamic>.from(rawItem['item'])
          : rawItem;
      final qty = (rawItem['quantity'] ?? actualItem['quantity'] ?? 1) as num;
      final price = _resolveItemPrice(rawItem, actualItem, qty);
      computedSubtotal += (price * qty);
    }

    if (computedSubtotal <= 0.0 && widget.totalAmount > 0.0) {
      computedSubtotal = (widget.totalAmount / 1.05).roundToDouble();
    }

    double taxes = (widget.totalAmount - computedSubtotal);
    if (taxes < 0) taxes = 0.0;

    final isTable = _isTableOrder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTable ? const Color(0xFFA7F3D0) : _borderSubtle.withValues(alpha: 0.8),
          width: isTable ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Item Subtotal',
                style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                currencyFormatter.format(computedSubtotal > 0 ? computedSubtotal : widget.totalAmount),
                style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          if (taxes > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Taxes & Charges',
                  style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '+${currencyFormatter.format(taxes)}',
                  style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ),
          ],
          if (isTable) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Dining Table Service',
                  style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  'FREE',
                  style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // Grand Total Container in Mint Green
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F9F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  currencyFormatter.format(widget.totalAmount),
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          if (isTable) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _borderSubtle),
              ),
              child: Row(
                children: const [
                  Icon(Icons.payments_outlined, size: 13, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Payment Mode: Pay at Counter / Cash on Table',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

'''

text = text[:b_start] + new_bill_card + text[b_end:]

# 10. Update _buildBottomActionBar
act_start = text.find('  Widget _buildBottomActionBar() {\n')
act_end = text.find('  void _handleAccept() async {\n')
assert act_start != -1 and act_end != -1, 'Bottom action bar boundaries not found'

new_bottom_bar = '''  Widget _buildBottomActionBar() {
    final isTable = _isTableOrder;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: REJECT Button
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: _isProcessing ? null : _handleReject,
              borderRadius: BorderRadius.circular(21),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close_rounded, size: 16, color: Color(0xFFE11D48)),
                      SizedBox(width: 4),
                      Text(
                        'REJECT',
                        style: TextStyle(
                          color: Color(0xFFE11D48),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Right: ACCEPT ORDER Button (Table KOT customized)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _isProcessing ? null : _handleAccept,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isTable
                        ? [const Color(0xFF059669), const Color(0xFF047857)]
                        : [_primaryGreen, const Color(0xFF00914C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: (isTable ? const Color(0xFF059669) : _primaryGreen).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isTable ? Icons.kitchen_rounded : Icons.check_circle_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isTable ? 'ACCEPT & SEND TO KOT' : 'ACCEPT ORDER',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
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

'''

text = text[:act_start] + new_bottom_bar + text[act_end:]

with open(path, 'w', encoding='utf-8', newline='') as f:
    f.write(text)

print('Updated incoming_order_accept_screen.dart successfully!')
