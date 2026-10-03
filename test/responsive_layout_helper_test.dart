import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/utils/responsive_layout_helper.dart';

void main() {
  group('ResponsiveLayoutHelper POS Grid Tests', () {
    test('POS grid returns 6 columns on tablet & desktop widths (>= 680px)', () {
      // Tablet portrait (e.g., iPad 768px, Android tablet 800px)
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(680, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(768, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(800, showImages: true), equals(6));

      // Tablet landscape / Desktop (1024px, 1280px, 1366px, 1920px)
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1024, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1280, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1366, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1920, showImages: true), equals(6));

      // Without images on tablet & desktop
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(680, showImages: false), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(768, showImages: false), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1024, showImages: false), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1920, showImages: false), equals(6));
    });

    test('POS grid returns appropriate columns device-wise for mobile screens', () {
      // Wide mobile / Landscape mobile (500px - 679px)
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(600, showImages: true), equals(4));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(600, showImages: false), equals(5));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(520, showImages: true), equals(4));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(520, showImages: false), equals(5));

      // Standard mobile phone portrait (360px - 499px) -> 3 columns
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(400, showImages: true), equals(3));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(390, showImages: true), equals(3));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(360, showImages: true), equals(3));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(400, showImages: false), equals(3));

      // Small screen mobile (< 360px) -> 2 columns
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(320, showImages: true), equals(2));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(300, showImages: true), equals(2));
    });

    test('POS child aspect ratio is balanced across desktop and touch tablet/mobile modes', () {
      // Desktop mode (isDesktop = true)
      final ratioDesktopWide = ResponsiveLayoutHelper.getPosChildAspectRatio(1280, true, true);
      final ratioDesktopMid = ResponsiveLayoutHelper.getPosChildAspectRatio(800, true, true);
      final ratioDesktopNoImage = ResponsiveLayoutHelper.getPosChildAspectRatio(1280, false, true);

      expect(ratioDesktopWide, greaterThanOrEqualTo(0.8));
      expect(ratioDesktopMid, greaterThanOrEqualTo(0.8));
      expect(ratioDesktopNoImage, greaterThan(1.5));

      // Tablet touch mode (isDesktop = false, width >= 680px)
      final ratioTabletTouchWithImg = ResponsiveLayoutHelper.getPosChildAspectRatio(768, true, false);
      final ratioTabletTouchNoImg = ResponsiveLayoutHelper.getPosChildAspectRatio(768, false, false);
      expect(ratioTabletTouchWithImg, equals(0.60));
      expect(ratioTabletTouchNoImg, equals(1.65));

      // Mobile phone touch mode (isDesktop = false, width < 500px)
      final ratioMobileTouchWithImg = ResponsiveLayoutHelper.getPosChildAspectRatio(390, true, false);
      final ratioMobileTouchNoImg = ResponsiveLayoutHelper.getPosChildAspectRatio(390, false, false);
      expect(ratioMobileTouchWithImg, equals(0.54));
      expect(ratioMobileTouchNoImg, equals(1.55));
    });
  });
}
