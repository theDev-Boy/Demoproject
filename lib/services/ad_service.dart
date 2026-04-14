import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../utils/logger.dart';

class AdService {
  static const String androidGameId = '5243163'; // Placeholder IDs
  static const String iosGameId = '5243162';
  
  static const String rewardedVideoPlacementId = 'Rewarded_Android';
  static const String interstitialPlacementId = 'Interstitial_Android';

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    
    await UnityAds.init(
      gameId: androidGameId,
      testMode: true, // Set to false for production
      onComplete: () {
        _isInitialized = true;
        logger.i('Unity Ads Initialized Successfully');
      },
      onFailed: (error, message) => logger.e('Unity Ads Initialization Failed: $error $message'),
    );
  }

  static Future<void> showRewardedAd({
    required Function onComplete,
    required Function(String) onFailed,
  }) async {
    // In test mode, we might just call onComplete directly for speed
    // but here is the real implementation logic:
    
    UnityAds.showVideoAd(
      placementId: rewardedVideoPlacementId,
      onComplete: (placementId) => onComplete(),
      onFailed: (placementId, error, message) => onFailed(message),
      onStart: (placementId) => logger.i('Ad Started'),
      onClick: (placementId) => logger.i('Ad Clicked'),
    );
  }

  static Future<void> loadAd() async {
    await UnityAds.load(placementId: rewardedVideoPlacementId);
    await UnityAds.load(placementId: interstitialPlacementId);
  }
}
