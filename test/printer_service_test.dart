import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/services/windows_printer_service.dart';
import 'package:apna_pos/core/services/bluetooth_printer_service.dart';
import 'package:apna_pos/core/widgets/printer_selection_dialog.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WindowsPrinterService Tests', () {
    test('WindowsPrinterService singleton and support check', () {
      final service = WindowsPrinterService();
      final service2 = WindowsPrinterService();
      expect(identical(service, service2), true);
      expect(service.isSupported, Platform.isWindows);
    });

    test('WindowsPrinterInfo model serialization', () {
      const printer = WindowsPrinterInfo(
        name: 'POS-58 (COM5)',
        isDefault: true,
        portName: 'COM5',
        isBluetooth: true,
        macAddress: '6632910CC1D9',
        status: 'Ready',
      );

      final json = printer.toJson();
      final fromJson = WindowsPrinterInfo.fromJson(json);

      expect(fromJson.name, 'POS-58 (COM5)');
      expect(fromJson.isDefault, true);
      expect(fromJson.portName, 'COM5');
      expect(fromJson.isBluetooth, true);
      expect(fromJson.macAddress, '6632910CC1D9');
      expect(fromJson.status, 'Ready');
    });

    test('WindowsPrinterService default printer save and clear', () async {
      final service = WindowsPrinterService();
      await service.saveDefaultPrinter('Test Thermal Printer', portName: 'COM5');
      final saved = await service.getSavedPrinterName(forceRefresh: true);
      expect(saved, 'Test Thermal Printer');

      await service.clearSavedPrinter();
      final cleared = await service.getSavedPrinterName(forceRefresh: true);
      expect(cleared, isNull);
    });

    if (Platform.isWindows) {
      test('WindowsPrinterService discovery on Windows', () async {
        final service = WindowsPrinterService();
        final spoolerPrinters = service.getWin32SpoolerPrinters();
        print('Spooler printers detected: ${spoolerPrinters.length}');
        for (var p in spoolerPrinters) {
          print(' - ${p.name} (default: ${p.isDefault})');
        }

        final allPrinters = await service.getInstalledPrinters(forceRefresh: true);
        expect(allPrinters, isNotEmpty);
      });
    }
  });

  group('BluetoothPrinterService Tests', () {
    test('CapabilityProfile is cached and loads fast', () async {
      final service = BluetoothPrinterService();
      final profile1 = await service.getCapabilityProfile();
      final profile2 = await service.getCapabilityProfile();
      expect(identical(profile1, profile2), true);
    });

    test('Logo cache invalidation works', () {
      final service = BluetoothPrinterService();
      service.invalidateLogoCache();
      expect(service.hasCachedData, isFalse);
    });
  });

  group('PrinterSelectionDialog Widget Tests', () {
    testWidgets('PrinterSelectionDialog renders correctly', (tester) async {
      final mockOrder = OrderModel(
        id: 'ord_123',
        orderNumber: '1001',
        items: [
          CartItemModel(
            item: MenuItemModel(
              id: 'item_1',
              name: 'Chicken Biryani',
              category: 'Biryani',
              price: 250,
              description: 'Delicious Chicken Biryani',
            ),
            quantity: 2,
          ),
        ],
        subtotal: 500,
        taxAmount: 25,
        totalAmount: 525,
        createdAt: DateTime.now().toIso8601String(),
        status: OrderStatus.pending,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrinterSelectionDialog(
              orderToPrint: mockOrder,
              currency: '₹',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PrinterSelectionDialog), findsOneWidget);
      expect(find.textContaining('Printer'), findsWidgets);
    });
  });
}
