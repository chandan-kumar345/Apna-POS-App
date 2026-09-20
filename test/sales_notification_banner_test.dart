import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/services/sales_notification_banner_generator.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  group('SalesNotificationBannerGenerator Tests', () {
    test('Generates valid PNG banner with 3 metric cards', () async {
      final bannerPath = await SalesNotificationBannerGenerator.generateBannerFile(
        totalSales: 7136.0,
        orderCount: 10,
        avgOrderValue: 714.0,
      );

      expect(bannerPath, isNotNull);
      final file = File(bannerPath!);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100)); // Non-empty PNG

      // Verify PNG header: 0x89 0x50 0x4E 0x47
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });

    test('Calculates avgOrderValue automatically when null', () async {
      final bannerPath = await SalesNotificationBannerGenerator.generateBannerFile(
        totalSales: 15000.0,
        orderCount: 5,
      );

      expect(bannerPath, isNotNull);
      final file = File(bannerPath!);
      expect(await file.exists(), isTrue);
    });
  });
}
