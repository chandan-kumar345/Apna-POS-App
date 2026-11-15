with open('lib/core/services/local_notification_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

target = """      // Check database for any unhandled pending external order placed within last 15 mins
      if (!IncomingOrderAcceptScreen.isShowing) {
        final pendingDbOrder = await DatabaseService()
            .findPendingExternalOrderForPrompt();
        if (pendingDbOrder != null && !IncomingOrderAcceptScreen.isShowing) {
          final pId = (pendingDbOrder['orderId'] ?? '').toString();
          final pNum = (pendingDbOrder['orderNumber'] ?? '').toString();
          if (DatabaseService.isOrderDismissed(pId, pNum)) {
            return;
          }
          final localOrder = DatabaseService().orders
              .where(
                (o) =>
                    (pId.isNotEmpty && o.id == pId) ||
                    (pNum.isNotEmpty && o.orderNumber == pNum),
              )
              .firstOrNull;
          if (localOrder != null && localOrder.status != OrderStatus.pending) {
            DatabaseService.markOrderDismissed(pId, pNum);
            return;
          }

          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            IncomingOrderAcceptScreen.openFromPayload(ctx, pendingDbOrder);
          } else {
            _pendingIncomingOrderPayload = pendingDbOrder;
          }
        }
      }"""

replacement = """      // Note: Live incoming orders arrive in real time via FCM Push, Socket.IO,
      // and Firestore streams. We deliberately do not poll old database orders on
      // normal app open to avoid repeatedly prompting already handled or completed orders."""

text_norm = text.replace('\r\n', '\n')
target_norm = target.replace('\r\n', '\n')

if target_norm in text_norm:
    text_norm = text_norm.replace(target_norm, replacement)
    with open('lib/core/services/local_notification_service.dart', 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(text_norm)
    print("SUCCESS: local_notification_service.dart patched")
else:
    print("FAILED: target not found")
