import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/measurements/presentation/measurement_form_page.dart';
import '../../features/measurements/presentation/measurements_page.dart';
import '../../features/photos/presentation/photos_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/progress/presentation/progress_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/subscription/presentation/plans_page.dart';
import '../../features/training/presentation/active_training_page.dart';
import '../../features/training/presentation/exercise_library_page.dart';
import '../../features/training/presentation/routine_editor_page.dart';
import '../../features/training/presentation/training_page.dart';
import '../widgets/app_shell.dart';

String? authRedirect(AuthSession session, String path) {
  final public = [
    '/login',
    '/register',
    '/recovery',
    '/confirm',
  ].contains(path);
  if (session.recovering && session.account != null) {
    return path == '/new-password' ? null : '/new-password';
  }
  if (session.account == null) return public ? null : '/login';
  return public || path == '/new-password' || path == '/' ? '/home' : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, next) => refresh.refresh());
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (_, state) =>
        authRedirect(ref.read(authControllerProvider), state.uri.path),
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, state) => const AuthPage(mode: AuthPageMode.login),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (_, state) => const AuthPage(mode: AuthPageMode.register),
      ),
      GoRoute(
        path: '/recovery',
        name: 'recovery',
        builder: (_, state) => const AuthPage(mode: AuthPageMode.recovery),
      ),
      GoRoute(
        path: '/confirm',
        name: 'confirm',
        builder: (_, state) => AuthPage(
          mode: AuthPageMode.confirm,
          email: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/new-password',
        name: 'new-password',
        builder: (_, state) => const AuthPage(mode: AuthPageMode.newPassword),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, state) => const HomePage(),
          ),
          GoRoute(
            path: '/training',
            name: 'training',
            builder: (_, state) => const TrainingPage(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/measurements',
            name: 'measurements',
            builder: (_, state) => const MeasurementsPage(),
          ),
          GoRoute(
            path: '/progress',
            name: 'progress',
            builder: (_, state) => const ProgressPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/training/new',
        name: 'new-training',
        builder: (_, state) => const RoutineEditorPage(),
      ),
      GoRoute(
        path: '/measurements/new',
        name: 'new-measurement',
        builder: (_, state) => const MeasurementFormPage(),
      ),
      GoRoute(
        path: '/photos',
        name: 'photos',
        builder: (_, state) => const PhotosPage(),
      ),
      GoRoute(
        path: '/training/edit/:id',
        name: 'edit-training',
        builder: (_, state) =>
            RoutineEditorPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/training/active',
        name: 'active-training',
        builder: (_, state) => const ActiveTrainingPage(),
      ),
      GoRoute(
        path: '/training/history/:id',
        name: 'training-history',
        builder: (_, state) =>
            HistoryDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/exercises',
        name: 'exercises',
        builder: (_, state) => const ExerciseLibraryPage(),
      ),
      GoRoute(
        path: '/plans',
        name: 'plans',
        builder: (_, state) => const PlansPage(),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (_, state) => const ReportsPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, state) => const SettingsPage(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
