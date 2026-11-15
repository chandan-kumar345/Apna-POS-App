import '../../../core/models/restaurant_model.dart';
import 'storefront_model.dart';

class TableQrBill {
  final int subtotalMinor;
  final int taxMinor;

  const TableQrBill._(this.subtotalMinor, this.taxMinor);

  factory TableQrBill.calculate(
    Iterable<StorefrontCartItem> items,
    RestaurantModel restaurant,
  ) {
    final subtotal = items.fold<int>(
      0,
      (sum, line) => sum + (line.totalPrice * 100).round(),
    );
    final rate = restaurant.taxRate;
    final taxable =
        restaurant.billingType.trim().toLowerCase() != 'non-gst' &&
        rate.isFinite &&
        rate > 0;
    return TableQrBill._(
      subtotal,
      taxable ? (subtotal * rate / 100).round() : 0,
    );
  }

  double get subtotal => subtotalMinor / 100;
  double get tax => taxMinor / 100;
  double get total => (subtotalMinor + taxMinor) / 100;
}
