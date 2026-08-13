import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_printer_service.dart';
import '../models/order_model.dart';
import '../database/database_service.dart';

class PrinterSelectionDialog extends StatefulWidget {
  final OrderModel? orderToPrint;
  final String currency;

  const PrinterSelectionDialog({
    super.key,
    this.orderToPrint,
    this.currency = '₹',
  });

  static Future<void> show(BuildContext context, {OrderModel? orderToPrint, String currency = '₹'}) {
    return showDialog(
      context: context,
      builder: (context) => PrinterSelectionDialog(
        orderToPrint: orderToPrint,
        currency: currency,
      ),
    );
  }

  @override
  State<PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  List<BluetoothInfo> _devices = [];
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isBluetoothOn = true;
  bool _isConnecting = false;
  String? _statusMessage;
  BluetoothInfo? _connectedDevice;
  Map<String, String?> _savedPrinter = {};

  final TextEditingController _macInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDevicesAndStatus();
  }

  @override
  void dispose() {
    _macInputController.dispose();
    super.dispose();
  }

  Future<void> _loadDevicesAndStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    await _printerService.requestPermissions();
    final bool btOn = await _printerService.isBluetoothOn();
    bool connected = await _printerService.isConnected();

    // If not currently connected, try auto-connecting to saved printer preference
    if (!connected && btOn) {
      connected = await _printerService.autoConnectSavedPrinter();
    }

    final Map<String, String?> saved = await _printerService.getSavedPrinter();
    final List<BluetoothInfo> bondedDevices = await _printerService.getBondedDevices();

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
        _statusMessage = '🟢 Printer connected and ready to print bills!';
      }
    });

    // If orderToPrint is provided and already connected, print bill right away
    if (widget.orderToPrint != null && connected) {
      _printBill();
    }
  }

  Future<void> _connectToDevice(BluetoothInfo device) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting Bluetooth to ${device.name.isNotEmpty ? device.name : 'Printer'} (${device.macAdress})...';
    });

    final success = await _printerService.connect(device);

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
      await _printBill();
    }
  }

  Future<void> _openBluetoothSettings() async {
    await openAppSettings();
    await Future.delayed(const Duration(seconds: 1));
    _loadDevicesAndStatus();
  }

  Future<void> _connectByMacAddress() async {
    final mac = _macInputController.text.trim();
    if (mac.isEmpty) return;

    final customDevice = BluetoothInfo(name: 'Thermal Printer', macAdress: mac);
    await _connectToDevice(customDevice);
  }

  Future<void> _printBill() async {
    if (widget.orderToPrint == null) return;

    setState(() {
      _statusMessage = 'Sending bill receipt to thermal printer...';
    });

    final restaurant = DatabaseService().restaurant;
    final success = await _printerService.printBill(
      order: widget.orderToPrint!,
      restaurant: restaurant,
      currency: widget.currency,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill printed successfully via Bluetooth thermal printer!'),
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
    final success = await _printerService.printTestReceipt(restaurant: restaurant, isKot: false);

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
        _statusMessage = 'Test print failed. Check printer paper & bluetooth connection.';
      });
    }
  }

  Future<void> _testKotPrint() async {
    setState(() {
      _statusMessage = 'Printing test KOT ticket...';
    });

    final restaurant = DatabaseService().restaurant;
    final success = await _printerService.printTestReceipt(restaurant: restaurant, isKot: true);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test KOT printed to kitchen successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _statusMessage = 'Test KOT print successful!';
      });
    } else {
      setState(() {
        _statusMessage = 'Test KOT print failed. Check printer paper & bluetooth connection.';
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
          maxWidth: 480,
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
                  Row(
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
                      const Text(
                        'Printer Setting',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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

              // Main Scrollable Content wrapped cleanly inside popup box
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
                            ? 'Print Bill #${widget.orderToPrint!.orderNumber}'
                            : 'Bluetooth Thermal Printer Setup',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),

                      // Bluetooth Warning Card (if BT is turned OFF)
                      if (!_isBluetoothOn) ...[
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

                      // Current Connection Status Card
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
                              _isConnected ? Icons.check_circle_rounded : Icons.bluetooth_searching_rounded,
                              color: _isConnected ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isConnected
                                    ? 'Connected: ${_connectedDevice?.name.isNotEmpty == true ? _connectedDevice!.name : 'Thermal Printer'}'
                                    : (_savedPrinter['name'] != null
                                        ? 'Saved: ${_savedPrinter['name']} (Disconnected)'
                                        : 'No Printer Connected'),
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
                          const Text(
                            'Available Printers',
                            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _openBluetoothSettings,
                                icon: const Icon(Icons.settings_bluetooth_rounded, color: Color(0xFF051C48), size: 16),
                                label: const Text('Settings', style: TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF051C48), size: 20),
                                tooltip: 'Refresh Bluetooth devices',
                                onPressed: _loadDevicesAndStatus,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // List of paired Bluetooth devices
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
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Fixed Bottom Action Buttons
              if (widget.orderToPrint != null && _isConnected)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
