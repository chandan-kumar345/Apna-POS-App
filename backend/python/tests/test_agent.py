import unittest

from chotu_agent.agent import plan


class AgentPolicyTests(unittest.TestCase):
    def command(self, intent, **extra):
        return {"intent": intent, "confidence": 0.98, "table_number": "T-5", **extra}

    def test_complete_order_plans_missing_steps_in_order(self):
        output = plan(self.command("COMPLETE_ORDER", payment_confirmed=True, payment_method="cash"), {"cartCount": 2})
        self.assertEqual(output["actions"], ["send_kot", "generate_bill", "settle_cash"])

    def test_settlement_reuses_valid_kitchen_and_bill(self):
        output = plan(self.command("COMPLETE_ORDER", payment_confirmed=True, payment_method="cash"), {
            "cartCount": 2, "kitchenCurrent": True, "billCurrent": True,
        })
        self.assertEqual(output["actions"], ["settle_cash"])

    def test_cash_confirmation_is_required(self):
        output = plan(self.command("COMPLETE_ORDER"), {"cartCount": 1})
        self.assertEqual(output["status"], "needs_confirmation")
        self.assertEqual(output["actions"], [])

    def test_digital_payment_is_not_marked_paid(self):
        output = plan(self.command("COMPLETE_ORDER", payment_method="upi", payment_confirmed=True), {"cartCount": 1})
        self.assertEqual(output["status"], "unsupported")
        self.assertEqual(output["actions"], [])

    def test_missing_table_preserves_pending_instruction(self):
        output = plan(self.command("ADD_ITEM", table_number=None), {})
        self.assertEqual(output["pending"], "table")
        self.assertEqual(output["actions"], [])

    def test_ambiguity_and_low_confidence_never_mutate(self):
        for fields in [{"ambiguity": True, "question": "Which size?"}, {"confidence": 0.6}, {"confidence": float("nan")}]:
            with self.subTest(fields=fields):
                self.assertEqual(plan(self.command("ADD_ITEM", **fields), {})["actions"], [])

    def test_bad_item_in_multi_item_order_prevents_partial_execution(self):
        output = plan(self.command("ADD_ITEM", items=[
            {"product_id": "valid", "quantity": 1}, {"product_id": None, "matched": False},
        ]), {})
        self.assertEqual(output["actions"], [])

    def test_invalid_quantities_are_rejected(self):
        for quantity in [-1, 0, 100, 1.5, True, "2"]:
            with self.subTest(quantity=quantity):
                output = plan(self.command("ADD_ITEM", items=[{"product_id": "p", "quantity": quantity}]), {})
                self.assertEqual(output["actions"], [])

    def test_empty_cart_cannot_generate_fake_order(self):
        for intent in ["SEND_KOT", "GENERATE_BILL", "COMPLETE_ORDER"]:
            self.assertEqual(plan(self.command(intent), {"cartCount": 0})["actions"], [])

    def test_clear_requires_confirmation_and_cannot_cancel_kitchen(self):
        self.assertEqual(plan(self.command("CLEAR_CART"), {})["pending"], "clear")
        self.assertEqual(plan(self.command("CLEAR_CART", confirmed=True), {})["actions"], ["clear_draft"])
        self.assertEqual(plan(self.command("CLEAR_CART", confirmed=True), {"hasKitchenOrder": True})["actions"], [])

    def test_modifiers_are_explicitly_deferred(self):
        output = plan(self.command("ADD_ITEM", items=[{"product_id": "p", "quantity": 1, "modifiers": ["no onion"]}]), {})
        self.assertEqual(output["status"], "unsupported")

    def test_completed_order_is_not_settled_again(self):
        output = plan(self.command("COMPLETE_ORDER", payment_confirmed=True), {"cartCount": 0, "orderCompleted": True})
        self.assertEqual(output["actions"], ["view_order"])


if __name__ == "__main__":
    unittest.main()
