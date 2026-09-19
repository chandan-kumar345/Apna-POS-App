import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/windows_printer_service.dart';
import '../models/order_model.dart';
import '../database/database_service.dart';

class PrinterSelectionDialog extends StatefulWidget {
  final OrderModel? orderToPrint;
  final bool isKot;
  final List<CartItemModel>? customItemsToPrint;
  final String currency;

  const PrinterSelectionDialog({
    super.key,
    this.orderToPrint,
    this.isKot = false,
    this.customItemsToPrint,
    this.currency = '₹',
  });

  static Future<void> show(
    BuildContext context, {
    OrderModel? orderToPrint,
    bool isKot = false,
    List<CartItemModel>? customItemsToPrint,
    String currency = '₹',
  }) {
    return showDialog(
      context: context,
      builder: (context) => PrinterSelectionDialog(
        orderToPrint: orderToPrint,
        isKot: isKot,
        customItemsToPrint: customItemsToPrint,
        currency: currency,
      ),
    );
  }

  @override
  State<PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  final WindowsPrinterService _windowsPrinterService = WindowsPrinterService();

  // Mobile State
  List<BluetoothInfo> _devices = [];
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isBluetoothOn = true;
  bool _isConnecting = false;
  String? _statusMessage;
  BluetoothInfo? _connectedDevice;
  Map<String, String?> _savedPrinter = {};

  // Windows State
  List<WindowsPrinterInfo> _windowsPrinters = [];
  WindowsPrinterInfo? _selectedWindowsPrinter;

  final TextEditingController _macInputController = TextEditingController();

