import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_model.dart';
import '../network/api_endpoints.dart';
import '../database/database_service.dart';

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
          'KOT',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          ),
        );
        bytes += generator.text(
          restName,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
        bytes += generator.text(
          'DineIn',
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          'Dine In-Table 01',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
        bytes += generator.text(
          DateFormat('dd-MM-yyyy,hh:mm:ss a').format(DateTime.now()).toLowerCase(),
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.hr(ch: '-');
        bytes += generator.row([
          PosColumn(text: 'Sn', width: 2, styles: const PosStyles(bold: true, align: PosAlign.left)),
          PosColumn(text: 'Items', width: 8, styles: const PosStyles(bold: true, align: PosAlign.left)),
          PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
        bytes += generator.hr(ch: '-');
        bytes += generator.row([
          PosColumn(text: '1', width: 2, styles: const PosStyles(align: PosAlign.left, bold: true)),
          PosColumn(text: 'Chicken Masala', width: 8, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '1', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
        bytes += generator.row([
          PosColumn(text: '2', width: 2, styles: const PosStyles(align: PosAlign.left, bold: true)),
          PosColumn(text: 'Chicken Handi', width: 8, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '1', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
        bytes += generator.hr(ch: '-');
        bytes += generator.text(
          'Thank you for dining with us!',
          styles: const PosStyles(align: PosAlign.center),
        );
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

  String _formatAmount(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  String _toAscii(String text) {
    return text
        .replaceAll('₹', 'Rs. ')
        .replaceAll('•', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  /// Generates a high-contrast raster bitmap QR image optimized for 58mm thermal printers
  Future<img.Image?> _generateQrRaster(String data, {double size = 220}) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
      );

      final byteData = await painter.toImageData(size, format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final decoded = img.decodeImage(byteData.buffer.asUint8List());
        if (decoded != null) {
          return img.grayscale(decoded);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[_generateQrRaster] Error: $e');
    }
    return null;
  }

  /// Loads company / restaurant profile logo from network, local file, asset or base64 and optimizes for thermal print
  Future<img.Image?> _loadCompanyLogo({UserModel? user, RestaurantModel? restaurant}) async {
    try {
      String photoPath = user?.profilePhotoPath?.trim() ?? '';
      if (photoPath.isEmpty) {
        final dbUser = DatabaseService().currentUser;
        photoPath = dbUser?.profilePhotoPath?.trim() ?? '';
      }

      Uint8List? imageBytes;

      if (photoPath.isNotEmpty) {
        // 1. Local filesystem path check (handles Windows / Android absolute paths & file:// URIs)
        try {
          final cleanPath = photoPath.replaceFirst('file://', '');
          final file = File(cleanPath);
          if (file.existsSync()) {
            imageBytes = await file.readAsBytes();
          }
        } catch (_) {}

        // 2. Base64 encoded image check
        if (imageBytes == null && (photoPath.startsWith('data:image') || (photoPath.length > 60 && !photoPath.startsWith('http') && !photoPath.startsWith('/') && !photoPath.contains('\\')))) {
          try {
            final cleanBase64 = photoPath.contains(',') ? photoPath.split(',').last : photoPath;
            imageBytes = base64Decode(cleanBase64.trim());
          } catch (_) {}
        }

        // 3. Asset path check
        if (imageBytes == null && photoPath.startsWith('assets/')) {
          try {
            final byteData = await rootBundle.load(photoPath);
            imageBytes = byteData.buffer.asUint8List();
          } catch (_) {}
        }

        // 4. Remote HTTP / Server media URL check (resolves relative server paths like /uploads/...)
        if (imageBytes == null) {
          final resolvedUrl = ApiEndpoints.resolveMediaUrl(photoPath);
          if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
            try {
              final response = await http.get(Uri.parse(resolvedUrl)).timeout(const Duration(seconds: 5));
              if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
                imageBytes = response.bodyBytes;
              }
            } catch (e) {
              if (kDebugMode) print('[_loadCompanyLogo] Error downloading logo from $resolvedUrl: $e');
            }
          }
        }
      }

      // 5. Fallback to bundled brand logo if user logo is not found or failed to load
      if (imageBytes == null || imageBytes.isEmpty) {
        for (final fallbackAsset in ['assets/images/apna_pos_brand_logo.png', 'assets/images/logo.png', 'assets/images/logoq.png']) {
          try {
            final byteData = await rootBundle.load(fallbackAsset);
            imageBytes = byteData.buffer.asUint8List();
            if (imageBytes.isNotEmpty) break;
          } catch (_) {}
        }
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final decoded = img.decodeImage(imageBytes);
        if (decoded != null) {
          return _formatCircularLogo(decoded, targetSize: 320, borderWidth: 4.0);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[_loadCompanyLogo] Error loading logo: $e');
    }
    return null;
  }

  /// Formats an image into a circle with a crisp outline border line on a solid white background
  img.Image _formatCircularLogo(img.Image src, {int targetSize = 320, double borderWidth = 4.0}) {
    // 1. Crop to center square so aspect ratio stays 1:1
    final minDim = src.width < src.height ? src.width : src.height;
    final srcX = (src.width - minDim) ~/ 2;
    final srcY = (src.height - minDim) ~/ 2;
    final squareCrop = img.copyCrop(src, x: srcX, y: srcY, width: minDim, height: minDim);

    // 2. Resize to target size (320x320 dots, multiple of 8)
    final resized = img.copyResize(
      squareCrop,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.cubic,
    );

    // 3. Composite onto solid white background to eliminate PNG transparency blackness
    final canvas = img.Image(width: targetSize, height: targetSize);
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
    img.compositeImage(canvas, resized);

    // 4. Apply circular mask and crisp circular outline border
    final double center = targetSize / 2.0;
    final double outerRadius = center - 4.0; // 156.0 for 320 size (leaves 4px white margin)
    final double innerRadius = outerRadius - borderWidth; // 152.0 (4px solid black circular line)

    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final double dx = (x + 0.5) - center;
        final double dy = (y + 0.5) - center;
        final double dist = math.sqrt(dx * dx + dy * dy);

        if (dist > outerRadius) {
          // Outside the circular frame -> clean white paper background
          canvas.setPixelRgba(x, y, 255, 255, 255, 255);
        } else if (dist >= innerRadius) {
          // Circular border line -> solid black stroke
          canvas.setPixelRgba(x, y, 0, 0, 0, 255);
        }
        // Inside innerRadius: preserves the crisp logo image
      }
    }

    return img.grayscale(canvas);
  }

  /// Print Thermal Bill Receipt for 58mm Mobile Thermal Printer
  Future<bool> printBill({
    required OrderModel order,
    RestaurantModel? restaurant,
    UserModel? user,
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

      final restName = _toAscii(restaurant?.name.isNotEmpty == true ? restaurant!.name : 'Apna POS Store');
      final restPhone = _toAscii(restaurant?.phone.isNotEmpty == true ? restaurant!.phone : '+91 98765 43210');
      final gstNumber = _toAscii(restaurant?.gstNumber.isNotEmpty == true ? restaurant!.gstNumber : '');
      final safeCurrency = (currency == '₹' || currency.contains('₹')) ? 'Rs.' : _toAscii(currency);
      final double cgstAmount = order.taxAmount / 2;
      final double sgstAmount = order.taxAmount / 2;

      // 1. Company Logo Raster (Centered on 58mm thermal roll, enlarged & crisp)
      try {
        final logoImage = await _loadCompanyLogo(user: user, restaurant: restaurant);
        if (logoImage != null) {
          bytes += generator.imageRaster(logoImage, align: PosAlign.center);
          bytes += generator.feed(1);
        }
      } catch (e) {
        if (kDebugMode) print('Error printing logo: $e');
      }

      // 2. Restaurant Header Info (Standard Size1)
      bytes += generator.text(
        restName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
      );
      if (restPhone.isNotEmpty) {
        bytes += generator.text('Mob: $restPhone', styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size1));
      }

      // 3. Order Details
      final orderTypeStr = order.orderType == OrderType.dineIn
          ? 'DineIn'
          : (order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery');

      bytes += generator.text(orderTypeStr, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1));

      if (order.orderType == OrderType.dineIn && order.tableNumber != null && order.tableNumber!.isNotEmpty) {
        final tableClean = order.tableNumber!.replaceAll(RegExp(r'[^0-9]'), '');
        final tableDisplay = tableClean.isNotEmpty ? 'Table $tableClean' : order.tableNumber!;
        bytes += generator.text('Dine In - $tableDisplay', styles: const PosStyles(align: PosAlign.center, bold: true));
      }

      if (order.customerName != null && order.customerName!.isNotEmpty) {
        bytes += generator.text('Customer Name: ${_toAscii(order.customerName!.toUpperCase())}', styles: const PosStyles(align: PosAlign.center, bold: true));
      }
      if (order.customerPhone != null && order.customerPhone!.isNotEmpty) {
        bytes += generator.text('Customer Mobile: ${_toAscii(order.customerPhone!)}', styles: const PosStyles(align: PosAlign.center, bold: true));
      }

      final dt = DateTime.tryParse(order.createdAt) ?? DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy hh:mm:ss a').format(dt);
      bytes += generator.text(dateStr, styles: const PosStyles(align: PosAlign.center));

      bytes += generator.text('Bill: #${_toAscii(order.orderNumber)}', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Invoice: #INV-${_toAscii(order.orderNumber)}', styles: const PosStyles(align: PosAlign.center));
      if (gstNumber.isNotEmpty) {
        bytes += generator.text('GST: #$gstNumber', styles: const PosStyles(align: PosAlign.center, bold: true));
      }

      if (order.orderType == OrderType.delivery && order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) {
        bytes += generator.text('Delivery Address: ${_toAscii(order.deliveryAddress!)}', styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.hr(ch: '-');

      // 4. Items Table Header (4 Columns: ITEM, QTY, RATE, TOTAL)
      bytes += generator.row([
        PosColumn(text: 'ITEM', width: 5, styles: const PosStyles(bold: true, align: PosAlign.left)),
        PosColumn(text: 'QTY', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'RATE', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'TOTAL', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr(ch: '-');

      // 5. Items List
      for (int i = 0; i < order.items.length; i++) {
        final cartItem = order.items[i];
        final rateStr = _formatAmount(cartItem.item.price);
        final lineTotalStr = _formatAmount(cartItem.totalPrice);

        bytes += generator.row([
          PosColumn(text: _toAscii(cartItem.item.name), width: 5, styles: const PosStyles(bold: true, align: PosAlign.left)),
          PosColumn(text: '${cartItem.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: rateStr, width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: lineTotalStr, width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);

        if (cartItem.note != null && cartItem.note!.trim().isNotEmpty) {
          bytes += generator.text(
            '  * ${_toAscii(cartItem.note!.trim())}',
            styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB),
          );
        }
      }

      bytes += generator.hr(ch: '-');

      // 6. Financials Summary
      bytes += generator.row([
        PosColumn(text: 'Sub Total', width: 7),
        PosColumn(text: '$safeCurrency${_formatAmount(order.subtotal)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (order.discountAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Discount', width: 7),
          PosColumn(text: '-$safeCurrency${_formatAmount(order.discountAmount)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      if (order.taxAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'CGST', width: 7),
          PosColumn(text: '$safeCurrency${_formatAmount(cgstAmount)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
        bytes += generator.row([
          PosColumn(text: 'SGST', width: 7),
          PosColumn(text: '$safeCurrency${_formatAmount(sgstAmount)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      if (order.tipAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Tip', width: 7),
          PosColumn(text: '+$safeCurrency${_formatAmount(order.tipAmount)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      if (order.deliveryCharge > 0) {
        bytes += generator.row([
          PosColumn(text: 'Delivery Charge', width: 7),
          PosColumn(text: '+$safeCurrency${_formatAmount(order.deliveryCharge)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      if (order.roundOff.abs() > 0.001) {
        final sign = order.roundOff >= 0 ? '+' : '';
        bytes += generator.row([
          PosColumn(text: 'Round Off', width: 7),
          PosColumn(text: '$sign$safeCurrency${_formatAmount(order.roundOff)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr(ch: '-');

      // 7. Net Amount Payable
      bytes += generator.row([
        PosColumn(
          text: 'Total Amount',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
        ),
        PosColumn(
          text: '$safeCurrency${_formatAmount(order.totalAmount)}',
          width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size1, width: PosTextSize.size1),
        ),
      ]);
      bytes += generator.hr(ch: '-');

      bytes += generator.row([
        PosColumn(text: 'Payment Method', width: 6),
        PosColumn(text: _toAscii(order.paymentMethod.toUpperCase()), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      final bool isOrderPaid = order.isPaid || order.paymentStatus.toLowerCase() == 'paid' || order.status == OrderStatus.completed;
      final String paymentStatusStr = isOrderPaid ? 'PAID (COMPLETED)' : 'UNPAID / RUNNING';
      bytes += generator.row([
        PosColumn(text: 'Payment Status', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: paymentStatusStr, width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      // 8. Dynamic UPI QR Code Section (Always carries exact total payable amount)
      final String upiId = (restaurant?.upiId.isNotEmpty == true)
          ? restaurant!.upiId.trim()
          : 'apnapos@upi';
      final String payeeName = (restaurant?.name.isNotEmpty == true)
          ? restaurant!.name.trim()
          : 'Apna POS Store';
      final String formattedAmount = order.totalAmount.toStringAsFixed(2);

      final String dynamicUpiUrl = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$formattedAmount&cu=INR&tr=${order.orderNumber}&tn=${Uri.encodeComponent("Bill ${order.orderNumber}")}';

      final String qrPayload = (order.qrIntentUrl != null && order.qrIntentUrl!.isNotEmpty && order.qrIntentUrl!.contains('&am='))
          ? order.qrIntentUrl!
          : dynamicUpiUrl;

      if (qrPayload.isNotEmpty) {
        bytes += generator.hr(ch: '-');
        bytes += generator.text(
          'SCAN & PAY WITH ANY UPI APP',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1),
        );

        // High-contrast, enlarged 220px bitmap QR raster for 100% reliable camera scanning
        try {
          final qrRaster = await _generateQrRaster(qrPayload, size: 220);
          if (qrRaster != null) {
            bytes += generator.imageRaster(qrRaster, align: PosAlign.center);
          } else {
            bytes += generator.qrcode(qrPayload, size: QRSize.size6);
          }
        } catch (_) {
          bytes += generator.qrcode(qrPayload, size: QRSize.size6);
        }

        bytes += generator.text(
          'Amount: $safeCurrency${_formatAmount(order.totalAmount)}',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1),
        );
        if (upiId.isNotEmpty) {
          bytes += generator.text('UPI ID: ${_toAscii(upiId)}', styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size1));
        }
      }

      bytes += generator.hr(ch: '-');

      // 9. Footer
      bytes += generator.text('Thank you! Visit Again!', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1));
      bytes += generator.text('Powered by Apna POS', styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size1));

      // 10. Tear Margin Feed (3 line feed so manual paper tear does not cut the footer text)
      bytes += generator.feed(3);

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      if (kDebugMode) print('Error sending bill to bluetooth printer: $e');
      return false;
    }
  }

  /// Print Kitchen Order Ticket (KOT) Thermal Receipt for Single KOT Thermal Printer
  Future<bool> printKOT({
    required OrderModel order,
    RestaurantModel? restaurant,
    String? kotNumber,
    bool isReprint = false,
    List<CartItemModel>? customItemsToPrint,
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

      final restName = restaurant?.name.isNotEmpty == true ? restaurant!.name : 'Apna POS Kitchen';

      final dt = DateTime.tryParse(order.createdAt) ?? DateTime.now();
      final formattedDateTime = DateFormat('dd-MM-yyyy,hh:mm:ss a').format(dt).toLowerCase();

      final orderTypeStr = order.orderType == OrderType.dineIn
          ? 'DineIn'
          : (order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery');

      final tableTitle = order.orderType == OrderType.dineIn
          ? (order.tableNumber != null && order.tableNumber!.isNotEmpty
              ? (order.tableNumber!.toLowerCase().startsWith('table')
                  ? 'Dine In-${order.tableNumber}'
                  : 'Dine In-Table ${order.tableNumber!.replaceAll(RegExp(r'[^0-9]'), '').padLeft(2, '0')}')
              : 'Dine In-Table 01')
          : orderTypeStr;

      // 1. Header: KOT or REPRINT (Centered & Bold)
      final String headerTitle = isReprint
          ? '*** KOT REPRINT ***'
          : ((kotNumber != null && kotNumber.isNotEmpty) ? 'KOT #$kotNumber' : 'KOT');

      bytes += generator.text(
        headerTitle,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      );

      // 2. Restaurant Name (Centered & Bold)
      bytes += generator.text(
        _toAscii(restName),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );

      // 3. Order Type (DineIn)
      bytes += generator.text(
        orderTypeStr,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );

      // 4. Table Info (Dine In-Table 01)
      bytes += generator.text(
        tableTitle,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );

      // 5. Order Number & Date Time
      if (order.orderNumber.isNotEmpty) {
        bytes += generator.text(
          'Order: #${_toAscii(order.orderNumber)}',
          styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size1),
        );
      }
      bytes += generator.text(
        formattedDateTime,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );

      // 6. Dashed Line Divider
      bytes += generator.hr(ch: '-');

      // 7. Table Header (Sn | Items | Qty)
      bytes += generator.row([
        PosColumn(
          text: 'Sn',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.left),
        ),
        PosColumn(
          text: 'Items',
          width: 8,
          styles: const PosStyles(bold: true, align: PosAlign.left),
        ),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      // 8. Dashed Line Divider
      bytes += generator.hr(ch: '-');

      // 9. Items List (Resolve pending delta items or full reprint list)
      final List<CartItemModel> itemsToPrint = customItemsToPrint ??
          (isReprint
              ? order.items
              : (order.items.any((i) => i.pendingKotQuantity > 0)
                  ? order.items.where((i) => i.pendingKotQuantity > 0).toList()
                  : order.items));

      for (int i = 0; i < itemsToPrint.length; i++) {
        final cartItem = itemsToPrint[i];
        final sn = '${i + 1}';
        final itemName = _toAscii(cartItem.item.name);

        // Format quantity: if increased on existing sent item, format as +X, else normal qty
        String qtyStr;
        if (isReprint) {
          qtyStr = '${cartItem.quantity}';
        } else if (cartItem.kotQuantity > 0 && cartItem.pendingKotQuantity > 0) {
          qtyStr = '+${cartItem.pendingKotQuantity}';
        } else if (cartItem.pendingKotQuantity > 0) {
          qtyStr = '${cartItem.pendingKotQuantity}';
        } else {
          qtyStr = '${cartItem.quantity}';
        }

        bytes += generator.row([
          PosColumn(
            text: sn,
            width: 2,
            styles: const PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: itemName,
            width: 8,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: qtyStr,
            width: 2,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);

        if (cartItem.note != null && cartItem.note!.trim().isNotEmpty) {
          bytes += generator.text(
            '  * Note: ${_toAscii(cartItem.note!.trim())}',
            styles: const PosStyles(
              align: PosAlign.left,
              fontType: PosFontType.fontB,
            ),
          );
        }
      }

      // 10. Dashed Line Divider
      bytes += generator.hr(ch: '-');

      // 11. Thank you message
      bytes += generator.text(
        'Thank you for dining with us!',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );

      // 12. Tear Margin Feed (3 line feed so manual paper tear does not cut the footer text)
      bytes += generator.feed(3);

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      if (kDebugMode) print('Error sending KOT to thermal printer: $e');
      return false;
    }
  }
}
