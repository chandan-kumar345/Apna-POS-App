import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/main.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/services/socket_service.dart';
import 'package:apna_pos/core/services/network_service.dart';

void main() {
  testWidgets('Apna POS app test', (WidgetTester tester) async {
    final db = DatabaseService();
    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();
    
    await tester.pumpWidget(const ApnaPosApp());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 10));
    
    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();
  });
}

