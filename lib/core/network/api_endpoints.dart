import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiEndpoints {
  /// Current local development LAN IP (auto-updated to your machine's IP)
  static const String defaultLanIp = '172.16.2.4';
  static const int defaultPort = 5000;

  /// Compile-time environment variable support e.g. flutter run --dart-define=API_URL=https://api.apnapos.com/api/v1
  static const String envApiUrl = String.fromEnvironment('API_URL', defaultValue: '');

  /// Default production cloud URL (deployed to Render 24/7)
  static const String productionApiUrl = 'https://apna-pos-app.onrender.com/api/v1';

  /// Cloudflare Tunnel URL (connects local server to Cloudflare edge)
  static const String cloudflareTunnelUrl = 'https://apna-pos-tunnel.trycloudflare.com/api/v1';

  /// Public Tunnel URL (bypasses Windows Firewall and works on Public/Private Wi-Fi & 4G/5G)
  static const String publicTunnelUrl = 'https://apna-pos-backend.loca.lt/api/v1';

  static String? _resolvedBaseUrl;

  /// Explicitly set custom backend base URL (e.g. https://apna-pos-app.onrender.com/api/v1 or http://172.16.2.3:5000/api/v1)
  static Future<void> setCustomBaseUrl(String url) async {
    if (url.trim().isNotEmpty) {
      var clean = url.trim();
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
        clean = 'http://$clean';
      }
      if (!clean.endsWith('/api/v1')) {
        if (clean.endsWith('/')) {
          clean = '${clean}api/v1';
        } else {
          clean = '$clean/api/v1';
        }
      }
      _resolvedBaseUrl = clean;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_backend_base_url', clean);
      } catch (_) {}
    }
  }

  static Future<void> resetBaseUrl() async {
    _resolvedBaseUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_backend_base_url');
    } catch (_) {}
  }

  /// Initialize and auto-discover reachable backend server endpoint
  static Future<void> initialize({bool forceRecheck = false}) async {
    // 0. If already resolved and not forced, verify health quickly
    if (!forceRecheck && _resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
      return;
    }

    // 1. Check compile-time environment variable
    if (envApiUrl.isNotEmpty) {
      _resolvedBaseUrl = envApiUrl;
      debugPrint('[ApiEndpoints] Using environment API_URL: $_resolvedBaseUrl');
      return;
    }

    // 2. Check saved user preference
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_backend_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        final isCustomAlive = await _pingHealth(savedUrl, timeoutMs: 1200);
        if (isCustomAlive) {
          _resolvedBaseUrl = savedUrl;
          debugPrint('[ApiEndpoints] Using saved custom backend URL: $_resolvedBaseUrl');
          return;
        }
      }
    } catch (_) {}

    // 3. Web platform
    if (kIsWeb) {
      _resolvedBaseUrl = productionApiUrl;
      return;
    }

    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final primaryCandidates = [
      'http://$defaultLanIp:$defaultPort/api/v1',
      if (isDesktop) 'http://127.0.0.1:$defaultPort/api/v1',
      if (isDesktop) 'http://localhost:$defaultPort/api/v1',
      if (Platform.isAndroid) 'http://10.0.2.2:$defaultPort/api/v1',
      'http://127.0.0.1:$defaultPort/api/v1',
      'http://localhost:$defaultPort/api/v1',
      'http://172.16.2.3:$defaultPort/api/v1',
      productionApiUrl,
      cloudflareTunnelUrl,
      publicTunnelUrl,
    ];

    // Fast parallel probe across all primary candidates
    final activeCandidate = await _scanCandidatesParallel(primaryCandidates, timeoutMs: 1200);
    if (activeCandidate != null) {
      _resolvedBaseUrl = activeCandidate;
      debugPrint('[ApiEndpoints] Connected to active backend at: $activeCandidate');
      return;
    }

    // 5. Dynamic Subnet Auto-Discovery (if primary candidates failed)
    if (!kIsWeb) {
      final subnetCandidates = _generateSubnetCandidates();
      final dynamicResolved = await _scanCandidatesParallel(subnetCandidates, timeoutMs: 500);
      if (dynamicResolved != null) {
        _resolvedBaseUrl = dynamicResolved;
        debugPrint('[ApiEndpoints] Auto-discovered backend on subnet: $dynamicResolved');
        return;
      }
    }

    // 6. Default fallback: Default LAN IP on Android, localhost on Desktop
    if (Platform.isAndroid) {
      _resolvedBaseUrl = 'http://$defaultLanIp:$defaultPort/api/v1';
    } else if (isDesktop) {
      _resolvedBaseUrl = 'http://127.0.0.1:$defaultPort/api/v1';
    } else {
      _resolvedBaseUrl = productionApiUrl;
    }
    debugPrint('[ApiEndpoints] Fallback base URL: $_resolvedBaseUrl');
  }

  /// Fast parallel ping across candidate endpoints
  static Future<String?> _scanCandidatesParallel(List<String> urls, {int timeoutMs = 400}) async {
    final completer = Completer<String?>();
    int pending = urls.length;
    if (urls.isEmpty) return null;

    for (final url in urls) {
      _pingHealth(url, timeoutMs: timeoutMs).then((isHealthy) {
        if (isHealthy && !completer.isCompleted) {
          completer.complete(url);
        } else {
          pending--;
          if (pending <= 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }).catchError((_) {
        pending--;
        if (pending <= 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future.timeout(
      const Duration(milliseconds: 1200),
      onTimeout: () => null,
    );
  }

  /// Generate likely DHCP IP addresses on local Wi-Fi subnets
  static List<String> _generateSubnetCandidates() {
    final list = <String>[];
    // Subnet variations based on defaultLanIp (172.16.2.x)
    final parts = defaultLanIp.split('.');
    if (parts.length == 4) {
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      for (int i = 2; i <= 20; i++) {
        final ip = '$prefix.$i';
        if (ip != defaultLanIp) {
          list.add('http://$ip:$defaultPort/api/v1');
        }
      }
    }
    // Also add common 192.168.1.x and 192.168.0.x candidates
    for (int i = 2; i <= 15; i++) {
      list.add('http://192.168.1.$i:$defaultPort/api/v1');
      list.add('http://192.168.0.$i:$defaultPort/api/v1');
    }
    return list;
  }

  /// Quick health check ping
  static Future<bool> _pingHealth(String candidateUrl, {int timeoutMs = 700}) async {
    try {
      final uri = Uri.parse('$candidateUrl/health');
      final response = await http.get(
        uri,
        headers: {
          'Bypass-Tunnel-Reminder': 'true',
          'Accept': 'application/json',
        },
      ).timeout(Duration(milliseconds: timeoutMs));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Public method to test health of any URL
  static Future<bool> testConnection(String url) async {
    var clean = url.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    if (!clean.endsWith('/api/v1')) {
      if (clean.endsWith('/')) {
        clean = '${clean}api/v1';
      } else {
        clean = '$clean/api/v1';
      }
    }
    return _pingHealth(clean, timeoutMs: 1500);
  }

  /// Active Base URL
  static String get baseUrl {
    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
      return _resolvedBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:$defaultPort/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://$defaultLanIp:$defaultPort/api/v1';
    }
    return 'http://127.0.0.1:$defaultPort/api/v1';
  }

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String resetPassword = '/auth/reset-password';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Onboarding endpoints
  static const String onboardingProfile = '/onboarding/profile';
  static const String onboardingBusiness = '/onboarding/business';
  static const String onboardingAddress = '/onboarding/address';
  static const String onboardingOrderSettings = '/onboarding/order-settings';
  static const String onboardingStatus = '/onboarding/status';
  static const String onboardingComplete = '/onboarding/complete';

  // Product & Category endpoints
  static const String products = '/products';
  static const String productsPos = '/products/pos';
  static const String categories = '/products/categories';
  static const String productsBulk = '/products/bulk';

  // Order & POS endpoints
  static const String orders = '/orders';
  static const String orderSaveAndPrint = '/orders/save-and-print';
  static const String orderTable = '/orders/table';
  static const String paymentMethods = '/payment-methods';
  static const String payments = '/payments';
  static const String createPaymentQr = '/payments/create-qr';
  static const String paymentStatus = '/payments/status';
  static const String printLogs = '/print-logs';

  // Sales & Reports endpoints
  static const String sales = '/sales';
  static const String salesSummary = '/sales/summary';
  static const String salesReport = '/sales/report';
  static const String topProducts = '/sales/top-products';

  // Dashboard endpoints
  static const String dashboardOverview = '/dashboard/overview';
  static const String dashboardSummary = '/dashboard/summary';
  static const String dashboardOrderTypes = '/dashboard/order-types';
  static const String dashboardProductSales = '/dashboard/product-sales';
  static const String dashboardCustomers = '/dashboard/customers';
  static const String dashboardPaymentMethods = '/dashboard/payment-methods';
  static const String dashboardTaxes = '/dashboard/taxes';
  static const String dashboardOrderStats = '/dashboard/order-stats';
  static const String dashboardChart = '/dashboard/chart';

  // CRM endpoints
  static const String crmLeads = '/crm/leads';
  static const String crmStats = '/crm/stats';
  static const String crmExport = '/crm/export';
  static const String crmImport = '/crm/import';

  // Tables endpoints
  static const String tables = '/tables';

  // Customers endpoints
  static const String customers = '/customers';

  // Inventory endpoints
  static const String inventory = '/inventory';

  // Profile & Business Settings endpoints
  static const String profile = '/profile';
  static const String posSettings = '/profile/pos-settings';
  static const String profileSettings = '/profile/settings';

  // Cart endpoints
  static const String cart = '/cart';
  static const String cartAdd = '/cart/add';
  static const String cartReduce = '/cart/reduce';
  static const String cartRemove = '/cart/remove';
  static const String cartSync = '/cart/sync';
  static const String cartClear = '/cart/clear';

  // Extras & Coupons endpoints
  static const String extras = '/extras';
  static const String validateCoupon = '/extras/validate-coupon';

  // Upload endpoints
  static const String uploadImage = '/upload/image';

  // Loyalty endpoints
  static const String loyaltyPrograms = '/loyalty/programs';
  static const String loyaltyConfig = '/loyalty/config';
  static const String loyaltyPerformance = '/loyalty/performance';
  static const String loyaltyCustomer = '/loyalty/customer';
  static const String loyaltySendOtp = '/loyalty/send-otp';
  static const String loyaltyVerifyOtp = '/loyalty/verify-otp';
  static const String loyaltyRedeem = '/loyalty/redeem';

  // Notification endpoints
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationDelete(String id) => '/notifications/$id';
  static const String notificationsClearAll = '/notifications/clear-all';
  static const String registerDeviceToken = '/notifications/device-token';
  static const String triggerDailySummary = '/notifications/trigger-daily-summary';

  // Subscription & Lead endpoints
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionLead = '/subscription/lead';
  static const String subscriptionLeads = '/subscription/leads';

  /// Show Developer / Admin Server Configuration Sheet
  static void showServerConfigSheet(BuildContext context, {VoidCallback? onUrlChanged}) {
    final controller = TextEditingController(text: baseUrl);
    bool testing = false;
    String? testResult;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.dns_rounded, color: Color(0xFF0284C7), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Server Connection Settings',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Configure your Node.js backend server URL or test connectivity for local Wi-Fi and production cloud hosting.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        labelText: 'Backend Base URL',
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        hintText: 'e.g. http://172.16.2.3:5000/api/v1',
                        prefixIcon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF0284C7)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    if (testResult != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                testResult!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Test Ping Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: testing
                                ? null
                                : () async {
                                    setModalState(() {
                                      testing = true;
                                      testResult = null;
                                    });
                                    final success = await testConnection(controller.text);
                                    setModalState(() {
                                      testing = false;
                                      isSuccess = success;
                                      testResult = success
                                          ? 'Connected! Server is online.'
                                          : 'Cannot reach server at this URL.';
                                    });
                                  },
                            icon: testing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.network_ping_rounded, size: 16),
                            label: Text(testing ? 'Testing...' : 'Test Ping'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Save & Apply Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await setCustomBaseUrl(controller.text);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Connected backend URL: ${ApiEndpoints.baseUrl}'),
                                    backgroundColor: const Color(0xFF16A34A),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                onUrlChanged?.call();
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Save & Use'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await resetBaseUrl();
                          await initialize();
                          setModalState(() {
                            controller.text = baseUrl;
                            testResult = 'Reset to default auto-detected URL';
                            isSuccess = true;
                          });
                        },
                        child: const Text(
                          'Reset to Auto-Detect Default',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
