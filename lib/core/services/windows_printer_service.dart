import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Win32 Spooler Data Structures & Function Types ---

final class DOC_INFO_1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

final class PRINTER_INFO_4 extends Struct {
  external Pointer<Utf16> pPrinterName;
  external Pointer<Utf16> pServerName;
  @Uint32()
  external int attributes;
}

typedef OpenPrinterC = Int32 Function(Pointer<Utf16> pPrinterName, Pointer<IntPtr> phPrinter, Pointer<Void> pDefault);
typedef OpenPrinterDart = int Function(Pointer<Utf16> pPrinterName, Pointer<IntPtr> phPrinter, Pointer<Void> pDefault);

typedef StartDocPrinterC = Uint32 Function(IntPtr hPrinter, Uint32 Level, Pointer<DOC_INFO_1> pDocInfo);
typedef StartDocPrinterDart = int Function(int hPrinter, int Level, Pointer<DOC_INFO_1> pDocInfo);

typedef StartPagePrinterC = Int32 Function(IntPtr hPrinter);
typedef StartPagePrinterDart = int Function(int hPrinter);

typedef WritePrinterC = Int32 Function(IntPtr hPrinter, Pointer<Uint8> pBuf, Uint32 cbBuf, Pointer<Uint32> pcbWritten);
typedef WritePrinterDart = int Function(int hPrinter, Pointer<Uint8> pBuf, int cbBuf, Pointer<Uint32> pcbWritten);

typedef EndPagePrinterC = Int32 Function(IntPtr hPrinter);
typedef EndPagePrinterDart = int Function(int hPrinter);

typedef EndDocPrinterC = Int32 Function(IntPtr hPrinter);
typedef EndDocPrinterDart = int Function(int hPrinter);

typedef ClosePrinterC = Int32 Function(IntPtr hPrinter);
typedef ClosePrinterDart = int Function(int hPrinter);

typedef EnumPrintersC = Int32 Function(
  Uint32 flags,
  Pointer<Utf16> name,
  Uint32 level,
  Pointer<Uint8> pPrinterEnum,
  Uint32 cbBuf,
  Pointer<Uint32> pcbNeeded,
  Pointer<Uint32> pcReturned,
);
typedef EnumPrintersDart = int Function(
  int flags,
  Pointer<Utf16> name,
  int level,
  Pointer<Uint8> pPrinterEnum,
  int cbBuf,
  Pointer<Uint32> pcbNeeded,
  Pointer<Uint32> pcReturned,
);

typedef GetDefaultPrinterC = Int32 Function(Pointer<Utf16> pszBuffer, Pointer<Uint32> pcchBuffer);
typedef GetDefaultPrinterDart = int Function(Pointer<Utf16> pszBuffer, Pointer<Uint32> pcchBuffer);

// --- Win32 File/COM Port Handle Function Types ---

typedef CreateFileC = IntPtr Function(
  Pointer<Utf16> lpFileName,
  Uint32 dwDesiredAccess,
  Uint32 dwShareMode,
  Pointer<Void> lpSecurityAttributes,
  Uint32 dwCreationDisposition,
  Uint32 dwFlagsAndAttributes,
  IntPtr hTemplateFile,
);
typedef CreateFileDart = int Function(
  Pointer<Utf16> lpFileName,
  int dwDesiredAccess,
  int dwShareMode,
  Pointer<Void> lpSecurityAttributes,
  int dwCreationDisposition,
  int dwFlagsAndAttributes,
  int hTemplateFile,
);

typedef WriteFileC = Int32 Function(
  IntPtr hFile,
  Pointer<Uint8> lpBuffer,
  Uint32 nNumberOfBytesToWrite,
  Pointer<Uint32> lpNumberOfBytesWritten,
  Pointer<Void> lpOverlapped,
);
typedef WriteFileDart = int Function(
  int hFile,
  Pointer<Uint8> lpBuffer,
  int nNumberOfBytesToWrite,
  Pointer<Uint32> lpNumberOfBytesWritten,
  Pointer<Void> lpOverlapped,
);

