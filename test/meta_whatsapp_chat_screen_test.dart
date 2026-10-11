import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/chat/meta_whatsapp_chat_screen.dart';
import 'package:apna_pos/core/services/whatsapp_chat_service.dart';

import 'package:apna_pos/core/services/network_service.dart';

void main() {
  tearDown(() {
    NetworkService().dispose();
  });

  testWidgets('MetaWhatsAppChatScreen renders smartphone frame mockup and Apna POS bar', (tester) async {
    await tester.runAsync(() async {
      final mockChat = WhatsAppChatModel(
        id: 'chat_123',
        customerPhone: '919876543210',
        customerName: 'Rahul Verma',
        lastMessage: 'Is my order ready?',
        lastMessageAt: DateTime.now(),
        lastMessageDirection: 'INCOMING',
        unreadCount: 1,
      );

      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MetaWhatsAppChatScreen(
            enablePolling: false,
            autoLoad: false,
            initialChats: [mockChat],
          ),
        ),
      );
      await tester.pump();

      // Verify Apna POS App Bar
      expect(find.textContaining('WhatsApp Live'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
      expect(find.byIcon(Icons.tune_rounded), findsWidgets);

      // Verify WhatsApp Mobile Title inside phone frame
      expect(find.text('WhatsApp'), findsOneWidget);

      // Verify fake phone time, battery, wifi, and network icons are removed per user instruction
      expect(find.text('9:41'), findsNothing);
      expect(find.byIcon(Icons.battery_full_rounded), findsNothing);
      expect(find.byIcon(Icons.wifi_rounded), findsNothing);
      expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsNothing);

      // Verify Meta AI Search and Filter pills
      expect(find.text('Ask Meta AI or Search'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);

      // Verify WhatsApp Bottom Navigation Tabs
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Updates'), findsOneWidget);
      expect(find.text('Communities'), findsOneWidget);
      expect(find.text('Calls'), findsOneWidget);

      // Verify New Chat FAB
      expect(find.byIcon(Icons.chat_bubble_rounded), findsWidgets);

      // Verify mock contact is rendered inside the smartphone chat list
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Is my order ready?'), findsOneWidget);

      // Verify opening redesigned New WhatsApp Chat bottom sheet
      await tester.tap(find.byIcon(Icons.person_add_rounded));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('New WhatsApp Chat'), findsOneWidget);
      expect(find.text('Start a 2-way conversation via Meta API'), findsOneWidget);
      expect(find.text('Recipient Phone Number'), findsOneWidget);
      expect(find.text('Customer Name (Optional)'), findsOneWidget);
      expect(find.text('Initial WhatsApp Message'), findsOneWidget);
      expect(find.text('33/1024'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Start Chat'), findsOneWidget);
      // Verify cross button is removed per user instruction
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Dismiss the sheet cleanly
      Navigator.of(tester.element(find.text('New WhatsApp Chat'))).pop();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('New WhatsApp Chat'), findsNothing);

      // Tap on the chat to open conversation view
      await tester.tap(find.text('Rahul Verma'));
      await tester.pump(const Duration(milliseconds: 350));

      // Verify redesigned conversation screen elements matching reference image
      expect(find.byIcon(Icons.call_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Order Ready for Pickup'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.text('Type a message...'), findsOneWidget);
    });
  });
}
