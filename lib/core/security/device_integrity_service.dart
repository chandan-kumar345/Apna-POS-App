import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

abstract class IDeviceIntegrityService {
  Future<bool> isDeviceCompromised();
  Future<bool> isEmulator();
  Future<void> enforceSecurityChecks();
}

class DeviceIntegrityService implements IDeviceIntegrityService {
  @override
  Future<bool> isDeviceCompromised() async {
    if (kDebugMode) return false; // Allow development builds

    try {
      bool jailbroken = await SafeDevice.isJailBroken;
      bool devMode = await SafeDevice.isDevelopmentModeEnable;

      return jailbroken || devMode;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isEmulator() async {
    if (kDebugMode) return false;
    try {
      return await SafeDevice.isRealDevice == false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> enforceSecurityChecks() async {
    final compromised = await isDeviceCompromised();
    if (compromised) {
      exit(0); // Immediately terminate process on compromised devices in production
    }
  }
}
