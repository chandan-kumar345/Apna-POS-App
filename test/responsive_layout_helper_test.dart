import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/utils/responsive_layout_helper.dart';

void main() {
  group('ResponsiveLayoutHelper POS Grid Tests', () {
    test('POS grid returns 6 columns on desktop widths (>= 700px)', () {
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(700, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(800, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1000, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1366, showImages: true), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1920, showImages: true), equals(6));

      // Without images
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(700, showImages: false), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1000, showImages: false), equals(6));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(1920, showImages: false), equals(6));
    });

    test('POS grid returns appropriate columns on smaller screens', () {
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(600, showImages: true), equals(4));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(600, showImages: false), equals(5));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(400, showImages: true), equals(3));
      expect(ResponsiveLayoutHelper.getPosGridColumnCount(300, showImages: true), equals(2));
    });

    test('POS child aspect ratio is balanced across desktop widths', () {
      final ratioWideWithImage = ResponsiveLayoutHelper.getPosChildAspectRatio(1280, true);
      final ratioMidWithImage = ResponsiveLayoutHelper.getPosChildAspectRatio(800, true);
      final ratioWithoutImage = ResponsiveLayoutHelper.getPosChildAspectRatio(1280, false);

      expect(ratioWideWithImage, greaterThanOrEqualTo(0.8));
      expect(ratioMidWithImage, greaterThanOrEqualTo(0.8));
      expect(ratioWithoutImage, greaterThan(1.5));
    });
  });
}
