import 'package:flutter/material.dart';
import '../screens/coupon_form_screen.dart';
import '../../../core/models/coupon_model.dart';

export '../screens/coupon_form_screen.dart';

class CouponFormDialog extends StatelessWidget {
  final CouponModel? existingCoupon;
  final VoidCallback onSaved;

  const CouponFormDialog({
    super.key,
    this.existingCoupon,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return CouponFormScreen(
      existingCoupon: existingCoupon,
      onSaved: onSaved,
    );
  }
}
