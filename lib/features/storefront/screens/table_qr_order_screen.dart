import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/menu_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/customer_storefront_flow_models.dart';
import '../models/storefront_model.dart';
import '../models/table_qr_bill.dart';
import '../services/customer_storefront_api_service.dart';
import '../services/table_qr_phone_auth.dart';
import '../widgets/storefront_product_detail_sheet.dart';
import 'customer_my_orders_screen.dart';
import '../../pos/widgets/pos_product_media_box.dart';

enum _Page { home, menu, cart, login }

class TableQrOrderScreen extends StatefulWidget {
  final StorefrontData data;
  final String tableCode;
  final bool preview;
  final Future<void> Function() onRefresh;
  final Widget Function(String? logo, String name, double size) avatar;

  const TableQrOrderScreen({
    super.key,
    required this.data,
    required this.tableCode,
    required this.onRefresh,
    required this.avatar,
    this.preview = false,
  });

  @override
  State<TableQrOrderScreen> createState() => _TableQrOrderScreenState();
}

class _TableQrOrderScreenState extends State<TableQrOrderScreen> {
  static const _blue = Color(0xFF064CF5);
  static const _ink = Color(0xFF101625);
  static const _muted = Color(0xFF526075);
  static const _border = Color(0xFFD7DFEB);
  static const _tint = Color(0xFFE6EEFF);
  final _search = TextEditingController();
  final _note = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _auth = TableQrPhoneAuth();
  final _cart = <StorefrontCartItem>[];
  _Page _page = _Page.home;
  _Page _loginBack = _Page.home;
  String _category = '';
  bool _vegOnly = false;
  bool _favorite = false;
  bool _checkoutLogin = false;
  bool _authBusy = false;
  bool _submitting = false;
  bool _guestPromptOpen = false;
  int _lineSequence = 0;
  String? _error;
  String? _orderError;
  CustomerProfileModel? _customer;
  CustomerOrderTrackingModel? _receipt;
  ConfirmTablePhone? _verify;

