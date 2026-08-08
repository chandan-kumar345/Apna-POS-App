import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/restaurant_model.dart';

class BluetoothPrinterService {
  static final BluetoothPrinterService _instance = BluetoothPrinterService._internal();
  factory BluetoothPrinterService() => _instance;
  BluetoothPrinterService._internal();

  BluetoothInfo? _selectedDevice;
  BluetoothInfo? get selectedDevice => _selectedDevice;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  static const String _prefKeyPrinterAddress = 'saved_printer_mac_address';
  static const String _prefKeyPrinterName = 'saved_printer_name';

  /// Request runtime Bluetooth and Location permissions safely for Android
  Future<void> requestPermissions() async {
    try {
      await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();
    } catch (e) {
      if (kDebugMode) print('Error requesting permissions: $e');
    }
  }

  /// Check if Bluetooth is powered ON on the mobile device
  Future<bool> isBluetoothOn() async {
    try {
      final bool enabled = await PrintBluetoothThermal.bluetoothEnabled;
      return enabled;
    } catch (e) {
      if (kDebugMode) print('Error checking if bluetooth is enabled: $e');
      return false;
    }
  }

  /// Check if Bluetooth printer is currently connected
  Future<bool> isConnected() async {
    try {
      final bool connected = await PrintBluetoothThermal.connectionStatus;
      return connected;
    } catch (e) {
      if (kDebugMode) print('Error checking bluetooth connection status: $e');
      return false;
    }
  }

