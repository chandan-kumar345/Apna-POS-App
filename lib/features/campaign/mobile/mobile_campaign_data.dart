import 'dart:math';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';

typedef CampaignJson = Map<String, dynamic>;

const campaignOrders = {
  'dine_in': 'Dine-in',
  'takeaway': 'Takeaway',
  'delivery': 'Delivery',
};
const campaignCategories = {
  'MARKETING': 'Marketing',
  'UTILITY': 'Utility',
  'AUTHENTICATION': 'Auth',
};
const campaignActions = {
  'URL': 'Visit website',
  'PHONE_NUMBER': 'Call phone',
  'QUICK_REPLY': 'Quick reply',
};
const istOffset = Duration(hours: 5, minutes: 30);

DateTime indiaClock(DateTime instant) => instant.toUtc().add(istOffset);
String campaignTime(DateTime instant) =>
    DateFormat('d MMM yyyy · h:mm a').format(indiaClock(instant));
String campaignNumber(dynamic n) =>
    n is num && n != 0 ? NumberFormat('0.##', 'en').format(n) : '';
DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toUtc();

class CampaignOptions {
  final String business, logo;
  final List<CampaignJson> products, groups, channels;
  CampaignOptions(CampaignJson json)
    : business = json['businessName'] ?? 'My business',
      logo = json['logoUrl'] ?? '',
      products = List<CampaignJson>.from(json['products'] ?? []),
      groups = List<CampaignJson>.from(json['groups'] ?? []),
      channels = List<CampaignJson>.from(json['channels'] ?? []);
  String product(String id) =>
      products.where((p) => p['id'] == id).firstOrNull?['name'] ?? '';
  CampaignJson? group(String id) =>
      groups.where((p) => p['id'] == id).firstOrNull;
}

class MessageAction {
  String type, text, value;
  MessageAction({this.type = 'URL', this.text = '', this.value = ''});
  String get _phoneNumber {
    final compact = value.trim().replaceAll(RegExp(r'[ ()-]'), '');
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(compact)) return '+91$compact';
    return compact;
  }

  CampaignJson toJson() => {
    'type': type,
    'text': text.trim(),
    'value': type == 'PHONE_NUMBER' ? _phoneNumber : value.trim(),
  };
  String? get error {
    if (text.trim().isEmpty) return 'Enter button text for each action.';
    if (type == 'URL') {
      final uri = Uri.tryParse(value.trim());
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          RegExp(r'[\s{}]').hasMatch(value)) {
        return 'Enter a complete website URL.';
      }
    }
    if (type == 'PHONE_NUMBER' &&
        !RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(_phoneNumber)) {
      return 'Enter a 10-digit Indian mobile number or an international number starting with +.';
    }
    return null;
  }
}

class MobileCampaignDraft {
  String id;
  int revision = 0;
  List<String> orders = ['takeaway', 'delivery'];
  String reward = '', amount = '', minimum = '', cap = '', gift = '', buy = '';
  int giftQty = 1, buyQty = 1;
  String headline = '', details = '', terms = '', coupon = '';
  DateTime? expiry, sendAt;
  bool later = false;
  String channel = '',
      category = 'MARKETING',
      title = '',
      body = '',
      image = '',
      group = '';
  List<MessageAction> actions = [];

