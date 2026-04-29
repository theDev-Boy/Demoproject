/// App-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Zuumeet';
  static const String appTagline = 'Connect with people around the world';

  // Tencent RTC Credentials
  static const int trtcSdkAppId = 20039211;
  static const String trtcSecretKey = 'b809fd78516ac3134601ee922be96480ba693421b862d58189f0d6abd05d6fa8';

  // Splash
  static const int splashDurationMs = 3000;

  // Gender options
  static const List<String> genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> interestOptions = ['Men', 'Women', 'Everyone'];

  // Report reasons
  static const List<String> reportReasons = [
    'Inappropriate content',
    'Harassment',
    'Spam',
    'Underage user',
    'Other',
  ];

  // Database paths (Firebase Realtime Database)
  static const String usersPath = 'users';
  static const String activeUsersPath = 'active_users';
  static const String matchesPath = 'matches';
  static const String directCallsPath = 'direct_calls';
  static const String reportsPath = 'reports';
  static const String bannedUsersPath = 'banned_users';
}