  StorefrontData get _data => widget.data;
  bool get _valid =>
      _data.tableInfo?.isValid == true &&
      _data.tableInfo!.tableCode.trim() == widget.tableCode.trim();
  bool get _canOrder => _valid && _data.isOnline && !_submitting;
  bool get _busy => _submitting || _authBusy;
  int get _count => _cart.fold(0, (sum, line) => sum + line.quantity);
  TableQrBill get _bill => TableQrBill.calculate(_cart, _data.restaurant);
  String get _favoriteKey => 'qr_favorite_${_data.restaurant.id}';
  String get _guestKey => 'qr_guest_${_data.restaurant.id}';
  String _money(double value) =>
      '${_data.restaurant.currencySymbol}${value.toStringAsFixed(value == value.truncateToDouble() ? 0 : 2)}';

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        final raw = prefs.getString(_guestKey);
        CustomerProfileModel? guest;
        if (raw != null) {
          final profile = CustomerProfileModel.fromJson(jsonDecode(raw));
          if (profile.name.trim().isNotEmpty &&
              RegExp(r'^[6-9][0-9]{9}$').hasMatch(profile.phone)) {
            guest = profile;
          }
        }
        setState(() {
          _favorite = prefs.getBool(_favoriteKey) ?? false;
          _customer = guest;
        });
      }
    } catch (_) {}
    try {
      final history = await CustomerStorefrontApiService().orderHistory(
        _data.restaurant.id,
      );
      if (mounted && history.isNotEmpty) {
        setState(() => _receipt = history.first);
      }
    } catch (_) {}
    if (widget.preview || !mounted) return;
    try {
      final customer = await _auth.restore();
      if (mounted &&
          _page != _Page.login &&
          _customer == null &&
          customer != null) {
        setState(() => _customer = customer);
      }
    } catch (_) {
      // Firebase availability never blocks a table guest from ordering.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _go(_Page page) {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (page == _Page.login && _page != _Page.login) {
        _loginBack = _page;
        _checkoutLogin = false;
      }
      _page = page;
      _error = null;
    });
  }

  void _back() {
    if (_busy) return;
    _go(switch (_page) {
      _Page.login => _loginBack,
      _Page.cart => _Page.menu,
      _ => _Page.home,
    });
  }

  bool _available(MenuItemModel item) => item.isAvailable && !item.isOutOfStock;

  StorefrontCartItem? _plainLine(MenuItemModel item) {
    for (final line in _cart) {
      if (line.item.id == item.id &&
          line.selectedSize == null &&
          line.selectedAddons.isEmpty &&
          line.instructions.isEmpty) {
        return line;
      }
    }
    return null;
  }

  void _quantity(StorefrontCartItem line, int delta) {
    if (_busy || (delta > 0 && (!_canOrder || !_available(line.item)))) return;
    setState(() {
      line.quantity += delta;
      if (line.quantity <= 0) _cart.remove(line);
      _orderError = null;
    });
  }

  void _add(StorefrontCartItem choice) {
    if (!_canOrder || !_available(choice.item)) return;
    final addons = choice.selectedAddons
        .where((a) => a.isSelected)
        .map((a) => a.id)
        .toSet();
    setState(() {
      for (final line in _cart) {
        final current = line.selectedAddons
            .where((a) => a.isSelected)
            .map((a) => a.id)
            .toSet();
        if (line.item.id == choice.item.id &&
            line.selectedSize?.id == choice.selectedSize?.id &&
            line.instructions.trim() == choice.instructions.trim() &&
            current.length == addons.length &&
            current.containsAll(addons)) {
          line.quantity += choice.quantity;
          _orderError = null;
          return;
        }
      }
      _cart.add(
        StorefrontCartItem(
          uid: 'qr_${_lineSequence++}',
          item: choice.item,
          selectedSize: choice.selectedSize,
          selectedAddons: choice.selectedAddons,
          instructions: choice.instructions,
          quantity: choice.quantity,
        ),
      );
      _orderError = null;
    });
  }

  void _choose(MenuItemModel item) {
    if (!_canOrder || !_available(item)) return;
    if (item.variants.isEmpty) {
      _add(StorefrontCartItem(uid: '', item: item));
      return;
    }
    _showDetails(item);
  }

  void _showDetails(MenuItemModel item) {
    if (_busy) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StorefrontProductDetailSheet(
        item: item,
        themeColor: _blue,
        isOnline: _canOrder,
        availableAddons: _data.addOns,
        onAddToCart: (choice, {bool openCartImmediately = false}) {
          _add(choice);
          if (openCartImmediately) _go(_Page.cart);
        },
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    setState(() => _favorite = !_favorite);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_favoriteKey, _favorite);
  }

  Future<void> _startCheckout() async {
    if (!_canOrder || _cart.isEmpty || _busy) return;
    if (widget.preview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preview only. Scan the table QR to order.'),
        ),
      );
      return;
    }
    if (_customer != null) {
      await _placeOrder(_customer);
      return;
    }
    _go(_Page.login);
    setState(() => _checkoutLogin = true);
  }

  Future<void> _finishLogin(CustomerProfileModel? customer) async {
    if (_busy || _guestPromptOpen) return;
    customer ??= _customer;
    if (customer == null) {
      _guestPromptOpen = true;
      try {
        customer = await _guestDetails();
      } finally {
        _guestPromptOpen = false;
      }
      if (!mounted || customer == null) return;
      setState(() => _customer = customer);
    }
    final checkout = _checkoutLogin;
    final back = _loginBack;
    _go(back);
    if (checkout) await _placeOrder(customer);
  }

  Future<CustomerProfileModel?> _guestDetails() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showModalBottomSheet<CustomerProfileModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Theme(
        data: ThemeData.light(
          useMaterial3: true,
        ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _blue)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your details',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'So the restaurant can identify and contact you about your order.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('qr-guest-name'),
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 80,
                        decoration: _input('Your name'),
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: const ValueKey('qr-guest-phone'),
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _input('10-digit mobile number'),
                        validator: (value) =>
                            RegExp(r'^[6-9][0-9]{9}$').hasMatch(value ?? '')
                            ? null
                            : 'Enter a valid mobile number',
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'We’ll remember these details on this device. No OTP is needed for guest orders.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (!form.currentState!.validate()) return;
                        Navigator.pop(
                          ctx,
                          CustomerProfileModel(
                            id: 'guest',
                            name: name.text.trim(),
                            phone: phone.text,
                          ),
                        );
                      },
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_guestKey, jsonEncode(result.toJson()));
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    phone.dispose();
    return result;
  }

  Future<void> _placeOrder(CustomerProfileModel? customer) async {
    if (!_canOrder || _cart.isEmpty || widget.preview) return;
    final bill = _bill;
    setState(() {
      _submitting = true;
      _orderError = null;
    });
    CustomerOrderTrackingModel? order;
    try {
      order = await CustomerStorefrontApiService().placeCustomerOrder(
        restaurant: _data.restaurant,
        customer:
            customer ??
            const CustomerProfileModel(id: 'guest', phone: '', name: 'Guest'),
        selectedAddress: CustomerAddressModel(
          id: widget.tableCode,
          label: 'Dining table',
          fullAddress: 'Table ${widget.tableCode}',
        ),
        cartItems: List.unmodifiable(_cart),
        paymentMethod: 'Pay at Counter / Table',
        subtotal: bill.subtotal,
        deliveryFee: 0,
        tax: bill.tax,
        grandTotal: bill.total,
        deliveryInstructions: _note.text.trim(),
        tableNumber: widget.tableCode,
        orderType: OrderType.dineIn,
      );
    } catch (_) {
      // Preserve the cart and let the same order request be retried.
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (order == null) {
        _orderError =
            'The restaurant hasn’t confirmed this order. Your cart is saved here. Please try again.';
      } else {
        _receipt = order;
        _cart.clear();
        _note.clear();
        _page = _Page.menu;
      }
    });
    if (order != null) _track(order);
  }

  void _track(CustomerOrderTrackingModel order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerMyOrdersScreen(
          order: order,
          restaurant: _data.restaurant,
          tableCode: widget.tableCode,
          themeColor: _blue,
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(_phone.text)) {
      setState(() => _error = 'Enter a valid 10-digit Indian mobile number.');
      return;
    }
    await _authorize(() async {
      final challenge = await _auth.send('+91${_phone.text}');
      if (!mounted) return;
      setState(() {
        _verify = challenge.confirm;
        if (challenge.verified != null) _customer = challenge.verified;
      });
    });
    if (mounted && _customer != null && _checkoutLogin) {
      await _finishLogin(_customer);
    }
  }

  Future<void> _verifyCode() async {
    if (_busy || _verify == null) return;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(_code.text)) {
      setState(() => _error = 'Enter the six-digit code from your SMS.');
      return;
    }
    await _authorize(() async {
      final customer = await _verify!(_code.text);
      if (!mounted) return;
      setState(() {
        _customer = customer;
        _verify = null;
        _code.clear();
      });
    });
    if (mounted && _customer != null && _checkoutLogin) {
      await _finishLogin(_customer);
    }
  }

  Future<void> _authorize(Future<void> Function() action) async {
    setState(() {
      _authBusy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error.code) {
            'invalid-verification-code' =>
              'That code is incorrect. Please try again.',
            'session-expired' =>
              'That code expired. Use Change number to request a new one.',
            'too-many-requests' =>
              'Too many attempts. Try again later or continue as a guest.',
            _ =>
              'SMS verification is unavailable right now. You can continue as a guest.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'SMS verification is unavailable right now. You can continue as a guest.',
        );
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _page == _Page.home && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Theme(
        data: theme.copyWith(
          colorScheme: const ColorScheme.light(primary: _blue, onSurface: _ink),
          textTheme: theme.textTheme.apply(bodyColor: _ink, displayColor: _ink),
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: const Color(0xFFEDF3FD),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 510),
                child: ColoredBox(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Expanded(
                        child: switch (_page) {
                          _Page.home => _home(),
                          _Page.menu => _menu(),
                          _Page.cart => _cartPage(),
                          _Page.login => _login(),
                        },
                      ),
                      if (_page == _Page.menu && _count > 0) _cartBar(),
                      if (_page == _Page.home || _page == _Page.menu) _nav(),
                      if (_page == _Page.cart && _cart.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                          child: _primary(
                            _submitting
                                ? 'Placing order…'
                                : 'Place order • ${_money(_bill.total)}',
                            _canOrder ? _startCheckout : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 01 / Table home
  Widget _home() {
    final restaurant = _data.restaurant;
    final popular = _data.menuItems.where(_available).take(10).toList();
    final banners = _data.banners.where(
      (banner) => banner.imageUrl.trim().isNotEmpty,
    );
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.avatar(restaurant.logoUrl, restaurant.name, 66),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title(restaurant.name, 23),
                    Text(
                      restaurant.cuisineType.trim().isEmpty
                          ? 'Restaurant'
                          : restaurant.cuisineType,
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _data.isOnline
                            ? const Color(0xFFD9F7E5)
                            : const Color(0xFFFFEAE8),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        _data.isOnline ? 'Open' : 'Closed',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _data.isOnline
                              ? const Color(0xFF006929)
                              : const Color(0xFF982923),
                        ),
                      ),
                    ),
                    if (restaurant.openingTime.isNotEmpty &&
                        restaurant.closingTime.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${restaurant.openingTime} – ${restaurant.closingTime}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: _favorite ? 'Remove favourite' : 'Save favourite',
                onPressed: _toggleFavorite,
                icon: Icon(
                  _favorite ? Icons.favorite : Icons.favorite_border,
                  color: _favorite ? Colors.red : _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 151,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (banners.isNotEmpty)
                    _image(banners.first.imageUrl)
                  else if (popular.isNotEmpty &&
                      _productImage(popular.first).isNotEmpty)
                    _image(_productImage(popular.first))
                  else
                    Image.asset(
                      'assets/images/restaurant_cooking_pan.jpg',
                      fit: BoxFit.cover,
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xE51D140D), Color(0x001D140D)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Freshly made.\nMade for you.',
                          style: TextStyle(
                            fontSize: 23,
                            height: 1.1,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _title(
            _valid
                ? 'Welcome to Table ${widget.tableCode}'
                : 'Check your table QR',
            24,
          ),
          const SizedBox(height: 4),
          Text(
            _valid
                ? 'Dine-in • Order from your table'
                : 'Scan the QR code on your table or ask a member of staff.',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          _primary(
            'Explore menu',
            () => _go(_Page.menu),
            icon: Icons.restaurant,
          ),
          if (popular.isNotEmpty) ...[
            const SizedBox(height: 20),
            _title('Popular picks', 20),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final item in popular)
                    SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: _popularCard(item),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Center(
            child: Text.rich(
              TextSpan(
                text: 'Powered by ',
                style: TextStyle(color: _muted, fontSize: 12),
                children: [
                  TextSpan(
                    text: 'Apna POS',
                    style: TextStyle(color: _blue, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _popularCard(MenuItemModel item) => _card(
    onTap: () => _showDetails(item),
    padding: const EdgeInsets.all(5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(aspectRatio: 1.65, child: _photo(item, 10)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 7, 4, 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40, child: _itemTitle(item, maxLines: 2)),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  _title(_money(item.effectivePrice), 16),
                  _addControl(item),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // 02 / Menu catalog
  Widget _menu() {
    final categories = _data.menuItems
        .map((item) => item.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    final query = _search.text.trim().toLowerCase();
    final results = _data.menuItems
        .where(
          (item) =>
              (_category.isEmpty || item.category.trim() == _category) &&
              (!_vegOnly || item.isVeg) &&
              (query.isEmpty ||
                  '${item.name} ${item.category} ${item.description}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    return Column(
      children: [
        _header('Our menu', trailing: _tableBadge()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: _ink, fontSize: 14),
            decoration:
                _input(
                  'Search pizzas, sides & drinks',
                  prefix: const Icon(
                    Icons.search_rounded,
                    size: 21,
                    color: _muted,
                  ),
                  filled: true,
                ).copyWith(
                  fillColor: const Color(0xFFF2F5FA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _blue, width: 1.5),
                  ),
                ),
          ),
        ),
        SizedBox(
          height: 53,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
            children: [
              for (final category in ['', ...categories])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: category.isEmpty
                        ? null
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: _image(
                                _productImage(
                                  _data.menuItems.firstWhere(
                                    (item) => item.category.trim() == category,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    label: Text(category.isEmpty ? 'All' : category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                    showCheckmark: false,
                    selectedColor: _blue,
                    labelStyle: TextStyle(
                      color: _category == category ? Colors.white : _ink,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color: _category == category ? _blue : _border,
                    ),
                    backgroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Veg only',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 7),
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: _vegOnly,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFD1D8E1),
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  onChanged: (value) => setState(() => _vegOnly = value),
                ),
              ),
            ],
          ),
        ),
        if (!_valid || !_data.isOnline)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _notice(
              !_valid
                  ? 'Scan a valid table QR to order.'
                  : 'The restaurant isn’t accepting orders right now.',
            ),
          ),
        if (!_valid)
          TextButton(
            onPressed: widget.onRefresh,
            child: const Text('Retry table check'),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 9),
          child: Row(
            children: [
              Expanded(
                child: _title(
                  _category.isEmpty
                      ? (categories.length == 1 ? categories.single : 'Menu')
                      : _category,
                  20,
                ),
              ),
              Text(
                '${results.length} ${results.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text('No matching items.'))
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _menuCard(results[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _menuCard(MenuItemModel item) => _card(
    onTap: () => _showDetails(item),
    padding: const EdgeInsets.all(8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 86, height: 91, child: _photo(item, 12)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _itemTitle(item, maxLines: 2),
              if (item.description.trim().isNotEmpty)
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.22,
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  _title(_money(item.effectivePrice), 16),
                  _addControl(item),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // 03 / Cart and pay at counter
  Widget _cartPage() => Column(
    children: [
      _header('Your cart'),
      Expanded(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            _notice(
              'Table ${widget.tableCode} • Dine-in',
              icon: Icons.table_restaurant_outlined,
            ),
            const SizedBox(height: 10),
            if (_orderError != null)
              _notice(_orderError!, icon: Icons.error_outline),
            if (_cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Your cart is empty.')),
              ),
            for (final line in _cart) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: _photo(line.item, 9),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _itemTitle(line.item, maxLines: 2),
                          if (line.selectedSize != null ||
                              line.selectedAddons.isNotEmpty ||
                              line.instructions.isNotEmpty)
                            Text(
                              [
                                if (line.selectedSize != null)
                                  line.selectedSize!.name,
                                ...line.selectedAddons
                                    .where((a) => a.isSelected)
                                    .map((a) => a.name),
                                if (line.instructions.isNotEmpty)
                                  line.instructions,
                              ].join(' • '),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 4),
                          _title(_money(line.totalPrice), 16),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _stepper(line),
                  ],
                ),
              ),
              const Divider(height: 1, color: _border),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : () => _go(_Page.menu),
                child: const Text('+ Add more items'),
              ),
            ),
            if (_cart.isNotEmpty) ...[
              TextField(
                controller: _note,
                enabled: !_busy,
                maxLength: 250,
                maxLines: 2,
                decoration: _input(
                  'Add cooking instructions\n(e.g., less spicy, extra cheese)',
                  prefix: const Icon(Icons.edit_outlined),
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 6),
              _title('Bill summary', 17),
              const SizedBox(height: 8),
              _amount('Subtotal', _bill.subtotal),
              _amount('Taxes', _bill.tax),
              const Divider(color: _border),
              _amount('Total', _bill.total, bold: true),
              const SizedBox(height: 18),
              _title('Payment method', 17),
              const SizedBox(height: 8),
              _card(
                padding: EdgeInsets.zero,
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(13),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.payments_outlined,
                      color: Color(0xFF087D46),
                    ),
                    title: const Text(
                      'Pay at counter',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Pay at counter'),
                              content: const Text(
                                'Pay the restaurant directly at the counter. No online payment will be taken.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Row(
                children: [
                  Icon(Icons.info_outline, color: _muted, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your order will be sent to the kitchen.',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );

  // 04 / Customer login, with guest checkout
  Widget _login() {
    final verifying = _verify != null;
    final restaurant = _data.restaurant;
    return Column(
      children: [
        _header(
          '',
          trailing: TextButton(
            onPressed: _busy ? null : () => _finishLogin(null),
            child: const Text('Skip'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 16),
            children: [
              Center(
                child: widget.avatar(restaurant.logoUrl, restaurant.name, 76),
              ),
              const SizedBox(height: 13),
              const Center(child: _PhoneIllustration()),
              const SizedBox(height: 16),
              Center(
                child: _title(
                  'Welcome to ${restaurant.name}',
                  23,
                  centered: true,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in with your mobile number to attach it to your order.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.4),
              ),
              const SizedBox(height: 21),
              if (_customer != null) ...[
                _notice(
                  '${_customer!.name} • ${_customer!.phone}',
                  icon: Icons.verified_user_outlined,
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _authorize(() async {
                          if (_customer?.id != 'guest') await _auth.signOut();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove(_guestKey);
                          if (mounted) setState(() => _customer = null);
                        }),
                  child: const Text('Sign out'),
                ),
              ] else ...[
                Text(
                  verifying ? 'Verification code' : 'Mobile number',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: ValueKey(verifying ? 'table-otp' : 'table-phone'),
                  controller: verifying ? _code : _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: [
                    verifying
                        ? AutofillHints.oneTimeCode
                        : AutofillHints.telephoneNumberNational,
                  ],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(verifying ? 6 : 10),
                  ],
                  onSubmitted: (_) => verifying ? _verifyCode() : _sendCode(),
                  decoration: _input(
                    verifying ? 'Enter six-digit code' : 'Enter mobile number',
                    prefix: verifying ? null : const _IndiaDialCode(),
                  ),
                ),
                const SizedBox(height: 14),
                _primary(
                  _authBusy
                      ? 'Please wait…'
                      : (verifying ? 'Verify code' : 'Send OTP'),
                  _busy || widget.preview
                      ? null
                      : (verifying ? _verifyCode : _sendCode),
                ),
                const SizedBox(height: 10),
                Text(
                  verifying
                      ? 'Enter the code sent to +91 ${_phone.text}.'
                      : 'We’ll send you a verification code by SMS.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                if (verifying)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _verify = null;
                            _code.clear();
                            _error = null;
                          }),
                    child: const Text('Change number'),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ],
              if (_receipt != null)
                TextButton(
                  onPressed: _busy ? null : () => _track(_receipt!),
                  child: const Text('Track latest order'),
                ),
              if (_customer == null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextButton(
                    onPressed: _busy ? null : () => _finishLogin(null),
                    child: const Text('Continue as guest'),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: _notice(
            'Your table: ${widget.tableCode}',
            icon: Icons.table_restaurant_outlined,
          ),
        ),
      ],
    );
  }

  Widget _header(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(7, 5, 15, 5),
    child: Row(
      children: [
        IconButton(
          style: IconButton.styleFrom(
            foregroundColor: _ink,
            backgroundColor: const Color(0xFFF2F5FA),
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _busy ? null : _back,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        const SizedBox(width: 5),
        Expanded(child: _title(title, 21)),
        ?trailing,
      ],
    ),
  );

  Widget _nav() {
    const pages = [_Page.home, _Page.menu, _Page.cart, _Page.login];
    const icons = [
      Icons.home_outlined,
      Icons.grid_view_rounded,
      Icons.shopping_cart_outlined,
      Icons.person_outline,
    ];
    const labels = ['Home', 'Menu', 'Cart', 'Account'];
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        child: Row(
          children: [
            for (var i = 0; i < pages.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: _busy ? null : () => _go(pages[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _page == pages[i] ? _tint : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      children: [
                        Badge(
                          isLabelVisible: pages[i] == _Page.cart && _count > 0,
                          label: Text('$_count'),
                          child: Icon(
                            icons[i],
                            size: 22,
                            color: _page == pages[i] ? _blue : _muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: _page == pages[i] ? _blue : _ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cartBar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 3, 12, 8),
    child: FilledButton(
      onPressed: () => _go(_Page.cart),
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_count ${_count == 1 ? 'item' : 'items'} • ${_money(_bill.subtotal)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Text(
            'View cart',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.arrow_forward, size: 17),
        ],
      ),
    ),
  );

  Widget _tableBadge() => _card(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.table_restaurant_outlined, color: _blue, size: 17),
        const SizedBox(width: 6),
        Text(
          _valid ? 'Table ${widget.tableCode}' : 'Invalid QR',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _addControl(MenuItemModel item) {
    final line = _plainLine(item);
    if (line != null) return _stepper(line);
    return OutlinedButton(
      onPressed: _canOrder && _available(item) ? () => _choose(item) : null,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _blue),
        minimumSize: const Size(60, 33),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Text(
        _available(item) ? '+ ADD' : 'Sold out',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }

  Widget _stepper(StorefrontCartItem line) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFF6F8FE),
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(
          Icons.remove,
          'Remove one ${line.item.name}',
          _busy ? null : () => _quantity(line, -1),
        ),
        Text(
          '${line.quantity}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        _stepButton(
          Icons.add,
          'Add one ${line.item.name}',
          _canOrder ? () => _quantity(line, 1) : null,
        ),
      ],
    ),
  );

  Widget _stepButton(IconData icon, String tooltip, VoidCallback? onTap) =>
      IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 16),
        color: _blue,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFE6EEFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        constraints: const BoxConstraints.tightFor(width: 31, height: 36),
        padding: EdgeInsets.zero,
      );

  Widget _itemTitle(MenuItemModel item, {required int maxLines}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (item.itemType.toLowerCase() != 'beverage') ...[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _DietaryMark(item),
        ),
        const SizedBox(width: 5),
      ],
      Expanded(
        child: Text(
          item.name,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, height: 1.18),
        ),
      ),
    ],
  );

  Widget _amount(String label, double value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: bold ? _title(label, 19) : Text(label)),
        if (bold) _title(_money(value), 19) else Text(_money(value)),
      ],
    ),
  );

  Widget _title(String text, double size, {bool centered = false}) => Text(
    text,
    textAlign: centered ? TextAlign.center : null,
    style: TextStyle(
      fontSize: size,
      height: 1.14,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.35,
    ),
  );

  Widget _notice(String text, {IconData icon = Icons.info_outline}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: _tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _primary(
    String label,
    VoidCallback? onPressed, {
    IconData? icon,
  }) => SizedBox(
    width: double.infinity,
    height: 46,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 7)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 7),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ],
      ),
    ),
  );

  Widget _card({
    required Widget child,
    required EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE8EDF4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    ),
  );

  InputDecoration _input(String hint, {Widget? prefix, bool filled = false}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 13),
      prefixIcon: prefix,
      fillColor: const Color(0xFFF1F4F8),
      filled: filled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: border,
      enabledBorder: border,
    );
  }

  String _productImage(MenuItemModel item) => item.imageUrl.trim().isNotEmpty
      ? item.imageUrl
      : (item.images.isEmpty ? '' : item.images.first);

  Widget _photo(MenuItemModel item, double radius) => PosProductMediaBox(
    key: ValueKey('qr-media-${item.id}'),
    item: item,
    borderRadius: BorderRadius.circular(radius),
    autoPlayVideo: _page == _Page.menu || _page == _Page.home,
    autoSlide: true,
    showDots: item.videoUrl.trim().isNotEmpty,
    isMini: false,
    independentPlayback: true,
    onTap: () => _showDetails(item),
  );

  Widget _image(String path) {
    const fallback = ColoredBox(
      color: Color(0xFFEDF2F8),
      child: Center(child: Icon(Icons.restaurant, color: _muted)),
    );
    if (path.trim().isEmpty) return fallback;
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.network(
      ApiEndpoints.resolveMediaUrl(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _DietaryMark extends StatelessWidget {
  final MenuItemModel item;
  const _DietaryMark(this.item);

  @override
  Widget build(BuildContext context) {
    final color = item.isVeg
        ? const Color(0xFF087D46)
        : const Color(0xFFC82E38);
    return Semantics(
      label: item.itemType,
      child: Container(
        width: 12,
        height: 12,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _IndiaDialCode extends StatelessWidget {
  const _IndiaDialCode();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 19,
          height: 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ColoredBox(color: Color(0xFFFF9A38))),
                  Expanded(child: ColoredBox(color: Color(0xFFFFFFFF))),
                  Expanded(child: ColoredBox(color: Color(0xFF138808))),
                ],
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF223B78),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 3, height: 3),
              ),
            ],
          ),
        ),
        SizedBox(width: 7),
        Text('+91', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(width: 9),
        SizedBox(
          height: 20,
          width: 1,
          child: ColoredBox(color: Color(0xFFD7DFEB)),
        ),
      ],
    ),
  );
}

class _PhoneIllustration extends StatelessWidget {
  const _PhoneIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 162,
    height: 121,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: const Alignment(0, 0.8),
          child: Container(
            width: 157,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EEFF),
              borderRadius: BorderRadius.circular(38),
            ),
          ),
        ),
        Transform.rotate(
          angle: 0.17,
          child: Container(
            width: 63,
            height: 108,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF064CF5), width: 3),
              borderRadius: BorderRadius.circular(13),
              boxShadow: const [
                BoxShadow(color: Color(0x33064CF5), offset: Offset(4, 2)),
              ],
            ),
            child: const Center(
              child: CircleAvatar(
                backgroundColor: Color(0xFF064CF5),
                child: Icon(Icons.check_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
