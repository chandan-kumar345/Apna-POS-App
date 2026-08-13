import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps across Windows, Web, Android, iOS, and macOS.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCAxoctCJKW63TaINdzpcBzDCiVTvJ0TKQ',
    appId: '1:370857291670:web:c07e72aa06fae7832637b7',
    messagingSenderId: '370857291670',
    projectId: 'apna-pos-55b95',
    authDomain: 'apna-pos-55b95.firebaseapp.com',
    storageBucket: 'apna-pos-55b95.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCAxoctCJKW63TaINdzpcBzDCiVTvJ0TKQ',
    appId: '1:370857291670:android:c07e72aa06fae7832637b7',
    messagingSenderId: '370857291670',
    projectId: 'apna-pos-55b95',
    storageBucket: 'apna-pos-55b95.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCAxoctCJKW63TaINdzpcBzDCiVTvJ0TKQ',
    appId: '1:370857291670:ios:c07e72aa06fae7832637b7',
    messagingSenderId: '370857291670',
    projectId: 'apna-pos-55b95',
    storageBucket: 'apna-pos-55b95.firebasestorage.app',
    iosBundleId: 'com.example.apna_pos',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCAxoctCJKW63TaINdzpcBzDCiVTvJ0TKQ',
    appId: '1:370857291670:ios:c07e72aa06fae7832637b7',
    messagingSenderId: '370857291670',
    projectId: 'apna-pos-55b95',
    storageBucket: 'apna-pos-55b95.firebasestorage.app',
    iosBundleId: 'com.example.apna_pos',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCAxoctCJKW63TaINdzpcBzDCiVTvJ0TKQ',
    appId: '1:370857291670:web:c07e72aa06fae7832637b7',
    messagingSenderId: '370857291670',
    projectId: 'apna-pos-55b95',
    authDomain: 'apna-pos-55b95.firebaseapp.com',
    storageBucket: 'apna-pos-55b95.firebasestorage.app',
  );
}
