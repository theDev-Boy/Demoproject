import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import '../utils/constants.dart';

class TRTCService {
  static const int _sdkAppId = AppConstants.trtcSdkAppId;
  static const String _secretKey = AppConstants.trtcSecretKey;

  /// Generate UserSig for a given userId.
  static String generateUserSig(String userId) {
    const int expire = 604800; // 7 days
    final int currTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int expireTime = currTime + expire;

    final String base =
        'TLS.identifier:$userId\nTLS.sdkappid:$_sdkAppId\nTLS.time:$currTime\nTLS.expire:$expireTime\n';
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(base));
    final sign = base64Encode(digest.bytes);

    final Map<String, dynamic> jsonObj = {
      'TLS.ver': '2.0',
      'TLS.identifier': userId,
      'TLS.sdkappid': _sdkAppId,
      'TLS.expire': expire,
      'TLS.time': currTime,
      'TLS.sig': sign,
    };

    return base64Url
        .encode(utf8.encode(json.encode(jsonObj)))
        .replaceAll('+', '*')
        .replaceAll('/', '-')
        .replaceAll('=', '_');
  }

  /// Initialize Tencent Calls UIKit with user credentials.
  static Future<void> init(String userId, String userName) async {
    final userSig = generateUserSig(userId);
    // In 4.0.8, use login instead of init
    await TUICallKit.instance.login(_sdkAppId, userId, userSig);
    await TUICallKit.instance.setSelfInfo(userName, '');
  }

  /// Make a 1-on-1 video call to a user.
  static Future<void> startVideoCall(String calleeId) async {
    // In 4.0.8, use calls (plural) which takes a List
    await TUICallKit.instance.calls([calleeId], CallMediaType.video);
  }

  /// Make a 1-on-1 audio/voice call to a user.
  static Future<void> startAudioCall(String calleeId) async {
    await TUICallKit.instance.calls([calleeId], CallMediaType.audio);
  }

  /// Logout and clean up TRTC resources.
  static Future<void> uninit() async {
    // In 4.0.8, use logout
    await TUICallKit.instance.logout();
  }
}
