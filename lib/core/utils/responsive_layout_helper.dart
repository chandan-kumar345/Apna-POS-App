import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Responsive layout and platform helper for Apna POS.
/// Distinguishes Windows desktop executable widescreen layout from tablet and Android / mobile layouts.
class ResponsiveLayoutHelper {
  /// Breakpoint for wide desktop UI layout
  static const double desktopBreakpoint = 900.0;
  static const double largeDesktopBreakpoint = 1280.0;
  static const double extraLargeDesktopBreakpoint = 1600.0;

  /// Breakpoints for devices
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 680.0;

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

  /// Returns true if running on a tablet device or in tablet view width
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (kIsWeb) return width >= 600 && width < desktopBreakpoint;
    final bool isDesktopOS = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (isDesktopOS) {
      return width >= 600 && width < desktopBreakpoint;
    }
    return width >= 600;
  }

  /// Returns true if running on a mobile phone (narrow screen format)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Returns true if running on Android or in a mobile narrow screen format
  static bool isMobileOrAndroid(BuildContext context) {
    if (kIsWeb) return MediaQuery.of(context).size.width < desktopBreakpoint;
    if (Platform.isAndroid || Platform.isIOS) return true;
    return MediaQuery.of(context).size.width < desktopBreakpoint;
  }

  /// Calculates dynamic product grid column count based on available width in POS screen:
  /// - Tablet & Desktop wide views (>= 680px): 6 products in one row
  /// - Large Mobile / Landscape (500px - 679px): 4 products (with images) / 5 products (without images)
  /// - Mobile Portrait (360px - 499px): 3 products per row
  /// - Small Mobile (< 360px): 2 products per row
  static int getPosGridColumnCount(double availableWidth, {bool showImages = true}) {
    if (availableWidth >= 680) {
      return 6;
    } else if (availableWidth >= 500) {
      return showImages ? 4 : 5;
    } else if (availableWidth >= 360) {
      return 3;
    } else {
      return 2;
    }
  }

  /// Calculates optimal card aspect ratio for product grid (width / height) based on screen width & device mode:
  /// Handles both Desktop mode and Tablet/Mobile touch layouts seamlessly.
  static double getPosChildAspectRatio(
    double availableWidth, [
    bool showImages = true,
    bool isDesktop = false,
  ]) {
    if (isDesktop) {
      if (availableWidth >= 1200) {
        return showImages ? 0.85 : 1.85;
      } else if (availableWidth >= 680) {
        return showImages ? 0.84 : 1.80;
      } else {
        return showImages ? 0.82 : 1.65;
      }
    } else {
      if (showImages) {
        if (availableWidth >= 1200) {
          return 0.76;
        } else if (availableWidth >= 900) {
          return 0.68;
        } else if (availableWidth >= 680) {
          // Tablet view 6 columns
          return 0.60;
        } else if (availableWidth >= 500) {
          // Landscape / large mobile 4 columns
          return 0.58;
        } else {
          // Standard mobile 3 columns
          return 0.54;
        }
      } else {
        if (availableWidth >= 1200) {
          return 2.20;
        } else if (availableWidth >= 900) {
          return 1.95;
        } else if (availableWidth >= 680) {
          // Tablet view 6 columns without images
          return 1.65;
        } else if (availableWidth >= 500) {
          return 1.60;
        } else {
          return 1.55;
        }
      }
    }
  }
}
