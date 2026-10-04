import 'windows_printer_models.dart';

/// Stub implementation of WindowsPrinterService for Web / non-Windows platforms
class WindowsPrinterService {
  static final WindowsPrinterService _instance = WindowsPrinterService._internal();
  factory WindowsPrinterService() => _instance;
  WindowsPrinterService._internal();

  bool get isSupported => false;
  List<WindowsPrinterInfo> get cachedPrinters => const [];
  String? get cachedSavedPrinterName => null;

  /// Fast retrieval of system default printer name from Win32 API
  String? getSystemDefaultPrinter() => null;

  /// Get user-saved default printer name from SharedPreferences
  Future<String?> getSavedPrinterName({bool forceRefresh = false}) async => null;

  /// Save default printer choice
  Future<void> saveDefaultPrinter(String printerName, {String portName = ''}) async {}

  /// Clear saved default printer
  Future<void> clearSavedPrinter() async {}

  /// Enumerate installed Windows Spooler printers via Win32 FFI (instant <1ms)
  List<WindowsPrinterInfo> getWin32SpoolerPrinters() => const [];

  /// Enumerate paired Bluetooth printers & Serial COM ports on Windows
  Future<List<WindowsPrinterInfo>> getBluetoothAndComPrinters() async => const [];

  /// Get complete list of all Windows printers (Spooler + Bluetooth) with caching
  Future<List<WindowsPrinterInfo>> getInstalledPrinters({bool forceRefresh = false}) async => const [];

  /// Resolve the active default printer for Windows printing
  Future<WindowsPrinterInfo?> getActiveDefaultPrinter() async => null;

  /// Print raw ESC/POS bytes directly to a Windows Spooler printer
  bool printRawBytesToSpooler(String printerName, List<int> bytes, {String docName = 'Apna POS Receipt'}) => false;

  /// Print raw ESC/POS bytes directly to a Serial COM port (Bluetooth SPP / USB Serial)
  Future<bool> printRawBytesToComPort(String comPort, List<int> bytes) async => false;

  /// Unified Raw Bytes Print Dispatcher for Windows (Auto-routes Spooler vs Bluetooth COM)
  Future<bool> printRawBytes(WindowsPrinterInfo printer, List<int> bytes, {String docName = 'Apna POS Receipt'}) async => false;
}