typedef CloseHandleC = Int32 Function(IntPtr hObject);
typedef CloseHandleDart = int Function(int hObject);

/// Model representing an installed or paired printer on Windows
class WindowsPrinterInfo {
  final String name;
  final bool isDefault;
  final String portName;
  final bool isBluetooth;
  final String? macAddress;
  final String? status;

  const WindowsPrinterInfo({
    required this.name,
    this.isDefault = false,
    this.portName = '',
    this.isBluetooth = false,
    this.macAddress,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'isDefault': isDefault,
        'portName': portName,
        'isBluetooth': isBluetooth,
        'macAddress': macAddress,
        'status': status,
      };

  factory WindowsPrinterInfo.fromJson(Map<String, dynamic> json) => WindowsPrinterInfo(
        name: json['name'] ?? '',
        isDefault: json['isDefault'] == true,
        portName: json['portName'] ?? '',
        isBluetooth: json['isBluetooth'] == true,
        macAddress: json['macAddress'],
        status: json['status'],
      );

  @override
  String toString() => 'WindowsPrinterInfo(name: $name, isDefault: $isDefault, port: $portName, bt: $isBluetooth)';
}

/// Service providing native Windows Printing (Spooler & Bluetooth COM/SPP)
class WindowsPrinterService {
  static final WindowsPrinterService _instance = WindowsPrinterService._internal();
  factory WindowsPrinterService() => _instance;
  WindowsPrinterService._internal();

  static const String _prefSavedWindowsPrinter = 'saved_windows_printer_name';
  static const String _prefSavedWindowsPort = 'saved_windows_printer_port';

  List<WindowsPrinterInfo>? _cachedPrinters;
  String? _cachedSavedPrinterName;
  bool _isScanning = false;

  bool get isSupported => !kIsWeb && Platform.isWindows;
  List<WindowsPrinterInfo> get cachedPrinters => _cachedPrinters ?? [];
  String? get cachedSavedPrinterName => _cachedSavedPrinterName;

  /// Fast retrieval of system default printer name from Win32 API
  String? getSystemDefaultPrinter() {
    if (!isSupported) return null;
    try {
      final winspool = DynamicLibrary.open('winspool.drv');
      final getDefaultPrinter = winspool.lookupFunction<GetDefaultPrinterC, GetDefaultPrinterDart>('GetDefaultPrinterW');

      final bufLenPtr = calloc<Uint32>();
      bufLenPtr.value = 0;
      getDefaultPrinter(nullptr, bufLenPtr);

      if (bufLenPtr.value > 0) {
        final nameBuf = calloc<Uint16>(bufLenPtr.value).cast<Utf16>();
        final ok = getDefaultPrinter(nameBuf, bufLenPtr);
        String? result;
        if (ok != 0) {
          result = nameBuf.toDartString();
        }
        calloc.free(nameBuf);
        calloc.free(bufLenPtr);
        return result;
      }
      calloc.free(bufLenPtr);
    } catch (e) {
      if (kDebugMode) print('[WindowsPrinterService] Error getting system default printer: $e');
    }
    return null;
  }

  /// Get user-saved default printer name from SharedPreferences
  Future<String?> getSavedPrinterName({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSavedPrinterName != null) {
      return _cachedSavedPrinterName;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedSavedPrinterName = prefs.getString(_prefSavedWindowsPrinter);
      return _cachedSavedPrinterName;
    } catch (_) {
      return _cachedSavedPrinterName;
    }
  }