  MobileCampaignDraft() : id = _newId() {
    final day = indiaClock(DateTime.now()).add(const Duration(days: 7));
    expiry = DateTime.utc(
      day.year,
      day.month,
      day.day,
      23,
      59,
    ).subtract(istOffset);
  }
  static String _newId() {
    final random = Random.secure();
    return List.generate(
      12,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  MobileCampaignDraft.fromJson(CampaignJson json)
    : id = (json['id'] ?? json['_id']).toString() {
    final r = json['rewardDetails'] ?? {},
        t = json['template'] ?? {},
        c = json['couponSettings'] ?? {};
    final studio = json['mobileStudio'] ?? {};
    revision = studio['revision'] ?? 0;
    group = studio['groupId'] ?? '';
    orders = List<String>.from(json['orderTypes'] ?? []);
    reward = r['rewardType'] ?? '';
    amount = campaignNumber(r['discountAmount']);
    minimum = campaignNumber(r['minSpendAmount']);
    cap = campaignNumber(r['maxCashbackCap']);
    buy = r['buyProductId'] ?? '';
    gift = r['freeGiftProductId'] ?? '';
    buyQty = r['buyQuantity'] ?? 1;
    giftQty = r['giftQuantity'] ?? 1;
    headline = r['promotionHeadline'] ?? '';
    details = r['offerDetails'] ?? '';
    terms = (r['termsAndConditions'] as List? ?? []).join('\n');
    coupon = c['couponCode'] ?? '';
    expiry = _date(c['expiryDate']);
    title = r['campaignTitle'] ?? '';
    body = t['body'] ?? '';
    image = t['headerMediaUrl'] ?? '';
    channel = json['channel']?['channelType'] ?? '';
    category = t['category'] ?? 'MARKETING';
    actions = [
      for (final a in t['actions'] ?? [])
        MessageAction(
          type: a['type'],
          text: a['text'] ?? '',
          value: a['value'] ?? '',
        ),
    ];
    later = json['schedule']?['mode'] == 'later';
    sendAt = _date(json['schedule']?['scheduledAt']);
  }

  CampaignJson toJson() => {
    'revision': revision,
    'orderTypes': orders,
    'rewardType': reward,
    'discountAmount': amount,
    'minimumOrder': minimum,
    'maximumDiscount': cap,
    'giftItem': gift,
    'buyItem': buy,
    'giftQty': giftQty,
    'buyQty': buyQty,
    'headline': headline,
    'offerDetails': details,
    'terms': terms,
    'couponCode': coupon.trim().toUpperCase(),
    'expiryAt': expiry?.toUtc().toIso8601String(),
    'title': title,
    'body': body,
    'imageUrl': image,
    'channel': channel,
    'category': category,
    'actions': actions.map((a) => a.toJson()).toList(),
    'groupId': group,
    'scheduleMode': later ? 'later' : 'now',
    'sendAt': later ? sendAt?.toUtc().toIso8601String() : null,
  };

  String get orderLabel => orders.map((t) => campaignOrders[t] ?? t).join(', ');
  String summary(CampaignOptions options) {
    final min = (double.tryParse(minimum) ?? 0) > 0
        ? ' on orders of ₹$minimum or more'
        : '';
    switch (reward) {
      case 'percentage':
        return '${amount.isEmpty ? '0' : amount}% OFF${(double.tryParse(cap) ?? 0) > 0 ? ' up to ₹$cap' : ''}$min';
      case 'flat_discount':
        return '₹${amount.isEmpty ? '0' : amount} OFF$min';
      case 'free_gift':
        return '$giftQty free ${options.product(gift).isEmpty ? 'gift' : options.product(gift)}$min';
      case 'bogo':
        return 'Buy $buyQty ${options.product(buy).isEmpty ? 'item' : options.product(buy)}, get $giftQty ${options.product(gift)} free';
      case 'promotional':
        return [
          headline.trim(),
          orderLabel,
        ].where((s) => s.isNotEmpty).join(' · ');
      default:
        return '';
    }
  }

  String? get rewardError {
    if (orders.isEmpty || reward.isEmpty) {
      return 'Select an order type and reward.';
    }
    if (['percentage', 'flat_discount'].contains(reward)) {
      final n = double.tryParse(amount);
      if (n == null ||
          !n.isFinite ||
          n <= 0 ||
          n > 1e8 ||
          (reward == 'percentage' && n > 100)) {
        return 'Enter a valid discount.';
      }
    }
    if (['free_gift', 'bogo'].contains(reward) && gift.isEmpty ||
        reward == 'bogo' && buy.isEmpty) {
      return 'Choose the menu items.';
    }
    if (reward == 'promotional' &&
        (headline.trim().isEmpty || details.trim().isEmpty)) {
      return 'Enter the headline and offer details.';
    }
    if (!RegExp(r'^[A-Z0-9_-]{1,32}$').hasMatch(coupon.trim().toUpperCase())) {
      return 'Enter a valid coupon code.';
    }
    if (expiry?.isAfter(DateTime.now()) != true) {
      return 'Select a future expiry.';
    }
    return null;
  }

  String? get messageError {
    if (category == 'AUTHENTICATION') {
      return channel.isEmpty || title.trim().isEmpty
          ? 'Select a channel and enter a title.'
          : null;
    }
    if (channel.isEmpty || title.trim().isEmpty || body.trim().isEmpty) {
      return 'Select a channel and enter a title and message.';
    }
    if (RegExp('[{}]').hasMatch(body.replaceAll('{{name}}', ''))) {
      return 'Use {{name}} for the customer name.';
    }
    return null;
  }

  String? get actionError {
    if (category == 'AUTHENTICATION') return null;
    if (actions.where((a) => a.type == 'PHONE_NUMBER').length > 1) {
      return 'Use one call button per message.';
    }
    for (final a in actions) {
      if (a.error != null) return a.error;
    }
    return null;
  }
}

class MobileCampaignApi {
  static const path = '/campaigns/mobile';
  final _client = ApiClient();
  Future<CampaignJson> performance(String id) async =>
      (await _client.get('$path/$id/performance'))['data'];

  Future<CampaignJson> followUp(String id, CampaignJson payload) async =>
      (await _client.postOnce('$path/$id/audience', data: payload))['data'];
  Future<void> setPaused(String id, bool pause) async {
    await _client.put('/campaigns/$id/${pause ? 'pause' : 'resume'}');
  }

  Future<CampaignOptions> options() async =>
      CampaignOptions((await _client.get('$path/options'))['data']);
  Future<CampaignJson> dashboard(
    String search,
    String status,
    int page,
  ) async => (await _client.get(
    path,
    queryParameters: {'search': search, 'status': status, 'page': page},
  ))['data'];
  Future<CampaignJson> save(MobileCampaignDraft draft) async =>
      (await _client.put('$path/${draft.id}', data: draft.toJson()))['data'];
  Future<void> submit(MobileCampaignDraft draft) async {
    await _client.postOnce(
      '$path/${draft.id}/submit',
      data: {'revision': draft.revision},
    );
  }

  Future<CampaignJson> launch(
    MobileCampaignDraft draft,
    int count, {
    List<String> phones = const [],
  }) async =>
      (await _client.postOnce(
        '$path/${draft.id}/launch',
        data: {
          'revision': draft.revision,
          'confirmedOptIn': true,
          'confirmedCount': count,
          'groupId': (draft.group.isNotEmpty && draft.group != 'all')
              ? draft.group
              : null,
          'phones': phones,
          'scheduleMode': draft.later ? 'later' : 'now',
          'sendAt': draft.sendAt?.toUtc().toIso8601String(),
        },
      ))['data'];
}
