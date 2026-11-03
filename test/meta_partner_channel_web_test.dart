import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/settings/meta_partner_channel_screen.dart';
import 'package:apna_pos/core/services/network_service.dart';

void main() {
  tearDown(() {
    NetworkService().dispose();
  });

  testWidgets('MetaPartnerChannelScreen renders Web portal layout with Search and Add Channel button', (tester) async {
    await tester.runAsync(() async {
      // Set desktop web viewport (1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MetaPartnerChannelScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Header
      expect(find.text('Meta Channels'), findsOneWidget);
      expect(find.text('Official Tech Provider'), findsOneWidget);

      // Verify Web Action Controls
      expect(find.text('Search Numbers...'), findsOneWidget);
      expect(find.text('+ Add New Meta Channel'), findsOneWidget);

      // Verify View Mode Switcher
      expect(find.text('Channels Fleet'), findsOneWidget);
      expect(find.text('WABA Settings'), findsOneWidget);

      // Tap "+ Add New Meta Channel" to open Own WhatsApp Channel modal
      await tester.tap(find.text('+ Add New Meta Channel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify "Own WhatsApp Channel" modal dialog contents matching video
      expect(find.text('Own WhatsApp Channel'), findsOneWidget);
      expect(find.text('Prerequisites:'), findsOneWidget);
      expect(find.text('Facebook Business account with admin access'), findsOneWidget);
      expect(find.text('Channel Name *'), findsOneWidget);
      expect(find.text('Phone Number *'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Is Active'), findsOneWidget);
      expect(find.text('Proceed'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Own WhatsApp Channel'), findsNothing);
    });
  });

  testWidgets('MetaPartnerChannelScreen renders mobile view without overflow', (tester) async {
    await tester.runAsync(() async {
      // Set mobile viewport (390x844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MetaPartnerChannelScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Header
      expect(find.text('Meta Channels'), findsOneWidget);
      expect(find.text('Fleet'), findsOneWidget);
      expect(find.text('WABA'), findsOneWidget);
      expect(find.text('Add Channel'), findsOneWidget);
    });
  });
}
