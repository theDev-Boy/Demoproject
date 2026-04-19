/// App-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Zuumeet';
  static const String appTagline = 'Connect with people around the world';

  // Splash
  static const int splashDurationMs = 3000;

  // WebRTC ICE servers are now fetched DYNAMICALLY by IceServerService.
  // They include:
  //   • 6x Google/Cloudflare STUN servers (always included)
  //   • Open Relay Project TURN servers (fetched from openrelay.metered.ca)
  //     → Works behind symmetric NATs, corporate/university firewalls
  //     → Ports 80, 443, TCP — universally firewall-safe
  //   • 24-hour cache + hardcoded fallback if API is unreachable
  // See: lib/utils/ice_server_service.dart

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
