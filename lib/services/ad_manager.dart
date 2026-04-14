import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../utils/logger.dart';

class AdManager {
  static const String gameId = '6080976';
  static const String interstitialPlacementId = 'Interstitial_Android';
  static const String rewardedPlacementId = 'Rewarded_Android';
  static const bool testMode = true; // Set to true for development

  static DateTime? _lastAdTime;
  static bool _isInitialized = false;

  /// Initialize the Unity Ads SDK.
  static Future<void> init() async {
    if (_isInitialized) return;
    
    await UnityAds.init(
      gameId: gameId,
      testMode: testMode,
      onComplete: () {
        _isInitialized = true;
        logger.i('[AdManager] Unity Ads Initialized');
        _loadInterstitial();
        _loadRewarded();
      },
      onFailed: (error, message) {
        logger.e('[AdManager] Unity Ads Initialization Failed: $error - $message');
      },
    );
  }

  /// Load an interstitial ad so it's ready for display.
  static void _loadInterstitial() {
    UnityAds.load(
      placementId: interstitialPlacementId,
      onComplete: (placementId) => logger.i('[AdManager] Interstitial Loaded'),
      onFailed: (placementId, error, message) => logger.e('[AdManager] Interstitial Load Failed: $error - $message'),
    );
  }

  /// Load a rewarded ad.
  static void _loadRewarded() {
    UnityAds.load(
      placementId: rewardedPlacementId,
      onComplete: (placementId) => logger.i('[AdManager] Rewarded Loaded'),
      onFailed: (placementId, error, message) => logger.e('[AdManager] Rewarded Load Failed: $error - $message'),
    );
  }

  /// Show an interstitial ad with a 5-second cooldown safety.
  static Future<void> showInterstitial({
    Function? onComplete,
    Function(String error)? onFailed,
  }) async {
    // 5-second cooldown check as requested by User
    final now = DateTime.now();
    if (_lastAdTime != null && now.difference(_lastAdTime!).inSeconds < 5) {
      logger.i('[AdManager] Ad skipped due to 5-second cooldown');
      onComplete?.call();
      return;
    }

    if (!_isInitialized) {
      logger.w('[AdManager] Ad not shown: Not initialized');
      onFailed?.call('Not initialized');
      return;
    }

    await UnityAds.showVideoAd(
      placementId: interstitialPlacementId,
      onStart: (placementId) => logger.i('[AdManager] Ad Started'),
      onComplete: (placementId) {
        logger.i('[AdManager] Ad Finished');
        _lastAdTime = DateTime.now();
        _loadInterstitial(); // Pre-load next one
        onComplete?.call();
      },
      onFailed: (placementId, error, message) {
        logger.e('[AdManager] Ad Failed: $error - $message');
        onFailed?.call(message);
      },
    );
  }

  /// Show a rewarded ad.
  static Future<void> showRewardedAd({
    required Function onComplete,
    required Function(String error) onFailed,
  }) async {
    if (!_isInitialized) {
      onFailed('Not initialized');
      return;
    }

    await UnityAds.showVideoAd(
      placementId: rewardedPlacementId,
      onComplete: (placementId) {
        _loadRewarded();
        onComplete();
      },
      onFailed: (placementId, error, message) {
        _loadRewarded();
        onFailed(message);
      },
    );
  }

  /// Force-load an ad if needed.
  static void reloadAd() => _loadInterstitial();
}
