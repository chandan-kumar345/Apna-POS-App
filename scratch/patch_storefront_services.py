with open('lib/features/storefront/services/storefront_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

target = """      await _apiClient.post(
        ApiEndpoints.storefrontOrder(slugTarget),
        data: {
          'orderNumber': orderNumber,"""

replacement = """      await _apiClient.post(
        ApiEndpoints.storefrontOrder(slugTarget),
        data: {
          'orderId': order.id,
          'restaurantId': restaurant.id,
          'businessId': restaurant.id,
          'orderNumber': orderNumber,"""

post_target = """    } catch (e) {
      debugPrint('[StorefrontService] Backend order submit notice: $e');
    }

    return localSuccess;"""

post_replacement = """    } catch (e) {
      debugPrint('[StorefrontService] Backend order submit notice: $e');
    }

    // 3. Dual-dispatch to Cloud Firestore for instant real-time POS notification
    if (restaurant.id.isNotEmpty) {
      unawaited(
        FirestoreService().submitStorefrontOrder(order, restaurantId: restaurant.id).catchError((e) {
          debugPrint('[StorefrontService] Firestore storefront order notice: $e');
          return false;
        }),
      );
    }

    return localSuccess;"""

text_norm = text.replace('\r\n', '\n')
target_norm = target.replace('\r\n', '\n')
post_target_norm = post_target.replace('\r\n', '\n')

if target_norm in text_norm and post_target_norm in text_norm:
    text_norm = text_norm.replace(target_norm, replacement)
    text_norm = text_norm.replace(post_target_norm, post_replacement)
    with open('lib/features/storefront/services/storefront_service.dart', 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(text_norm)
    print("SUCCESS: storefront_service.dart patched")
else:
    print("FAILED: storefront_service target not found")

with open('lib/features/storefront/services/customer_storefront_api_service.dart', 'r', encoding='utf-8') as f:
    text2 = f.read()

target2 = """          'restaurantId': restaurant.id,"""
replacement2 = """          'restaurantId': restaurant.id,
          'businessId': restaurant.id,"""

text2_norm = text2.replace('\r\n', '\n')
target2_norm = target2.replace('\r\n', '\n')

if target2_norm in text2_norm:
    text2_norm = text2_norm.replace(target2_norm, replacement2)
    with open('lib/features/storefront/services/customer_storefront_api_service.dart', 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(text2_norm)
    print("SUCCESS: customer_storefront_api_service.dart patched")
else:
    print("FAILED: customer_storefront_api_service target not found")
