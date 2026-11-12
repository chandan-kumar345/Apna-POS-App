"""Plan an order turn. The Node host owns all database and payment effects.

Run with --health or pass one {"command": ..., "context": ...} JSON object on
stdin. Only the fixed action names returned here may be executed by the host.
"""

import json
import math
import sys

MAX_QUANTITY = 99
MIN_CONFIDENCE = 0.85


def result(status, message, actions=None, pending=None):
    return {
        "status": status,
        "message": message,
        "actions": actions or [],
        "pending": pending,
    }


def valid_quantity(value):
    return type(value) is int and 1 <= value <= MAX_QUANTITY


def confident(value):
    return (
        type(value) in (int, float)
        and math.isfinite(value)
        and MIN_CONFIDENCE <= value <= 1
    )


def plan(command, context):
    if not isinstance(command, dict) or not isinstance(context, dict):
        raise ValueError("command and context must be objects")
    intent = command.get("intent", "UNKNOWN")
    if command.get("ambiguity"):
        return result(
            "needs_clarification",
            command.get("question") or "Please repeat the full order with the exact menu item.",
        )
    if not confident(command.get("confidence", 0)):
        return result("needs_clarification", "Command clear nahi hai. Please repeat the full instruction.")
    if intent == "CHAT":
        return result("answered", command.get("chotu_response") or "Boliye, kaunsa order lagana hai?")
    supported = {
        "ADD_ITEM", "REMOVE_ITEM", "UPDATE_QUANTITY", "SEND_KOT",
        "GENERATE_BILL", "COMPLETE_ORDER", "CLEAR_CART", "SWITCH_TABLE",
        "VIEW_TABLE_ORDER",
    }
    if intent not in supported or command.get("order_type", "dineIn") != "dineIn":
        return result("unsupported", "Is action ke liye normal POS use kijiye. Chotu agent abhi dine-in orders handle karta hai.")
    if not command.get("table_number"):
        return result("needs_clarification", "Kaunsi table par order lagana hai?", pending="table")

    if intent in {"VIEW_TABLE_ORDER", "SWITCH_TABLE"}:
        return result("completed", "Table ka current order ready hai.", ["view_order"])

    if intent in {"ADD_ITEM", "REMOVE_ITEM", "UPDATE_QUANTITY"}:
        items = command.get("items") or ([command["item"]] if command.get("item") else [])
        if not isinstance(items, list) or not items:
            return result("needs_clarification", "Item samajh nahi aaya. Please repeat the full order.")
        if intent != "ADD_ITEM" and len(items) != 1:
            return result("needs_clarification", "Ek item ki quantity ya removal ek baar mein batayiye.")
        for item in items:
            if not isinstance(item, dict) or not item.get("product_id") or item.get("matched") is False:
                return result("needs_clarification", "Menu item nahi mila. Please repeat the full order using menu names.")
            quantity = command.get("quantity", item.get("quantity", 1)) if intent != "ADD_ITEM" else item.get("quantity", 1)
            if not valid_quantity(quantity):
                return result("needs_clarification", "Quantity 1 se 99 tak whole number honi chahiye.")
            if item.get("modifiers") or item.get("variant_name") or item.get("variantName"):
                return result("unsupported", "Variant ya special instructions normal POS par confirm kijiye.")
        action = {"ADD_ITEM": "add_items", "REMOVE_ITEM": "remove_item", "UPDATE_QUANTITY": "set_quantity"}[intent]
        return result("completed", "Order draft update ho gaya.", [action])

    if intent == "CLEAR_CART":
        if context.get("hasKitchenOrder") or context.get("hasRunningOrder"):
            return result("unsupported", "Issued order/invoice ko normal POS cancellation se handle kijiye.")
        if command.get("confirmed") is not True:
            return result("needs_confirmation", "Is table ka draft clear karna hai? Boliye: confirm clear cart.", pending="clear")
        return result("completed", "Draft clear ho gaya.", ["clear_draft"])

    if context.get("orderCompleted") and not context.get("cartCount"):
        return result("completed", "Order pehle hi complete ho chuka hai.", ["view_order"])
    if not context.get("cartCount"):
        return result("needs_clarification", "Cart khali hai. Pehle menu items add kijiye.")

    if intent == "SEND_KOT":
        actions = [] if context.get("kitchenCurrent") else ["send_kot"]
        return result("completed", "KOT record ready hai; physical printing POS printer par depend karti hai.", actions)
    if intent == "GENERATE_BILL":
        actions = [] if context.get("billCurrent") else ["generate_bill"]
        return result("completed", "Unpaid bill ready hai. Payment abhi pending hai.", actions)
    if intent == "COMPLETE_ORDER":
        if command.get("payment_method", "cash").lower() != "cash":
            return result("unsupported", "UPI/card payment existing POS payment flow mein verify kijiye. Order unpaid rahega.")
        if command.get("payment_confirmed") is not True:
            return result("needs_confirmation", "Cash receive hone ke baad boliye: cash received, settle order.", pending="cash")
        actions = []
        if not context.get("kitchenCurrent"):
            actions.append("send_kot")
        if not context.get("billCurrent"):
            actions.append("generate_bill")
        actions.append("settle_cash")
        return result("completed", "Cash settlement record ho gaya. Order complete hai.", actions)
    return result("unsupported", "Please use the normal POS for this action.")


def main():
    if sys.version_info < (3, 11):
        raise ValueError("Python 3.11 or newer is required")
    if hasattr(sys.stdin, "reconfigure"):
        sys.stdin.reconfigure(encoding="utf-8")
        sys.stdout.reconfigure(encoding="utf-8")
    if sys.argv[1:] == ["--health"]:
        print(json.dumps({"available": True, "pythonVersion": sys.version.split()[0]}))
        return
    raw = sys.stdin.read(262145)
    if len(raw) > 262144:
        raise ValueError("Planner input exceeds limit")
    request = json.loads(raw)
    output = plan(request.get("command"), request.get("context", {}))
    print(json.dumps(output, ensure_ascii=False, allow_nan=False))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, TypeError, AttributeError) as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(2)