  /// Save default printer choice
  Future<void> saveDefaultPrinter(String printerName, {String portName = ''}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSavedWindowsPrinter, printerName);
      await prefs.setString(_prefSavedWindowsPort, portName);
      _cachedSavedPrinterName = printerName;
    } catch (e) {
      if (kDebugMode) print('[WindowsPrinterService] Error saving default printer: $e');
    }
  }

  /// Clear saved default printer
  Future<void> clearSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefSavedWindowsPrinter);
      await prefs.remove(_prefSavedWindowsPort);
      _cachedSavedPrinterName = null;
    } catch (_) {}
  }

  /// Enumerate installed Windows Spooler printers via Win32 FFI (instant <1ms)
  List<WindowsPrinterInfo> getWin32SpoolerPrinters() {
    if (!isSupported) return [];
    final printers = <WindowsPrinterInfo>[];

    try {
      final winspool = DynamicLibrary.open('winspool.drv');
      final enumPrinters = winspool.lookupFunction<EnumPrintersC, EnumPrintersDart>('EnumPrintersW');

      final defaultPrinter = getSystemDefaultPrinter();

      final pcbNeeded = calloc<Uint32>();
      final pcReturned = calloc<Uint32>();
      pcbNeeded.value = 0;
      pcReturned.value = 0;

      // PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS = 6, Level = 4
      enumPrinters(6, nullptr, 4, nullptr, 0, pcbNeeded, pcReturned);

      if (pcbNeeded.value > 0) {
        final buffer = calloc<Uint8>(pcbNeeded.value);
        final ok = enumPrinters(6, nullptr, 4, buffer, pcbNeeded.value, pcbNeeded, pcReturned);
        if (ok != 0) {
          final count = pcReturned.value;
          final infoPtr = buffer.cast<PRINTER_INFO_4>();
          for (int i = 0; i < count; i++) {
            final info = infoPtr.elementAt(i).ref;
            if (info.pPrinterName != nullptr) {
              final name = info.pPrinterName.toDartString();
              if (name.isNotEmpty) {
                printers.add(WindowsPrinterInfo(
                  name: name,
                  isDefault: defaultPrinter != null && name.toLowerCase() == defaultPrinter.toLowerCase(),
                  portName: 'Spooler',
                  isBluetooth: false,
                  status: 'Ready',
                ));
              }
            }
          }
        }
        calloc.free(buffer);
      }
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
    } catch (e) {
      if (kDebugMode) print('[WindowsPrinterService] Win32 Spooler enum error: $e');
    }

    return printers;
  }

  /// Enumerate paired Bluetooth printers & Serial COM ports on Windows
  Future<List<WindowsPrinterInfo>> getBluetoothAndComPrinters() async {
    if (!isSupported) return [];
    final btPrinters = <WindowsPrinterInfo>[];

    try {
      // Query Windows Bluetooth Devices, Serial Ports, and System COM Names
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'''
        $ports = Get-PnpDevice -Class 'Ports' -Status OK -ErrorAction SilentlyContinue | Select-Object FriendlyName, InstanceId, Service
        $bthDevices = Get-PnpDevice -Class 'Bluetooth' -Status OK -ErrorAction SilentlyContinue | Select-Object FriendlyName, InstanceId, Status
        $allComs = [System.IO.Ports.SerialPort]::GetPortNames()
        $output = @{ Ports = $ports; Bluetooth = $bthDevices; ComNames = $allComs }
        $output | ConvertTo-Json -Depth 3 -Compress
        '''
      ]).timeout(const Duration(seconds: 8), onTimeout: () => ProcessResult(0, 1, '', 'timeout'));

      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
        final dynamic rawPorts = data['Ports'];
        final dynamic rawBth = data['Bluetooth'];
        final dynamic rawComNames = data['ComNames'];

        final List<dynamic> portList = rawPorts is List ? rawPorts : (rawPorts != null ? [rawPorts] : []);
        final List<dynamic> bthList = rawBth is List ? rawBth : (rawBth != null ? [rawBth] : []);
        final List<String> systemComNames = (rawComNames is List ? rawComNames : (rawComNames != null ? [rawComNames] : []))
            .map((e) => e.toString().toUpperCase().trim())
            .where((s) => s.isNotEmpty)
            .toList();

        // 1. Filter valid paired Bluetooth devices and extract their MAC addresses
        final Map<String, String> devMacToName = {};
        for (var bth in bthList) {
          final String name = (bth['FriendlyName'] ?? '').toString().trim();
          final String instanceId = (bth['InstanceId'] ?? '').toString();

          if (name.isEmpty) continue;
          final lowerName = name.toLowerCase();
          if (lowerName.contains('generic access') ||
              lowerName.contains('generic attribute') ||
              lowerName.contains('enumerator') ||
              lowerName.contains('intel(r)') ||
              lowerName.contains('wireless bluetooth') ||
              lowerName.contains('avrcp') ||
              lowerName.contains('attribute service') ||
              lowerName.contains('rfcomm protocol') ||
              lowerName.contains('buds') ||
              lowerName.contains('earphone') ||
              lowerName.contains('headphone') ||
              lowerName.contains('speaker') ||
              lowerName.contains('tws') ||
              lowerName.contains('airpod') ||
              lowerName.contains('audio') ||
              lowerName.contains('duopod') ||
              lowerName.contains('watch') ||
              lowerName.contains('chetak') ||
              lowerName.contains('fireboltt') ||
              lowerName.contains('omega') ||
              lowerName.contains('redmi') ||
              lowerName.contains('oppo')) {
            continue;
          }

          // Extract MAC address from InstanceId (e.g. DEV_6632910CC1D9)
          final macMatch = RegExp(r'DEV_([0-9A-Fa-f]{12})').firstMatch(instanceId);
          if (macMatch != null) {
            final rawMac = macMatch.group(1)!.toUpperCase();
            devMacToName[rawMac] = name;
          }
        }

        // 2. Map PnP Ports to Bluetooth Devices & standard Serial COM Ports
        final Set<String> addedPortNames = {};
        final Set<String> addedMacs = {};
        final List<String> unmappedBtComPorts = [];

        for (var port in portList) {
          final String friendly = (port['FriendlyName'] ?? '').toString().trim();
          final String instanceId = (port['InstanceId'] ?? '').toString();
          final String service = (port['Service'] ?? '').toString();

          // Extract COM identifier (e.g. COM6 from "Standard Serial over Bluetooth link (COM6)")
          String comId = '';
          final comMatch = RegExp(r'\((COM\d+)\)', caseSensitive: false).firstMatch(friendly);
          if (comMatch != null) {
            comId = comMatch.group(1)!.toUpperCase();
          }

          if (comId.isEmpty) continue;
          addedPortNames.add(comId);

          // Extract real device MAC address (ignoring base Bluetooth UUID 00805F9B34FB)
          String? matchedMac;
          final macInInstanceMatch = RegExp(r'&([0-9A-Fa-f]{12})_').firstMatch(instanceId);
          if (macInInstanceMatch != null) {
            matchedMac = macInInstanceMatch.group(1)!.toUpperCase();
          } else {
            final devMacMatch = RegExp(r'DEV_([0-9A-Fa-f]{12})').firstMatch(instanceId);
            if (devMacMatch != null) {
              matchedMac = devMacMatch.group(1)!.toUpperCase();
            }
          }

          // Avoid base UUID suffix
          if (matchedMac == '00805F9B34FB' || matchedMac == '000000000000') {
            matchedMac = null;
          }

          String matchedDevName = '';
          if (matchedMac != null && devMacToName.containsKey(matchedMac)) {
            matchedDevName = devMacToName[matchedMac]!;
            addedMacs.add(matchedMac);
          }

          final bool isBtPort = service.toUpperCase() == 'BTHMODEM' ||
              instanceId.toUpperCase().contains('BTHENUM') ||
              friendly.toLowerCase().contains('bluetooth');

          if (isBtPort) {
            if (matchedDevName.isNotEmpty) {
              btPrinters.add(WindowsPrinterInfo(
                name: '$matchedDevName ($comId)',
                portName: comId,
                isBluetooth: true,
                macAddress: matchedMac,
                status: 'Ready ($comId)',
              ));
            } else {
              unmappedBtComPorts.add(comId);
            }
          } else {
            // Standard USB Serial / COM Port
            final displayName = friendly.isNotEmpty ? friendly : 'Serial Port ($comId)';
            btPrinters.add(WindowsPrinterInfo(
              name: displayName,
              portName: comId,
              isBluetooth: false,
              status: 'Ready ($comId)',
            ));
          }
        }

        // 3. Match any named Bluetooth thermal printers that were not mapped by MAC
        for (var entry in devMacToName.entries) {
          final mac = entry.key;
          final devName = entry.value;

          if (addedMacs.contains(mac)) continue;

          final isThermalCandidate = devName.toLowerCase().contains('mpt') ||
              devName.toLowerCase().contains('pos') ||
              devName.toLowerCase().contains('thermal') ||
              devName.toLowerCase().contains('printer') ||
              devName.toLowerCase().contains('receipt') ||
              devName.toLowerCase().contains('rpp') ||
              devName.toLowerCase().contains('xp-') ||
              devName.toLowerCase().contains('inner');

          if (isThermalCandidate) {
            // If there is an unmapped Bluetooth COM port, associate it!
            if (unmappedBtComPorts.isNotEmpty) {
              final assignedCom = unmappedBtComPorts.removeAt(0);
              btPrinters.add(WindowsPrinterInfo(
                name: '$devName ($assignedCom)',
                portName: assignedCom,
                isBluetooth: true,
                macAddress: mac,
                status: 'Ready ($assignedCom)',
              ));
              addedMacs.add(mac);
            } else {
              // Add device with Bluetooth indication
              btPrinters.add(WindowsPrinterInfo(
                name: '$devName (Bluetooth)',
                portName: 'Bluetooth SPP',
                isBluetooth: true,
                macAddress: mac,
                status: 'Paired (Bluetooth)',
              ));
              addedMacs.add(mac);
            }
          }
        }

        // 4. Add any remaining unmapped Bluetooth COM ports
        for (var comId in unmappedBtComPorts) {
          btPrinters.add(WindowsPrinterInfo(
            name: 'Bluetooth Serial Printer ($comId)',
            portName: comId,
            isBluetooth: true,
            status: 'Ready ($comId)',
          ));
        }

        // 5. Add any system COM ports not in PnP list
        for (var comName in systemComNames) {
          if (!addedPortNames.contains(comName) && !btPrinters.any((p) => p.portName.toUpperCase() == comName)) {
            btPrinters.add(WindowsPrinterInfo(
              name: 'Serial Port ($comName)',
              portName: comName,
              isBluetooth: false,
              status: 'Ready ($comName)',
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('[WindowsPrinterService] Error getting Bluetooth/COM printers: $e');
    }

    return btPrinters;
  }

  /// Get complete list of all Windows printers (Spooler + Bluetooth) with caching
  Future<List<WindowsPrinterInfo>> getInstalledPrinters({bool forceRefresh = false}) async {
    if (!isSupported) return [];

    if (!forceRefresh && _cachedPrinters != null && _cachedPrinters!.isNotEmpty) {
      return _cachedPrinters!;
    }

    _isScanning = true;

    // 1. Get Win32 Spooler printers instantly
    final spoolerPrinters = getWin32SpoolerPrinters();

    // 2. Get Paired Bluetooth & COM printers
    final btPrinters = await getBluetoothAndComPrinters();

    // 3. Merge lists
    final savedName = await getSavedPrinterName();
    final allPrinters = <WindowsPrinterInfo>[];

    for (var p in [...spoolerPrinters, ...btPrinters]) {
      final isSavedDefault = savedName != null &&
          (p.name.toLowerCase() == savedName.toLowerCase() ||
              (p.portName.isNotEmpty && p.portName.toLowerCase() == savedName.toLowerCase()) ||
              (savedName.toLowerCase().contains(p.name.toLowerCase()) || p.name.toLowerCase().contains(savedName.toLowerCase())));

      allPrinters.add(WindowsPrinterInfo(
        name: p.name,
        isDefault: isSavedDefault || (savedName == null && p.isDefault),
        portName: p.portName,
        isBluetooth: p.isBluetooth,
        macAddress: p.macAddress,
        status: p.status,
      ));
    }

    _cachedPrinters = allPrinters;
    _isScanning = false;
    return allPrinters;
  }

  /// Resolve the active default printer for Windows printing
  Future<WindowsPrinterInfo?> getActiveDefaultPrinter() async {
    final printers = await getInstalledPrinters();
    if (printers.isEmpty) return null;

    final saved = await getSavedPrinterName();
    if (saved != null && saved.trim().isNotEmpty) {
      final cleanSaved = saved.trim().toLowerCase();
      // Exact name or port match
      for (var p in printers) {
        if (p.name.toLowerCase() == cleanSaved ||
            (p.portName.isNotEmpty && p.portName.toLowerCase() == cleanSaved)) {
          return p;
        }
      }
      // Substring match (e.g. saved 'MPT-II' matches 'MPT-II (COM6)')
      for (var p in printers) {
        if (p.name.toLowerCase().contains(cleanSaved) || cleanSaved.contains(p.name.toLowerCase())) {
          return p;
        }
      }
    }

    // Fall back to printer marked isDefault
    final defaultPrinter = printers.where((p) => p.isDefault).firstOrNull;
    if (defaultPrinter != null) return defaultPrinter;

    // Fall back to first printer
    return printers.first;
  }

  /// Print raw ESC/POS bytes directly to a Windows Spooler printer
  bool printRawBytesToSpooler(String printerName, List<int> bytes, {String docName = 'Apna POS Receipt'}) {
    if (!isSupported) return false;

    try {
      final winspool = DynamicLibrary.open('winspool.drv');
      final openPrinter = winspool.lookupFunction<OpenPrinterC, OpenPrinterDart>('OpenPrinterW');
      final startDocPrinter = winspool.lookupFunction<StartDocPrinterC, StartDocPrinterDart>('StartDocPrinterW');
      final startPagePrinter = winspool.lookupFunction<StartPagePrinterC, StartPagePrinterDart>('StartPagePrinter');
      final writePrinter = winspool.lookupFunction<WritePrinterC, WritePrinterDart>('WritePrinter');
      final endPagePrinter = winspool.lookupFunction<EndPagePrinterC, EndPagePrinterDart>('EndPagePrinter');
      final endDocPrinter = winspool.lookupFunction<EndDocPrinterC, EndDocPrinterDart>('EndDocPrinter');
      final closePrinter = winspool.lookupFunction<ClosePrinterC, ClosePrinterDart>('ClosePrinter');

      final pPrinterName = printerName.toNativeUtf16();
      final phPrinter = calloc<IntPtr>();

      final opened = openPrinter(pPrinterName, phPrinter, nullptr);
      if (opened == 0 || phPrinter.value == 0) {
        calloc.free(pPrinterName);
        calloc.free(phPrinter);
        return false;
      }

      final hPrinter = phPrinter.value;

      final docInfo = calloc<DOC_INFO_1>();
      docInfo.ref.pDocName = docName.toNativeUtf16();
      docInfo.ref.pOutputFile = nullptr;
      docInfo.ref.pDatatype = 'RAW'.toNativeUtf16();

      final jobId = startDocPrinter(hPrinter, 1, docInfo);
      if (jobId == 0) {
        calloc.free(docInfo.ref.pDocName);
        calloc.free(docInfo.ref.pDatatype);
        calloc.free(docInfo);
        closePrinter(hPrinter);
        calloc.free(pPrinterName);
        calloc.free(phPrinter);
        return false;
      }

      startPagePrinter(hPrinter);

      final uint8Bytes = Uint8List.fromList(bytes);
      final pBuf = calloc<Uint8>(uint8Bytes.length);
      pBuf.asTypedList(uint8Bytes.length).setAll(0, uint8Bytes);
      final pcbWritten = calloc<Uint32>();

      final written = writePrinter(hPrinter, pBuf, uint8Bytes.length, pcbWritten);

      endPagePrinter(hPrinter);
      endDocPrinter(hPrinter);
      closePrinter(hPrinter);

      calloc.free(pBuf);
      calloc.free(pcbWritten);
      calloc.free(docInfo.ref.pDocName);
      calloc.free(docInfo.ref.pDatatype);
      calloc.free(docInfo);
      calloc.free(pPrinterName);
      calloc.free(phPrinter);

      return written != 0;
    } catch (e) {
      if (kDebugMode) print('[WindowsPrinterService] Error writing to spooler: $e');
      return false;
    }
  }

  /// Print raw ESC/POS bytes directly to a Serial COM port (Bluetooth SPP / USB Serial)
  Future<bool> printRawBytesToComPort(String comPort, List<int> bytes) async {
    if (!isSupported) return false;

    final String cleanPort = comPort.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleanPort.isEmpty) return false;
    final String devicePath = r'\\.\' + cleanPort;

    // Method 1: Win32 CreateFile / WriteFile Direct Native API (Fastest <5ms)
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final createFile = kernel32.lookupFunction<CreateFileC, CreateFileDart>('CreateFileW');
      final writeFile = kernel32.lookupFunction<WriteFileC, WriteFileDart>('WriteFile');
      final closeHandle = kernel32.lookupFunction<CloseHandleC, CloseHandleDart>('CloseHandle');

      final pFileName = devicePath.toNativeUtf16();
      // GENERIC_READ | GENERIC_WRITE = 0xC0000000, OPEN_EXISTING = 3
      final hFile = createFile(pFileName, 0xC0000000, 0, nullptr, 3, 0, 0);
      calloc.free(pFileName);

      if (hFile != 0 && hFile != -1) {
        final uint8Bytes = Uint8List.fromList(bytes);
        final pBuf = calloc<Uint8>(uint8Bytes.length);
        pBuf.asTypedList(uint8Bytes.length).setAll(0, uint8Bytes);
        final pcbWritten = calloc<Uint32>();

        final success = writeFile(hFile, pBuf, uint8Bytes.length, pcbWritten, nullptr);

        calloc.free(pBuf);
        calloc.free(pcbWritten);
        closeHandle(hFile);

        if (success != 0) return true;
      }
    } catch (e) {
      if (kDebugMode) print('[WindowsPrinterService] Win32 COM write error: $e');
    }

    // Method 2: High-reliability PowerShell .NET SerialPort Stream Fallback
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\pos_print_${DateTime.now().millisecondsSinceEpoch}.bin');
      await tempFile.writeAsBytes(bytes);

      final psScript = '''
\$port = New-Object System.IO.Ports.SerialPort '$cleanPort', 9600, 'None', 8, 'One'
\$port.WriteTimeout = 4000
\$port.Open()
\$bytes = [System.IO.File]::ReadAllBytes('${tempFile.path.replaceAll('\\', '\\\\')}')
\$port.Write(\$bytes, 0, \$bytes.Length)
Start-Sleep -Milliseconds 250
\$port.Close()
''';
      final psResult = await Process.run('powershell', ['-NoProfile', '-Command', psScript])
          .timeout(const Duration(seconds: 5), onTimeout: () => ProcessResult(0, 1, '', 'timeout'));

      try {
        await tempFile.delete();
      } catch (_) {}

      if (psResult.exitCode == 0) return true;
    } catch (e) {
      if (kDebugMode) print('[WindowsPrinterService] PowerShell COM write error: $e');
    }

    return false;
  }

  /// Unified Raw Bytes Print Dispatcher for Windows (Auto-routes Spooler vs Bluetooth COM)
  Future<bool> printRawBytes(WindowsPrinterInfo printer, List<int> bytes, {String docName = 'Apna POS Receipt'}) async {
    if (!isSupported) return false;

    // 1. If it's a COM port or Bluetooth device with a COM port
    if (printer.portName.toUpperCase().startsWith('COM')) {
      final success = await printRawBytesToComPort(printer.portName, bytes);
      if (success) return true;
    }

    // 2. Extract COM port from name if formatted like "Device (COM5)"
    final comMatch = RegExp(r'\((COM\d+)\)', caseSensitive: false).firstMatch(printer.name);
    if (comMatch != null) {
      final port = comMatch.group(1)!;
      final success = await printRawBytesToComPort(port, bytes);
      if (success) return true;
    }

    // 3. Direct Win32 Spooler Printing
    final cleanPrinterName = printer.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    bool spoolerSuccess = printRawBytesToSpooler(cleanPrinterName, bytes, docName: docName);
    if (spoolerSuccess) return true;

    // Try with original printer name if stripped name failed
    spoolerSuccess = printRawBytesToSpooler(printer.name, bytes, docName: docName);
    if (spoolerSuccess) return true;

    return false;
  }
}
