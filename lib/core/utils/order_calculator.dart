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
  final double taxAmount;         // GST calculated dynamically proportional to each item's GST
  final double taxableSubtotal;   // Subtotal of items subject to GST (> 0%)
  final double nonTaxableSubtotal;// Subtotal of items with No GST (0% or exempt)
  final Map<double, double> taxBreakupByRate;      // rate -> tax amount (e.g. 5.0 -> 14.50)
  final Map<double, double> taxableAmountByRate;  // rate -> taxable base (e.g. 5.0 -> 290.00)
  final double cgst;              // Central GST (taxAmount / 2)
  final double sgst;              // State GST (taxAmount / 2)
  final double igst;              // Integrated GST (0.0)
  final double deliveryCharge;    // Delivery charge (if any)
  final double tipAmount;         // Tip amount
  final double roundOff;          // Optional roundoff difference
  final double totalPayableAmount;// (taxableAmount + taxAmount + deliveryCharge + tipAmount + roundOff).clamp(0.0, double.infinity)

  OrderCalculationResult({
    required this.subtotal,
    required this.originalSubtotal,
    required this.itemDiscounts,
    required this.orderDiscount,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.taxAmount,
    this.taxableSubtotal = 0.0,
    this.nonTaxableSubtotal = 0.0,
    this.taxBreakupByRate = const {},
    this.taxableAmountByRate = const {},
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.deliveryCharge = 0.0,
    required this.tipAmount,
    this.roundOff = 0.0,
    required this.totalPayableAmount,
  });

  @override
  String toString() {
    return 'OrderCalculationResult(subtotal: $subtotal, orderDiscount: $orderDiscount, taxableAmount: $taxableAmount, taxAmount: $taxAmount, taxableSubtotal: $taxableSubtotal, nonTaxableSubtotal: $nonTaxableSubtotal, tipAmount: $tipAmount, deliveryCharge: $deliveryCharge, roundOff: $roundOff, totalPayableAmount: $totalPayableAmount)';
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
      return OrderCalculationResult(
        subtotal: 0.0,
        originalSubtotal: 0.0,
        itemDiscounts: 0.0,
        orderDiscount: 0.0,
        totalDiscount: 0.0,
        taxableAmount: 0.0,
        taxAmount: 0.0,
        taxableSubtotal: 0.0,
        nonTaxableSubtotal: 0.0,
        taxBreakupByRate: const {},
        taxableAmountByRate: const {},
        cgst: 0.0,
        sgst: 0.0,
        igst: 0.0,
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

    // 4. Calculate Tax/GST Dynamically per Product
    // Each product's tax is calculated based on its specific gstPercent:
    // - If item.gstPercent == 0.0: No GST (0%)
    // - If item.gstPercent > 0: Specific GST rate
    // - If item.gstPercent == null: Inherit defaultTaxRate (or 0.0 if defaultTaxRate == 0)
    final double discountRatio = grossSubtotal > 0
        ? (1.0 - (orderDiscount / grossSubtotal)).clamp(0.0, 1.0)
        : 1.0;
    double taxAmount = 0.0;
    double taxableSubtotal = 0.0;
    double nonTaxableSubtotal = 0.0;
    final Map<double, double> taxBreakupByRate = {};
    final Map<double, double> taxableAmountByRate = {};

    for (final cartItem in items) {
      final itemTaxableBase = cartItem.totalPrice * discountRatio;
      double itemGstRate = 0.0;

      if (cartItem.item.gstPercent != null) {
        itemGstRate = cartItem.item.gstPercent!;
      } else {
        itemGstRate = defaultTaxRate;
      }

      if (itemGstRate < 0.0) {
        itemGstRate = 0.0;
      }

      final double itemTax = itemTaxableBase * (itemGstRate / 100.0);
      taxAmount += itemTax;

      if (itemGstRate > 0.0) {
        taxableSubtotal += itemTaxableBase;
        taxBreakupByRate[itemGstRate] = (taxBreakupByRate[itemGstRate] ?? 0.0) + itemTax;
        taxableAmountByRate[itemGstRate] = (taxableAmountByRate[itemGstRate] ?? 0.0) + itemTaxableBase;
      } else {
        nonTaxableSubtotal += itemTaxableBase;
        taxBreakupByRate[0.0] = 0.0;
        taxableAmountByRate[0.0] = (taxableAmountByRate[0.0] ?? 0.0) + itemTaxableBase;
      }
    }

    final double cgst = taxAmount / 2.0;
    final double sgst = taxAmount / 2.0;
    const double igst = 0.0;

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
      debugPrint('[OrderCalculator] Subtotal: ₹$grossSubtotal | Disc: ₹$orderDiscount | TaxableBase: ₹$taxableAmount | GST: ₹$taxAmount (Taxable: ₹$taxableSubtotal, Non-Taxable: ₹$nonTaxableSubtotal) | Tip: ₹$cleanTip | Total: ₹$finalTotal');
    }

    return OrderCalculationResult(
      subtotal: grossSubtotal,
      originalSubtotal: originalGrossSubtotal,
      itemDiscounts: itemDiscounts,
      orderDiscount: orderDiscount,
      totalDiscount: totalDiscount,
      taxableAmount: taxableAmount,
      taxAmount: taxAmount,
      taxableSubtotal: taxableSubtotal,
      nonTaxableSubtotal: nonTaxableSubtotal,
      taxBreakupByRate: taxBreakupByRate,
      taxableAmountByRate: taxableAmountByRate,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      deliveryCharge: cleanDelivery,
      tipAmount: cleanTip,
      roundOff: roundOff,
      totalPayableAmount: finalTotal,
    );
  }
}