  bool get _isWindows => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    // 1. Instant Cache Initialization: Show cached devices & preferences immediately (0ms delay)
    if (_isWindows) {
      if (_windowsPrinterService.cachedPrinters.isNotEmpty) {
        _windowsPrinters = _windowsPrinterService.cachedPrinters;
        _isLoading = false;
      }
    } else {
      if (_printerService.hasCachedData) {
        _devices = _printerService.cachedBondedDevices;
        _savedPrinter = _printerService.cachedSavedPrinter;
        _isLoading = false;
        if (_savedPrinter['address'] != null) {
          _connectedDevice = _printerService.selectedDevice ??
              BluetoothInfo(
                name: _savedPrinter['name'] ?? 'Saved Printer',
                macAdress: _savedPrinter['address']!,
              );
        }
      }
    }
    _loadDevicesAndStatus();
  }

  @override
  void dispose() {
    _macInputController.dispose();
    super.dispose();
  }

  Future<void> _loadDevicesAndStatus({bool isManualRefresh = false}) async {
    if (_isLoading && !isManualRefresh && (_devices.isNotEmpty || _windowsPrinters.isNotEmpty)) {
      _isLoading = false;
    } else if (isManualRefresh || (_devices.isEmpty && _windowsPrinters.isEmpty)) {
      setState(() {
        _isLoading = true;
        _statusMessage = null;
      });
    }

    if (_isWindows) {
      // Windows Detection Flow (Instant Win32 Spooler + Bluetooth COM/SPP)
      final printers = await _windowsPrinterService.getInstalledPrinters(forceRefresh: isManualRefresh);
      final activeDefault = await _windowsPrinterService.getActiveDefaultPrinter();

      if (!mounted) return;
      setState(() {
        _windowsPrinters = printers;
        _selectedWindowsPrinter = activeDefault;
        _isConnected = activeDefault != null;
        _isLoading = false;

        if (printers.isEmpty) {
          _statusMessage = '⚠️ No printers found. Connect a printer or pair Bluetooth printer in Windows Settings.';
        } else if (activeDefault != null) {
          _statusMessage = '🟢 Connected to ${activeDefault.name}';
        }
      });

      // If opening for direct print and only 1 printer or default selected
      if (widget.orderToPrint != null && activeDefault != null && !isManualRefresh) {
        if (printers.length == 1) {
          // Exactly 1 printer -> print immediately
          _printToWindowsPrinter(activeDefault);
        }
      }
    } else {
      // Mobile Android/iOS Flow
      final results = await Future.wait([
        _printerService.getSavedPrinter(forceRefresh: isManualRefresh),
        _printerService.isBluetoothOn(),
        _printerService.isConnected(),
        _printerService.getBondedDevices(forceRefresh: isManualRefresh),
      ]);

      final Map<String, String?> saved = results[0] as Map<String, String?>;
      final bool btOn = results[1] as bool;
      final bool connected = results[2] as bool;
      final List<BluetoothInfo> bondedDevices = results[3] as List<BluetoothInfo>;

      if (!mounted) return;

      setState(() {
        _isBluetoothOn = btOn;
        _isConnected = connected;
        _devices = bondedDevices;
        _savedPrinter = saved;
        _connectedDevice = _printerService.selectedDevice ??
            (saved['address'] != null
                ? BluetoothInfo(name: saved['name'] ?? 'Saved Printer', macAdress: saved['address']!)
                : (bondedDevices.isNotEmpty ? bondedDevices.first : null));
        _isLoading = false;

        if (!btOn) {
          _statusMessage = '⚠️ System Bluetooth adapter is turned OFF on your phone.';
        } else if (connected && _connectedDevice != null) {
          _statusMessage = widget.isKot
              ? '🟢 Printer connected and ready to print KOT tickets!'
              : '🟢 Printer connected and ready to print bills!';
        }
      });

      // Handle Printing / Auto-Connect on Mobile
      if (widget.orderToPrint != null) {
        if (connected) {
          if (widget.isKot) {
            _printKot();
          } else {
            _printBill();
          }
        } else if (btOn && saved['address'] != null && saved['address']!.isNotEmpty) {
          _autoConnectAndPrint();
        }
      } else if (!connected && btOn && saved['address'] != null && saved['address']!.isNotEmpty) {
        _silentAutoConnect();
      }
    }
  }

  Future<void> _selectWindowsDefault(WindowsPrinterInfo printer) async {
    await _windowsPrinterService.saveDefaultPrinter(printer.name, portName: printer.portName);
    if (!mounted) return;
    setState(() {
      _selectedWindowsPrinter = printer;
      _isConnected = true;
      _statusMessage = '🟢 Connected to: ${printer.name}';
    });

    if (widget.orderToPrint != null) {
      await _printToWindowsPrinter(printer);
    }
  }

  Future<void> _printToWindowsPrinter(WindowsPrinterInfo printer) async {
    if (widget.orderToPrint == null) return;

    setState(() {
      _statusMessage = 'Printing to ${printer.name}...';
    });

    final dbInstance = DatabaseService();
    final restaurant = dbInstance.restaurant;
    final user = dbInstance.currentUser;

    bool success = false;
    if (widget.isKot) {
      success = await _printerService.printKOT(
        order: widget.orderToPrint!,
        restaurant: restaurant,
        isReprint: true,
        customItemsToPrint: widget.customItemsToPrint,
        windowsPrinter: printer,
      );
    } else {
      success = await _printerService.printBill(
        order: widget.orderToPrint!,
        restaurant: restaurant,
        user: user,
        currency: widget.currency,
        windowsPrinter: printer,
      );
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.isKot ? 'KOT' : 'Bill'} printed successfully on ${printer.name}!'),
          backgroundColor: const Color(0xFF051C48),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _statusMessage = 'Failed to send print job to ${printer.name}. Check printer power / connection.';
      });
    }
  }

  Future<void> _silentAutoConnect() async {
    final success = await _printerService.autoConnectSavedPrinter();
    if (!mounted) return;
    if (success) {
      setState(() {
        _isConnected = true;
        _connectedDevice = _printerService.selectedDevice;
        _statusMessage = widget.isKot
            ? '🟢 Printer connected and ready to print KOT tickets!'
            : '🟢 Printer connected and ready to print bills!';
      });
    }
  }

  Future<void> _autoConnectAndPrint() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to saved printer...';
    });

    final success = await _printerService.autoConnectSavedPrinter();
    if (!mounted) return;

    setState(() {
      _isConnecting = false;
      _isConnected = success;
      if (success) {
        _connectedDevice = _printerService.selectedDevice;
        _statusMessage = '🟢 Printer connected!';
      } else {
        _statusMessage = '⚠️ Could not auto-connect to saved printer. Please select your printer below.';
      }
    });

    if (success && widget.orderToPrint != null) {
      if (widget.isKot) {
        await _printKot();
      } else {
        await _printBill();
      }
    }
  }

  Future<void> _connectToDevice(BluetoothInfo device) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting Bluetooth to ${device.name.isNotEmpty ? device.name : 'Printer'} (${device.macAdress})...';
    });

    final success = await _printerService.connect(device);

    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _isConnected = success;
      if (success) {
        _connectedDevice = device;
        _statusMessage = '🟢 Connected to ${device.name.isNotEmpty ? device.name : 'Printer'} successfully!';
      } else {
        _statusMessage = '❌ Could not connect to ${device.name.isNotEmpty ? device.name : 'Printer'}. Ensure printer is ON & near mobile.';
      }
    });

    if (success && widget.orderToPrint != null) {
      if (widget.isKot) {
        await _printKot();
      } else {
        await _printBill();
      }
    }
  }

  Future<void> _openBluetoothSettings() async {
    if (_isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', 'ms-settings:bluetooth']);
      } catch (_) {}
    } else {
      await openAppSettings();
    }
    await Future.delayed(const Duration(milliseconds: 600));
    _loadDevicesAndStatus(isManualRefresh: true);
  }

  Future<void> _connectByMacAddress() async {
    final mac = _macInputController.text.trim();
    if (mac.isEmpty) return;

    final customDevice = BluetoothInfo(name: 'Thermal Printer', macAdress: mac);
    await _connectToDevice(customDevice);
  }

  Future<void> _printKot() async {
    if (widget.orderToPrint == null) return;

    setState(() {
      _statusMessage = 'Sending KOT ticket to kitchen thermal printer...';
    });

    final dbInstance = DatabaseService();
    final restaurant = dbInstance.restaurant;
    final success = await _printerService.printKOT(
      order: widget.orderToPrint!,
      restaurant: restaurant,
      isReprint: true,
      customItemsToPrint: widget.customItemsToPrint,
      windowsPrinter: _selectedWindowsPrinter,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KOT Printed successfully via Thermal Printer!'),
          backgroundColor: Color(0xFF051C48),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _statusMessage = 'Failed to send KOT print job. Ensure printer is paired & turned ON.';
      });
    }
  }

  Future<void> _printBill() async {
    if (widget.orderToPrint == null) return;

    setState(() {
      _statusMessage = 'Sending bill receipt to thermal printer...';
    });

    final dbInstance = DatabaseService();
    final restaurant = dbInstance.restaurant;
    final user = dbInstance.currentUser;
    final success = await _printerService.printBill(
      order: widget.orderToPrint!,
      restaurant: restaurant,
      user: user,
      currency: widget.currency,
      windowsPrinter: _selectedWindowsPrinter,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill printed successfully via thermal printer!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _statusMessage = 'Failed to send print job. Re-connect printer and try again.';
      });
    }
  }

  Future<void> _testPrint() async {
    setState(() {
      _statusMessage = 'Printing test bill...';
    });

    final restaurant = DatabaseService().restaurant;
    final success = await _printerService.printTestReceipt(
      restaurant: restaurant,
      isKot: false,
      windowsPrinter: _selectedWindowsPrinter,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test bill printed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _statusMessage = 'Test bill print successful!';
      });
    } else {
      setState(() {
        _statusMessage = 'Test print failed. Check printer power, paper & connection.';
      });
    }
  }

  Future<void> _testKotPrint() async {
    setState(() {
      _statusMessage = 'Printing test KOT ticket...';
    });

    final restaurant = DatabaseService().restaurant;
    final success = await _printerService.printTestReceipt(
      restaurant: restaurant,
      isKot: true,
      windowsPrinter: _selectedWindowsPrinter,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test KOT printed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _statusMessage = 'Test KOT print successful!';
      });
    } else {
      setState(() {
        _statusMessage = 'Test KOT print failed. Check printer power, paper & connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF051C48),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isWindows ? 'Windows & Bluetooth Printers' : 'Printer Setting',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Main Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle
                      Text(
                        widget.orderToPrint != null
                            ? (widget.isKot ? 'Select printer to print KOT #${widget.orderToPrint!.orderNumber}' : 'Select printer to print Bill #${widget.orderToPrint!.orderNumber}')
                            : (_isWindows ? 'Thermal POS, USB & Bluetooth Printers' : 'Bluetooth Thermal Printer Setup'),
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),

                      // Bluetooth Warning Card (on Mobile if BT is OFF)
                      if (!_isWindows && !_isBluetoothOn) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bluetooth_disabled_rounded, color: Color(0xFFEF4444), size: 22),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bluetooth is Turned OFF',
                                      style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      'Turn on Bluetooth to detect printers',
                                      style: TextStyle(color: Color(0xFF991B1B), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _openBluetoothSettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: const Text('Turn ON', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Current Connection / Default Status Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                          border: Border.all(
                            color: _isConnected ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isConnected ? Icons.check_circle_rounded : Icons.print_outlined,
                              color: _isConnected ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isWindows
                                    ? (_selectedWindowsPrinter != null
                                        ? 'Connected: ${_selectedWindowsPrinter!.name}'
                                        : 'No Printer Connected')
                                    : (_isConnected
                                        ? 'Connected: ${_connectedDevice?.name.isNotEmpty == true ? _connectedDevice!.name : 'Thermal Printer'}'
                                        : (_savedPrinter['name'] != null
                                            ? 'Saved: ${_savedPrinter['name']} (Disconnected)'
                                            : 'No Printer Connected')),
                                style: TextStyle(
                                  color: _isConnected ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (_isConnected)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton(
                                    onPressed: _testPrint,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      side: const BorderSide(color: Color(0xFF051C48), width: 1.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      backgroundColor: const Color(0x0D051C48),
                                    ),
                                    child: const Text('Test Bill', style: TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    onPressed: _testKotPrint,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      side: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      backgroundColor: const Color(0x0DD97706),
                                    ),
                                    child: const Text('Test KOT', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      if (_statusMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _statusMessage!.contains('Could not') || _statusMessage!.contains('OFF') || _statusMessage!.contains('Failed') || _statusMessage!.contains('❌')
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF051C48),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _isWindows ? 'Available Printers & Bluetooth Devices' : 'Available Printers',
                              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _openBluetoothSettings,
                                icon: Icon(_isWindows ? Icons.settings_rounded : Icons.settings_bluetooth_rounded, color: const Color(0xFF051C48), size: 16),
                                label: Text(_isWindows ? 'Settings' : 'Settings', style: const TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF051C48), size: 20),
                                tooltip: 'Refresh printers',
                                onPressed: () => _loadDevicesAndStatus(isManualRefresh: true),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // --- Windows Printers List ---
                      if (_isWindows) ...[
                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(color: Color(0xFF051C48)),
                                ),
                              )
                            : _windowsPrinters.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.print_disabled_rounded, color: Color(0xFFD97706), size: 22),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'No Windows or Bluetooth printers detected',
                                                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Text('• Pair Bluetooth thermal printer in Windows Bluetooth Settings', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                        Text('• Connect USB POS printer or install standard printer driver', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                        Text('• Click Refresh above to reload devices', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                      ],
                                    ),
                                  )
                                : Container(
                                    constraints: const BoxConstraints(maxHeight: 250),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: _windowsPrinters.length,
                                      separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 1),
                                      itemBuilder: (context, index) {
                                        final printer = _windowsPrinters[index];
                                        final isSelected = _selectedWindowsPrinter?.name.toLowerCase() == printer.name.toLowerCase();

                                        return ListTile(
                                          dense: true,
                                          leading: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: printer.isBluetooth ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              printer.isBluetooth ? Icons.bluetooth_audio_rounded : Icons.print_rounded,
                                              color: isSelected
                                                  ? const Color(0xFF16A34A)
                                                  : (printer.isBluetooth ? const Color(0xFF2563EB) : const Color(0xFF051C48)),
                                              size: 18,
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  printer.name,
                                                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ),
                                              if (printer.isBluetooth)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  margin: const EdgeInsets.only(left: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDBEAFE),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text('Bluetooth', style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                                ),
                                              if (isSelected)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  margin: const EdgeInsets.only(left: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                                  ),
                                                  child: const Text('Connected', style: TextStyle(color: Color(0xFF15803D), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                                ),
                                            ],
                                          ),
                                          subtitle: Text(
                                            printer.portName.isNotEmpty ? 'Port: ${printer.portName}' : (printer.status ?? 'Ready'),
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                          ),
                                          trailing: ElevatedButton(
                                            onPressed: () => _selectWindowsDefault(printer),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isSelected ? const Color(0xFF16A34A) : const Color(0xFF051C48),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              elevation: 0,
                                            ),
                                            child: Text(
                                              widget.orderToPrint != null ? 'Print' : (isSelected ? 'Connected' : 'Select'),
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                      ] else ...[
                        // --- Mobile Bluetooth Devices List ---
                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(color: Color(0xFF051C48)),
                                ),
                              )
                            : _devices.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.bluetooth_searching_rounded, color: Color(0xFFD97706), size: 22),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'No Bluetooth printers detected',
                                                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Text('• Turn ON printer & pair in Bluetooth Settings', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                        const Text('• Tap Refresh to search again', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                        const SizedBox(height: 12),
                                        const Divider(color: Color(0xFFE2E8F0)),
                                        const SizedBox(height: 8),

                                        // Manual MAC Address Connect Option
                                        const Text('Connect by MAC Address:', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _macInputController,
                                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                                                decoration: InputDecoration(
                                                  hintText: 'e.g. 00:11:22:33:44:55',
                                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: _connectByMacAddress,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF051C48),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                elevation: 0,
                                              ),
                                              child: const Text('Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: _devices.length,
                                      separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 1),
                                      itemBuilder: (context, index) {
                                        final device = _devices[index];
                                        final isThisDeviceConnected = _isConnected &&
                                            (_connectedDevice?.macAdress == device.macAdress || _printerService.selectedDevice?.macAdress == device.macAdress);

                                        return ListTile(
                                          dense: true,
                                          leading: Icon(
                                            Icons.print_rounded,
                                            color: isThisDeviceConnected ? const Color(0xFF16A34A) : const Color(0xFF051C48),
                                          ),
                                          title: Text(
                                            device.name.trim().isNotEmpty ? device.name : 'Thermal Printer (${device.macAdress})',
                                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          subtitle: Text(
                                            device.macAdress,
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                          ),
                                          trailing: _isConnecting && _connectedDevice?.macAdress == device.macAdress
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                                                )
                                              : ElevatedButton(
                                                  onPressed: () => _connectToDevice(device),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: isThisDeviceConnected
                                                        ? const Color(0xFF16A34A)
                                                        : const Color(0xFF051C48),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    elevation: 0,
                                                  ),
                                                  child: Text(
                                                    isThisDeviceConnected ? 'Connected' : 'Connect',
                                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                        );
                                      },
                                    ),
                                  ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Fixed Bottom Action Buttons
              if (widget.orderToPrint != null && _isConnected)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.isKot)
                      ElevatedButton.icon(
                        onPressed: _printKot,
                        icon: const Icon(Icons.soup_kitchen_rounded, size: 18, color: Colors.white),
                        label: const Text('Print KOT to Kitchen', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF051C48),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _printBill,
                        icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                        label: const Text('Print Bill Now', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF051C48),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
