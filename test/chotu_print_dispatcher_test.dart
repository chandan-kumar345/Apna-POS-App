import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/services/chotu_print_dispatcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> job(String id, {String type = 'kot'}) => {
    'id': id.padLeft(24, '0'),
    'type': type,
    'order': {
      'id': 'receipt-1',
      'items': [
        {'name': 'Naan', 'quantity': 1},
      ],
    },
  };
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'replays and new dispatcher instances do not send the same job twice',
    () async {
      var calls = 0;
      Future<bool> send(Map<String, dynamic> _) async {
        calls++;
        return true;
      }

      final jobs = [job('1'), job('2', type: 'bill')];
      expect(
        await ChotuPrintDispatcher(transport: send).dispatch('tenant-a', jobs),
        contains('Sent'),
      );
      expect(
        await ChotuPrintDispatcher(transport: send).dispatch('tenant-a', jobs),
        isNull,
      );
      expect(calls, 2);
      await ChotuPrintDispatcher(transport: send).dispatch('tenant-b', jobs);
      expect(calls, 4);
    },
  );

  test('concurrent receipts serialize and claim before transport', () async {
    var calls = 0;
    final hold = Completer<bool>();
    final dispatcher = ChotuPrintDispatcher(
      transport: (_) {
        calls++;
        return hold.future;
      },
    );
    final first = dispatcher.dispatch('tenant', [job('1')]);
    final second = dispatcher.dispatch('tenant', [job('1')]);
    await Future<void>.delayed(Duration.zero);
    hold.complete(true);
    await Future.wait([first, second]);
    expect(calls, 1);
  });

  test(
    'failed and interrupted delivery is reported and never auto-retried',
    () async {
      var calls = 0;
      final dispatcher = ChotuPrintDispatcher(
        transport: (_) async {
          calls++;
          throw StateError('Printer disconnected');
        },
      );
      expect(
        await dispatcher.dispatch('tenant', [job('1')]),
        contains('unconfirmed'),
      );
      expect(
        await dispatcher.dispatch('tenant', [job('1')]),
        contains('unconfirmed'),
      );
      expect(calls, 1);
    },
  );

  test('invalid receipt does not reach the printer', () async {
    var calls = 0;
    final dispatcher = ChotuPrintDispatcher(
      transport: (_) async {
        calls++;
        return true;
      },
    );
    expect(
      await dispatcher.dispatch('tenant', [job('invalid')]),
      contains('unconfirmed'),
    );
    expect(calls, 0);
  });

  test(
    'account switch stops remaining jobs before printer transport',
    () async {
      var current = true;
      var calls = 0;
      final dispatcher = ChotuPrintDispatcher(
        transport: (_) async {
          calls++;
          current = false;
          return true;
        },
      );
      expect(
        await dispatcher.dispatch('original-account', [
          job('1'),
          job('2'),
        ], canDispatch: () => current),
        contains('Account changed'),
      );
      expect(calls, 1);
    },
  );
}
