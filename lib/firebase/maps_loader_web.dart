import 'package:web/web.dart' as web;

/// Dynamically inject the Google Maps JavaScript SDK on web using a
/// compile-time API key passed via --dart-define. This avoids hardcoding
/// the key in index.html.
void injectMapsScript(String apiKey) {
  // Prevent double-injection
  if (web.document.getElementById('google-maps-sdk') != null) return;
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.id = 'google-maps-sdk';
  script.src =
      'https://maps.googleapis.com/maps/api/js?key=$apiKey&loading=async';
  script.async = true;
  script.defer = true;
  web.document.head!.appendChild(script);
}