  /// Get saved printer details from SharedPreferences
  Future<Map<String, String?>> getSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'address': prefs.getString(_prefKeyPrinterAddress),
        'name': prefs.getString(_prefKeyPrinterName),
      };
    } catch (e) {
      return {'address': null, 'name': null};
    }
  }

  /// Get list of paired Bluetooth devices on the mobile device
  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      await requestPermissions();
      final List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices;
    } catch (e) {
      if (kDebugMode) print('Error getting bonded bluetooth devices: $e');
      return [];
    }
  }

  /// Auto-reconnect to saved printer if available
  Future<bool> autoConnectSavedPrinter() async {
    final connected = await isConnected();
    if (connected) return true;

    final saved = await getSavedPrinter();
    final savedAddress = saved['address'];

    if (savedAddress != null && savedAddress.isNotEmpty) {
      final devices = await getBondedDevices();
      BluetoothInfo? targetDevice;

      for (var device in devices) {
        if (device.macAdress == savedAddress) {
          targetDevice = device;
          break;
        }
      }

      if (targetDevice != null) {
        return await connect(targetDevice);
      } else {
        // Create fallback device with saved MAC address
        final fallbackDevice = BluetoothInfo(
          name: saved['name'] ?? 'Saved Printer',
          macAdress: savedAddress,
        );
        return await connect(fallbackDevice);
      }
    }
    return false;
  }

  /// Connect to a specific Bluetooth printer device
  Future<bool> connect(BluetoothInfo device) async {
    try {
      _isConnecting = true;

      await requestPermissions();

      // Disconnect any existing socket connection to free the RFCOMM channel
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));

      final String macAddress = device.macAdress.trim();
      final String deviceName = device.name.trim().isNotEmpty ? device.name.trim() : 'Thermal Printer';

      // Attempt 1: Initial connection
      bool success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);

      // Attempt 2: Retry after brief delay if attempt 1 returned false
      if (!success) {
        await Future.delayed(const Duration(milliseconds: 500));
        success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      }

      if (success) {
        _selectedDevice = BluetoothInfo(name: deviceName, macAdress: macAddress);

        // Save preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyPrinterAddress, macAddress);
        await prefs.setString(_prefKeyPrinterName, deviceName);
      }

      _isConnecting = false;
      return success;
    } catch (e) {
      _isConnecting = false;
      if (kDebugMode) print('Failed to connect to printer: $e');
      return false;
    }
  }

  /// Disconnect current printer
  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _selectedDevice = null;
      return result;
    } catch (e) {
      if (kDebugMode) print('Error disconnecting printer: $e');
      return false;
    }
  }

  /// Print test receipt (Bill or KOT sample)
  Future<bool> printTestReceipt({RestaurantModel? restaurant, bool isKot = false}) async {
    bool connected = await isConnected();
    if (!connected) {
      connected = await autoConnectSavedPrinter();
      if (!connected) return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      final restName = restaurant?.name.isNotEmpty == true ? restaurant!.name : 'Apna POS Outlet';

      if (isKot) {
        bytes += generator.text(
          'KITCHEN ORDER TICKET',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
        );
        bytes += generator.text('*** KOT TEST ***', styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(text: 'TABLE:', width: 4, styles: const PosStyles(bold: true)),
          PosColumn(text: 'TABLE 1', width: 8, styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
        ]);
        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(text: '2 x', width: 3, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
          PosColumn(text: 'CHICKEN BIRYANI', width: 9, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        ]);
        bytes += generator.text('  * Note: Extra Spicy', styles: const PosStyles(bold: true));
        bytes += generator.hr();
        bytes += generator.text('*** KITCHEN COPY ***', styles: const PosStyles(align: PosAlign.center, bold: true));
      } else {
        final restAddress = restaurant?.address.isNotEmpty == true ? restaurant!.address : 'Main Market, City Center';
        final restPhone = restaurant?.phone.isNotEmpty == true ? restaurant!.phone : '+91 98765 43210';

        bytes += generator.text(
          restName,
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
        );
        bytes += generator.text(restAddress, styles: const PosStyles(align: PosAlign.center));
        bytes += generator.text('Tel: $restPhone', styles: const PosStyles(align: PosAlign.center));
        bytes += generator.hr();

        bytes += generator.text(
          'THERMAL PRINTER TEST',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1),
        );
        bytes += generator.text('Status: Connected & Ready!', styles: const PosStyles(align: PosAlign.center));
        bytes += generator.hr();
        bytes += generator.text('Thank you for using Apna POS', styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.feed(2);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      if (kDebugMode) print('Error printing test receipt: $e');
      return false;
    }
  }

  String _toAscii(String text) {
    return text
        .replaceAll('₹', 'Rs. ')
        .replaceAll('•', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  /// Print Thermal Bill Receipt
  Future<bool> printBill({
    required OrderModel order,
    RestaurantModel? restaurant,
    String currency = '₹',
  }) async {
    bool connected = await isConnected();
    if (!connected) {
      connected = await autoConnectSavedPrinter();
      if (!connected) return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      final restName = _toAscii(restaurant?.name.isNotEmpty == true ? restaurant!.name : 'Apna POS Outlet');
      final restAddress = _toAscii(restaurant?.address.isNotEmpty == true ? restaurant!.address : 'Main Market, City Center');
      final restPhone = _toAscii(restaurant?.phone.isNotEmpty == true ? restaurant!.phone : '+91 98765 43210');
      final gstNumber = _toAscii(restaurant?.gstNumber.isNotEmpty == true ? restaurant!.gstNumber : '19FPYPD2539M1Z0');
      final safeCurrency = (currency == '₹' || currency.contains('₹')) ? 'Rs. ' : _toAscii(currency);
      final double taxRate = restaurant?.taxRate ?? 5.0;
      final double cgstRate = taxRate / 2;
      final double sgstRate = taxRate / 2;
      final double cgstAmount = order.taxAmount / 2;
      final double sgstAmount = order.taxAmount / 2;

      // Header - Restaurant Info
      bytes += generator.text(
        restName.toUpperCase(),
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      );
      if (restaurant?.tagline != null && restaurant!.tagline.isNotEmpty) {
        bytes += generator.text(_toAscii(restaurant.tagline), styles: const PosStyles(align: PosAlign.center));
      }
      bytes += generator.text(restAddress, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Ph: $restPhone', styles: const PosStyles(align: PosAlign.center));
      if (gstNumber.isNotEmpty) {
        bytes += generator.text('GSTIN: $gstNumber', styles: const PosStyles(align: PosAlign.center, bold: true));
      }
      bytes += generator.hr();

      // Order Details
      final orderTypeStr = order.orderType == OrderType.dineIn
          ? 'Dine In'
          : (order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery');

      bytes += generator.text('TAX INVOICE / BILL', styles: const PosStyles(align: PosAlign.center, bold: true));

      bytes += generator.row([
        PosColumn(text: 'Bill: #${_toAscii(order.orderNumber)}', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Type: ${_toAscii(orderTypeStr)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      final dateStr = order.createdAt.contains(' ')
          ? order.createdAt.split(' ').first
          : (order.createdAt.length > 10 ? order.createdAt.substring(0, 10) : order.createdAt);
      final timeStr = order.createdAt.contains(' ')
          ? order.createdAt.split(' ').last.split('.').first
          : '';

      bytes += generator.row([
        PosColumn(text: 'Date: ${_toAscii(dateStr)}', width: 6),
        PosColumn(text: 'Time: ${_toAscii(timeStr)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      if (order.tableNumber != null && order.tableNumber!.isNotEmpty) {
        bytes += generator.text('Table: ${_toAscii(order.tableNumber!.replaceAll('T-', ''))}', styles: const PosStyles(bold: true));
      }
      if (order.customerName != null && order.customerName!.isNotEmpty) {
        bytes += generator.text('Customer: ${_toAscii(order.customerName!)}');
      }
      if (order.customerPhone != null && order.customerPhone!.isNotEmpty) {
        bytes += generator.text('Phone: ${_toAscii(order.customerPhone!)}');
      }

      bytes += generator.hr();

      // Items Column Header
      bytes += generator.row([
        PosColumn(text: 'ITEM DESCRIPTION', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(text: 'TOTAL', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr();

      // Items List
      for (var cartItem in order.items) {
        final double unitPrice = cartItem.item.price;
        final double lineTotal = cartItem.totalPrice;

        bytes += generator.text(_toAscii(cartItem.item.name), styles: const PosStyles(bold: true));

        final qtyDetail = '  ${cartItem.quantity} x $safeCurrency${unitPrice.toStringAsFixed(2)}';
        final lineTotalStr = '$safeCurrency${lineTotal.toStringAsFixed(2)}';

        bytes += generator.row([
          PosColumn(text: qtyDetail, width: 8),
          PosColumn(text: lineTotalStr, width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
      }

      bytes += generator.hr();

      // Financials Summary
      bytes += generator.row([
        PosColumn(text: 'Gross Subtotal', width: 7),
        PosColumn(text: '$safeCurrency${order.subtotal.toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'CGST (${cgstRate.toStringAsFixed(1)}%)', width: 7),
        PosColumn(text: '$safeCurrency${cgstAmount.toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'SGST (${sgstRate.toStringAsFixed(1)}%)', width: 7),
        PosColumn(text: '$safeCurrency${sgstAmount.toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);

      if (order.discountAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Discount', width: 7),
          PosColumn(text: '-$safeCurrency${order.discountAmount.toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();

      // Net Amount Payable
      bytes += generator.row([
        PosColumn(
          text: 'TOTAL AMOUNT',
          width: 7,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: '$safeCurrency${order.totalAmount.toStringAsFixed(2)}',
          width: 5,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Order Status', width: 6),
        PosColumn(text: _toAscii(order.status.name.toUpperCase()), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Payment Method', width: 6),
        PosColumn(text: _toAscii(order.paymentMethod.toUpperCase()), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      bytes += generator.hr();

      // Footer
      bytes += generator.text('Thank You For Your Visit!', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Please Come Again', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Powered by Apna POS', styles: const PosStyles(align: PosAlign.center));

      bytes += generator.feed(2);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      if (kDebugMode) print('Error sending bill to bluetooth printer: $e');
      return false;
    }
  }

  /// Print Kitchen Order Ticket (KOT) Thermal Receipt
  Future<bool> printKOT({
    required OrderModel order,
    RestaurantModel? restaurant,
    String? kotNumber,
  }) async {
    bool connected = await isConnected();
    if (!connected) {
      connected = await autoConnectSavedPrinter();
      if (!connected) return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      final restName = restaurant?.name.isNotEmpty == true ? restaurant!.name : 'Apna POS Outlet';
      final kotId = kotNumber ?? 'KOT-${order.orderNumber}';

      // Header - KOT Title (Bold & Large for Kitchen)
      bytes += generator.text(
        'KITCHEN ORDER TICKET',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      );
      bytes += generator.text(
        '*** $kotId ***',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1),
      );
      bytes += generator.hr();

      // Order Type & Table Number (Prominent for Kitchen Staff)
      final orderTypeStr = order.orderType == OrderType.dineIn
          ? 'DINE IN'
          : (order.orderType == OrderType.takeaway ? 'TAKEAWAY' : 'DELIVERY');

      bytes += generator.row([
        PosColumn(text: 'ORDER TYPE:', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: orderTypeStr, width: 6, styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
      ]);

      if (order.tableNumber != null && order.tableNumber!.isNotEmpty) {
        final tableStr = 'TABLE: ${order.tableNumber!.replaceAll('T-', '')}';
        bytes += generator.text(
          tableStr,
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
        );
      }

      bytes += generator.row([
        PosColumn(text: 'Bill #: ${order.orderNumber}', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Time: ${order.createdAt.split(' ').last}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.hr();

      // Items Header
      bytes += generator.row([
        PosColumn(text: 'QTY', width: 3, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(text: 'ITEM NAME', width: 9, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      ]);
      bytes += generator.hr();

      // Kitchen Items List
      for (var cartItem in order.items) {
        bytes += generator.row([
          PosColumn(
            text: '${cartItem.quantity} x',
            width: 3,
            styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
          PosColumn(
            text: cartItem.item.name.toUpperCase(),
            width: 9,
            styles: const PosStyles(bold: true, height: PosTextSize.size2),
          ),
        ]);

        if (cartItem.note != null && cartItem.note!.isNotEmpty) {
          bytes += generator.text(
            '  * Preparation Note: ${cartItem.note}',
            styles: const PosStyles(bold: true),
          );
        }
        bytes += generator.feed(1);
      }

      bytes += generator.hr();

      // KOT Footer
      bytes += generator.text('*** KITCHEN COPY ***', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Outlet: $restName', styles: const PosStyles(align: PosAlign.center));

      bytes += generator.feed(2);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      if (kDebugMode) print('Error sending KOT to thermal printer: $e');
      return false;
    }
  }
}
