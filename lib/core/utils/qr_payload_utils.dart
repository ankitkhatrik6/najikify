/// Validation / extraction helpers for Najikify pairing payloads.
///
/// A pairing payload can reach the app from three different places:
///   * a live camera scan (mobile),
///   * an image file that contains a screenshot/photo of the QR code,
///   * a pasted pairing link ("Copy Link" on the peer device).
///
/// Text coming from those sources is often surrounded by whitespace, quotes or
/// extra sentence text, so the raw string is normalised here before it is
/// handed over to [PairingSession.fromQrUri].
class QrPayloadUtils {
  QrPayloadUtils._();

  /// URI scheme used by Najikify pairing links.
  static const String scheme = 'najikify';

  /// Fully qualified prefix of a valid pairing link.
  static const String pairUriPrefix = 'najikify://pair/';

  /// Alternative deep-link form accepted for compatibility.
  static const String pairDeepLinkPrefix = 'najikify:pair/';

  /// Returns the pairing URI contained in [raw], or null when [raw] does not
  /// hold a Najikify pairing payload.
  static String? extractPairingUri(String? raw) {
    final candidate = _extractSchemeFragment(raw);
    if (candidate == null) return null;
    if (candidate.startsWith(pairUriPrefix)) return candidate;
    if (candidate.startsWith(pairDeepLinkPrefix)) return candidate;
    // `najikify://pair?data=<payload>` style links.
    if (candidate.startsWith('najikify://pair?')) return candidate;
    return null;
  }

  /// True when [raw] contains a Najikify pairing payload.
  static bool isValidPairingUri(String? raw) => extractPairingUri(raw) != null;

  /// True when [raw] looks like a Najikify link, but not necessarily a pairing
  /// one (used to produce a friendlier "not a pairing code" message).
  static bool looksLikeNajikifyLink(String? raw) {
    final candidate = _extractSchemeFragment(raw);
    return candidate != null && candidate.startsWith('najikify:');
  }

  /// Normalises [raw] and returns the fragment that starts at the Najikify
  /// scheme, ignoring surrounding prose, quotes, line breaks and punctuation.
  static String? _extractSchemeFragment(String? raw) {
    if (raw == null) return null;

    final value = raw.trim();
    if (value.isEmpty) return null;

    // Pairing payloads are base64url and never contain whitespace, so the text
    // can safely be split into tokens before the scheme is located.
    for (final token in value.split(RegExp(r'\s+'))) {
      final index = token.indexOf('najikify:');
      if (index < 0) continue;

      final fragment = _trimTrailingPunctuation(token.substring(index));
      if (fragment.isNotEmpty) return fragment;
    }

    return null;
  }

  /// Removes quotes/brackets/punctuation that often follow a copied link.
  static String _trimTrailingPunctuation(String value) {
    const trailing = <String>[
      '"', "'", '`', ')', ']', '}', ',', '.', ';', ':', '>',
    ];

    var result = value;
    var changed = true;
    while (changed && result.isNotEmpty) {
      changed = false;
      for (final char in trailing) {
        if (result.endsWith(char)) {
          result = result.substring(0, result.length - 1);
          changed = true;
        }
      }
    }
    return result;
  }
}
