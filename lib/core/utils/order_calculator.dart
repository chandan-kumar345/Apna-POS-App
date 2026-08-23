import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

/// Centralized result object holding every calculated component of an order.
class OrderCalculationResult {
  final double subtotal;          // Sum of (effectivePrice * quantity)
  final double originalSubtotal;  // Sum of (original price * quantity)
  final double itemDiscounts;     // originalSubtotal - subtotal
  final double orderDiscount;     // Applied coupon + manual discount
  final double totalDiscount;     // itemDiscounts + orderDiscount
  final double taxableAmount;     // (subtotal - orderDiscount).clamp(0.0, double.infinity)
  final double taxAmount;         // GST calculated on taxable base proportional to each item's GST
  final double deliveryCharge;    // Delivery charge (if any)
  final double tipAmount;         // Tip amount
  final double roundOff;          // Optional roundoff difference
  final double totalPayableAmount;// (taxableAmount + taxAmount + deliveryCharge + tipAmount + roundOff).clamp(0.0, double.infinity)

  const OrderCalculationResult({
    required this.subtotal,
    required this.originalSubtotal,
    required this.itemDiscounts,
    required this.orderDiscount,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.taxAmount,
    this.deliveryCharge = 0.0,
    required this.tipAmount,
    this.roundOff = 0.0,
    required this.totalPayableAmount,
  });

  @override
  String toString() {
    return 'OrderCalculationResult(subtotal: $subtotal, orderDiscount: $orderDiscount, taxableAmount: $taxableAmount, taxAmount: $taxAmount, tipAmount: $tipAmount, deliveryCharge: $deliveryCharge, roundOff: $roundOff, totalPayableAmount: $totalPayableAmount)';
  }
}

/// Centralized single total calculation engine ensuring 100% mathematical consistency
/// across POS Cart, Payment Checkout, Database, API, and Invoices.
class OrderCalculator {
  static OrderCalculationResult calculate({
    required List<CartItemModel> items,
    double defaultTaxRate = 5.0,
    String? appliedCoupon,
    double discountInputValue = 0.0,
    String discountMode = 'percent', // 'percent' or 'flat'
    String? selectedDiscountProductType,
    double manualDiscountOverride = 0.0,
    double tipAmount = 0.0,
    double deliveryCharge = 0.0,
    bool isRounded = false,
  }) {
    if (items.isEmpty) {
      return const OrderCalculationResult(
        subtotal: 0.0,
        originalSubtotal: 0.0,
        itemDiscounts: 0.0,
        orderDiscount: 0.0,
        totalDiscount: 0.0,
        taxableAmount: 0.0,
        taxAmount: 0.0,
        deliveryCharge: 0.0,
        tipAmount: 0.0,
        roundOff: 0.0,
        totalPayableAmount: 0.0,
      );
    }

    // 1. Calculate Gross Subtotal and Item-level Discounts
    double grossSubtotal = 0.0;
    double originalGrossSubtotal = 0.0;
    for (final cartItem in items) {
      grossSubtotal += cartItem.totalPrice;
      originalGrossSubtotal += cartItem.originalTotalPrice;
    }
    final double itemDiscounts = (originalGrossSubtotal - grossSubtotal).clamp(0.0, double.infinity);

    // 2. Calculate Order-level / Extra Discount
    double orderDiscount = 0.0;
    if (manualDiscountOverride > 0) {
      orderDiscount = manualDiscountOverride;
    } else {
      final coupon = (appliedCoupon ?? '').trim().toUpperCase();
      if (coupon.isNotEmpty) {
        if (coupon == 'SAVE50') {
          orderDiscount = grossSubtotal * 0.50;
        } else if (coupon == 'FLAT100') {
          orderDiscount = 100.0;
        } else if (coupon == 'WELCOME10') {
          orderDiscount = grossSubtotal * 0.10;
        } else {
          orderDiscount = 50.0;
        }
      } else if (discountInputValue > 0) {
        if (selectedDiscountProductType == null ||
            selectedDiscountProductType == 'Select Product Type' ||
            selectedDiscountProductType == 'All Products') {
          if (discountMode == 'percent') {
            orderDiscount = grossSubtotal * (discountInputValue / 100.0);
          } else {
            orderDiscount = discountInputValue;
          }
        } else {
          double eligibleSubtotal = 0.0;
          final target = selectedDiscountProductType.toLowerCase();
          for (final cItem in items) {
            final itemType = cItem.item.itemType.toLowerCase();
            final category = cItem.item.category.toLowerCase();
            if (itemType == target || category == target || (target == 'food' && itemType != 'beverage')) {
              eligibleSubtotal += cItem.totalPrice;
            }
          }
          if (discountMode == 'percent') {
            orderDiscount = eligibleSubtotal * (discountInputValue / 100.0);
          } else {
            orderDiscount = discountInputValue.clamp(0.0, eligibleSubtotal);
          }
        }
      }
    }
    orderDiscount = orderDiscount.clamp(0.0, grossSubtotal);
    final double totalDiscount = itemDiscounts + orderDiscount;

    // 3. Calculate Taxable Amount (Subtotal - Order Discount)
    final double taxableAmount = (grossSubtotal - orderDiscount).clamp(0.0, double.infinity);

    // 4. Calculate Tax/GST on the Discounted Taxable Base
    final double discountRatio = grossSubtotal > 0
        ? (1.0 - (orderDiscount / grossSubtotal)).clamp(0.0, 1.0)
        : 1.0;
    double taxAmount = 0.0;
    for (final cartItem in items) {
      final itemTaxable = cartItem.totalPrice * discountRatio;
      final itemGst = cartItem.item.gstPercent ?? defaultTaxRate;
      taxAmount += itemTaxable * (itemGst / 100.0);
    }

    // 5. Clean Tip & Delivery Charges
    final double cleanTip = tipAmount.clamp(0.0, double.infinity);
    final double cleanDelivery = deliveryCharge.clamp(0.0, double.infinity);

    // 6. Net Payable Amount Calculation
    final double unroundedTotal = (taxableAmount + taxAmount + cleanDelivery + cleanTip).clamp(0.0, double.infinity);
    double roundOff = 0.0;
    double finalTotal = unroundedTotal;
    if (isRounded) {
      finalTotal = unroundedTotal.roundToDouble();
      roundOff = finalTotal - unroundedTotal;
    }

    if (kDebugMode) {
      debugPrint('[OrderCalculator] Subtotal: ₹$grossSubtotal | Disc: ₹$orderDiscount | Taxable: ₹$taxableAmount | GST: ₹$taxAmount | Tip: ₹$cleanTip | Total: ₹$finalTotal');
    }

    return OrderCalculationResult(
      subtotal: grossSubtotal,
      originalSubtotal: originalGrossSubtotal,
      itemDiscounts: itemDiscounts,
      orderDiscount: orderDiscount,
      totalDiscount: totalDiscount,
      taxableAmount: taxableAmount,
      taxAmount: taxAmount,
      deliveryCharge: cleanDelivery,
      tipAmount: cleanTip,
      roundOff: roundOff,
      totalPayableAmount: finalTotal,
    );
  }
}
