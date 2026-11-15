with open('lib/core/network/api_endpoints.dart', 'r', encoding='utf-8') as f:
    text = f.read()

target1 = """    // 6. Default fallback: Default LAN IP on Android, localhost on Desktop
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _resolvedBaseUrl = 'http://$defaultLanIp:$defaultPort/api/v1';
    } else if (isDesktop) {
      _resolvedBaseUrl = 'http://127.0.0.1:$defaultPort/api/v1';
    } else {
      _resolvedBaseUrl = productionApiUrl;
    }
    debugPrint('[ApiEndpoints] Fallback base URL: $_resolvedBaseUrl');"""

replace1 = """    // 6. Default fallback: Live production cloud backend (Render 24/7)
    _resolvedBaseUrl = productionApiUrl;
    debugPrint('[ApiEndpoints] Candidate probes finished. Active cloud base URL: $_resolvedBaseUrl');"""

target2 = """    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$defaultLanIp:$defaultPort/api/v1';
    }
    return 'http://127.0.0.1:$defaultPort/api/v1';"""

replace2 = """    return productionApiUrl;"""

# Normalize line endings for replacement
text_norm = text.replace('\r\n', '\n')
target1_norm = target1.replace('\r\n', '\n')
target2_norm = target2.replace('\r\n', '\n')

if target1_norm in text_norm and target2_norm in text_norm:
    text_norm = text_norm.replace(target1_norm, replace1)
    text_norm = text_norm.replace(target2_norm, replace2)
    with open('lib/core/network/api_endpoints.dart', 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(text_norm)
    print("SUCCESS: api_endpoints.dart patched successfully")
else:
    print("FAILED: targets not found")
