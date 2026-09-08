import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Responsive layout and platform helper for Apna POS.
/// Distinguishes Windows desktop executable widescreen layout from Android / mobile layout.
class ResponsiveLayoutHelper {
  /// Breakpoint for wide desktop UI layout
  static const double desktopBreakpoint = 900.0;
  static const double largeDesktopBreakpoint = 1280.0;
  static const double extraLargeDesktopBreakpoint = 1600.0;

  /// Returns true if running as a Desktop application (Windows, macOS, Linux) on a widescreen display.
  static bool isDesktop(BuildContext context) {
    if (kIsWeb) return MediaQuery.of(context).size.width >= desktopBreakpoint;
    final bool isDesktopOS = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    return isDesktopOS && MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Returns true specifically for Windows Executable desktop mode with wide screen
  static bool isWindowsDesktop(BuildContext context) {
    if (kIsWeb) return false;
    return Platform.isWindows && MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Returns true if running on Android or in a mobile narrow screen format
  static bool isMobileOrAndroid(BuildContext context) {
    if (kIsWeb) return MediaQuery.of(context).size.width < desktopBreakpoint;
    if (Platform.isAndroid || Platform.isIOS) return true;
    return MediaQuery.of(context).size.width < desktopBreakpoint;
  }

  /// Calculates dynamic product grid column count based on available width in POS screen
  static int getPosGridColumnCount(double availableWidth, {bool showImages = true}) {
    if (availableWidth >= 1400) {
      return 6;
    } else if (availableWidth >= 1050) {
      return 5;
    } else if (availableWidth >= 780) {
      return 4;
    } else if (availableWidth >= 500) {
      return 3;
    } else {
      return 2;
    }
  }

  /// Calculates optimal card aspect ratio for product grid
  static double getPosChildAspectRatio(double availableWidth, bool showImages) {
    if (availableWidth >= 1200) {
      return showImages ? 0.88 : 1.45;
    } else if (availableWidth >= 750) {
      return showImages ? 0.86 : 1.35;
    } else {
      return showImages ? 0.84 : 1.25;
    }
  }
}
