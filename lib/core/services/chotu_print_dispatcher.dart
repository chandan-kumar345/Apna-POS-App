import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';
import '../models/order_model.dart';
import 'bluetooth_printer_service.dart';

typedef ChotuPrintTransport = Future<bool> Function(Map<String, dynamic> job);

/// The server owns orders; this bridge only sends immutable receipt snapshots.
/// A durable claim precedes printer I/O. Unknown delivery is never auto-retried.
class ChotuPrintDispatcher {
  ChotuPrintDispatcher({ChotuPrintTransport? transport})
    : _transport = transport ?? _print;

  final ChotuPrintTransport _transport;
  static Future<void> _tail = Future.value();

  static Future<bool> _print(Map<String, dynamic> job) async {
    final db = DatabaseService();
    final printer = BluetoothPrinterService();
    final order = OrderModel.fromJson(job['order'] as Map);
    if (job['type'] == 'kot') {
      return printer.printKOT(
        order: order,
        restaurant: db.restaurant,
        kotNumber: job['kotNumber']?.toString(),
        customItemsToPrint: order.items,
      );
    }
    return printer.printBill(
      order: order,
      restaurant: db.restaurant,
      user: db.currentUser,
    );
  }

  Future<String?> dispatch(
    String scope,
    List<dynamic> jobs, {
    bool Function()? canDispatch,
  }) {
    final done = Completer<String?>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        done.complete(await _dispatch(scope, jobs, canDispatch));
      } catch (_) {
        done.complete(
          'Printer delivery is unconfirmed. Check the printer and reprint from Orders if needed.',
        );
      }
    });
    return done.future;
  }

  Future<String?> _dispatch(
    String scope,
    List<dynamic> jobs,
    bool Function()? canDispatch,
  ) async {
    if (jobs.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final key = 'chotu_print_claims_v1_${base64Url.encode(utf8.encode(scope))}';
    final saved = prefs.getString(key);
    final claims = saved == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(saved) as Map);
    var submitted = 0;
    var uncertain = false;
    for (final raw in jobs) {
      if (canDispatch?.call() == false) {
        return 'Account changed. Check the saved order in its original account before printing.';
      }
      if (raw is! Map ||
          raw['order'] is! Map ||
          !['kot', 'bill'].contains(raw['type']) ||
          !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(raw['id']?.toString() ?? '')) {
        uncertain = true;
        continue;
      }
      final job = Map<String, dynamic>.from(raw);
      final id = job['id'] as String;
      if (claims.containsKey(id)) {
        uncertain |= claims[id] != 'submitted';
        continue;
      }
      claims[id] = 'claimed';
      // Keep all claims: evicting an old ID could reprint a recovered receipt.
      if (!await prefs.setString(key, jsonEncode(claims))) {
        uncertain = true;
        break;
      }
      var success = false;
      try {
        if (canDispatch?.call() != false) {
          success = await _transport(job).timeout(const Duration(seconds: 20));
        }
      } catch (_) {
        /* Bytes may have reached the printer. Do not auto-retry. */
      }
      claims[id] = success ? 'submitted' : 'uncertain';
      await prefs.setString(key, jsonEncode(claims));
      if (success) {
        submitted++;
      } else {
        uncertain = true;
      }
    }
    if (uncertain) {
      return 'Order saved. Printer delivery is unconfirmed. Check the printer and reprint from Orders if needed.';
    }
    return submitted > 0 ? 'Sent to the configured printer.' : null;
  }
}
