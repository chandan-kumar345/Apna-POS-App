enum TableStatus { free, occupied, runningKot, reserved }

class TableModel {
  final String id;
  final int tableNumber;
  final String name;
  final String floor; // Ground Floor, Terrace, Main Hall
  final int capacity;
  final TableStatus status;
  final String? currentOrderId;
  String? get activeOrderId => currentOrderId;
  final String? occupiedSince;
  final String? activeOrderNumber;
  final double activeOrderTotal;
  final int activeItemCount;

  TableModel({
    required this.id,
    required this.tableNumber,
    required this.name,
    this.floor = 'Ground Floor',
    this.capacity = 4,
    this.status = TableStatus.free,
    this.currentOrderId,
    this.occupiedSince,
    this.activeOrderNumber,
    this.activeOrderTotal = 0.0,
    this.activeItemCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableNumber': tableNumber,
        'name': name,
        'floor': floor,
        'capacity': capacity,
        'status': status.name,
        'currentOrderId': currentOrderId,
        'occupiedSince': occupiedSince,
        'activeOrderNumber': activeOrderNumber,
        'activeOrderTotal': activeOrderTotal,
        'activeItemCount': activeItemCount,
      };

  factory TableModel.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? '').toString().toLowerCase().trim();
    TableStatus mappedStatus;
    if (statusRaw == 'runningkot' || statusRaw == 'running_kot' || statusRaw == 'billed') {
      mappedStatus = TableStatus.runningKot;
    } else if (statusRaw == 'occupied') {
      mappedStatus = TableStatus.occupied;
    } else if (statusRaw == 'reserved') {
      mappedStatus = TableStatus.reserved;
    } else {
      mappedStatus = TableStatus.free;
    }

    final activeOrder = json['activeOrder'] as Map<String, dynamic>?;
    final cart = json['cart'] as Map<String, dynamic>?;

    final String? orderNum = activeOrder?['orderNumber']?.toString() ?? json['currentOrderNumber']?.toString();
    final double ordTotal = (activeOrder?['totalAmount'] as num?)?.toDouble() ??
        (cart?['totalAmount'] as num?)?.toDouble() ??
        (json['currentOrderTotal'] as num?)?.toDouble() ??
        0.0;
    final int itmCount = (activeOrder?['itemCount'] as num?)?.toInt() ??
        (cart?['itemCount'] as num?)?.toInt() ??
        (json['activeItemCount'] as num?)?.toInt() ??
        0;

    return TableModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      tableNumber: (json['tableNumber'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? 'T-1',
      floor: json['floor']?.toString() ?? 'Ground Floor',
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      status: mappedStatus,
      currentOrderId: activeOrder?['id']?.toString() ?? json['currentOrderId']?.toString(),
      occupiedSince: json['occupiedSince']?.toString(),
      activeOrderNumber: orderNum,
      activeOrderTotal: ordTotal,
      activeItemCount: itmCount,
    );
  }

  TableModel copyWith({
    TableStatus? status,
    String? currentOrderId,
    String? occupiedSince,
    String? activeOrderNumber,
    double? activeOrderTotal,
    int? activeItemCount,
    bool clearOrderId = false,
  }) {
    final effectiveStatus = status ?? this.status;
    final isNowFree = effectiveStatus == TableStatus.free;

    return TableModel(
      id: id,
      tableNumber: tableNumber,
      name: name,
      floor: floor,
      capacity: capacity,
      status: effectiveStatus,
      currentOrderId: (clearOrderId || isNowFree) ? null : (currentOrderId ?? this.currentOrderId),
      occupiedSince: isNowFree ? null : (occupiedSince ?? this.occupiedSince),
      activeOrderNumber: isNowFree ? null : (activeOrderNumber ?? this.activeOrderNumber),
      activeOrderTotal: isNowFree ? 0.0 : (activeOrderTotal ?? this.activeOrderTotal),
      activeItemCount: isNowFree ? 0 : (activeItemCount ?? this.activeItemCount),
    );
  }

  /// Calculates the live running duration of this table if occupied or running KOT
  Duration? getRunningDuration({DateTime? now, String? activeOrderCreatedAt}) {
    if (status == TableStatus.free) return null;
    final startA = parseTableOccupiedSince(occupiedSince);
    final startB = activeOrderCreatedAt != null ? parseTableOccupiedSince(activeOrderCreatedAt) : null;
    final DateTime? start;
    if (startA != null && startB != null) {
      // Pick the earlier timestamp (when items were first added or session began)
      start = startA.isBefore(startB) ? startA : startB;
    } else {
      start = startA ?? startB;
    }
    if (start == null) return null;
    final current = now ?? DateTime.now();
    final diff = current.difference(start);
    return diff.isNegative ? Duration.zero : diff;
  }
}

/// Robustly parses occupiedSince timestamps supporting ISO-8601 and HH:mm formats
DateTime? parseTableOccupiedSince(String? val) {
  if (val == null || val.trim().isEmpty) return null;
  final clean = val.trim();
  final parsed = DateTime.tryParse(clean);
  if (parsed != null) return parsed;

  final parts = clean.split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
    if (h != null && m != null) {
      final now = DateTime.now();
      var dt = DateTime(now.year, now.month, now.day, h, m, s);
      if (dt.isAfter(now)) {
        dt = dt.subtract(const Duration(days: 1));
      }
      return dt;
    }
  }
  return null;
}

/// Formats duration into minutes & seconds (under 1h) or hours & minutes (1h+)
String formatRunningDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  } else {
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}

/// Helper function to match table names across formats (e.g. 'T-1', 'T1', '1', 'Table 1')
bool isSameTable(String? a, String? b) {
  if (a == null || b == null) return false;
  final cleanA = a.trim().toLowerCase();
  final cleanB = b.trim().toLowerCase();
  if (cleanA.isEmpty || cleanB.isEmpty) return false;
  if (cleanA == cleanB) return true;

  final digitsA = cleanA.replaceAll(RegExp(r'[^0-9]'), '');
  final digitsB = cleanB.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsA.isNotEmpty && digitsA == digitsB) return true;

  if (cleanA == 't-$cleanB' || cleanB == 't-$cleanA') return true;
  if (cleanA == 't$cleanB' || cleanB == 't$cleanA') return true;
  if (cleanA == 'table $cleanB' || cleanB == 'table $cleanA') return true;

  return false;
}
