import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/chat/meta_whatsapp_chat_screen.dart';
import 'package:apna_pos/core/services/whatsapp_chat_service.dart';

void main() {
  testWidgets('MetaWhatsAppChatScreen renders smartphone frame mockup and Apna POS bar', (tester) async {
    final mockChat = WhatsAppChatModel(
      id: 'chat_123',
      customerPhone: '919876543210',
      customerName: 'Rahul Verma',
      lastMessage: 'Is my order ready?',
      lastMessageAt: DateTime.now(),
      lastMessageDirection: 'INCOMING',
      unreadCount: 1,
    );

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
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // Verify WhatsApp Mobile Title inside phone frame
    expect(find.text('WhatsApp'), findsOneWidget);

    // Verify fake phone time and Dynamic Island
    expect(find.text('9:41'), findsOneWidget);
    expect(find.byIcon(Icons.battery_5_bar_rounded), findsOneWidget);

    // Verify New Chat FAB
    expect(find.byIcon(Icons.chat_bubble_rounded), findsWidgets);

    // Verify mock contact is rendered inside the smartphone chat list
    expect(find.text('Rahul Verma'), findsOneWidget);
    expect(find.text('Is my order ready?'), findsOneWidget);
  });
}
