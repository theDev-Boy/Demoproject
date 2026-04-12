import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/gender_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/call_screen.dart';
import '../screens/history_screen.dart';

/// App-wide route configuration using GoRouter.
class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/auth',
          name: 'auth',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/gender-selection',
          name: 'gender-selection',
          builder: (context, state) => const GenderSelectionScreen(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/call',
          name: 'call',
          builder: (context, state) => const CallScreen(),
        ),
        GoRoute(
          path: '/history',
          name: 'history',
          builder: (context, state) => const HistoryScreen(),
        ),
      ],
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        final isLoggedIn = auth.isLoggedIn;
        final hasProfile = auth.hasCompletedProfile;
        final currentPath = state.matchedLocation;

        // Allow splash to load
        if (currentPath == '/splash') return null;

        // Not logged in → go to auth
        if (!isLoggedIn) {
          if (currentPath != '/auth') return '/auth';
          return null;
        }

        // Logged in but no profile → go to gender selection
        if (isLoggedIn && !hasProfile) {
          if (currentPath != '/gender-selection') return '/gender-selection';
          return null;
        }

        // Logged in with profile but still on auth or gender page → go home
        if (isLoggedIn &&
            hasProfile &&
            (currentPath == '/auth' || currentPath == '/gender-selection')) {
          return '/home';
        }

        return null;
      },
    );
  }
}
