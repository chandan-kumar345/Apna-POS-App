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
