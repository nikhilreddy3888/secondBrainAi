import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/vault_model.dart';

import '../features/assistant/screens/assistant_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/documents/screens/documents_screen.dart';
import '../features/events/screens/events_screen.dart';
import '../features/notes/screens/add_note_screen.dart';
import '../features/notes/screens/notes_screen.dart';
import '../features/passwords/screens/passwords_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/settings/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/notes',
        name: 'notes',
        builder: (context, state) => const NotesScreen(),
      ),
      GoRoute(
        path: '/notes/add',
        name: 'add_note',
        builder: (context, state) {
          final extra = state.extra;
          final note = extra is VaultNote ? extra : null;
          return AddNoteScreen(note: note);
        },
      ),
      GoRoute(
        path: '/passwords',
        name: 'passwords',
        builder: (context, state) => const PasswordsScreen(),
      ),
      GoRoute(
        path: '/documents',
        name: 'documents',
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: '/events',
        name: 'events',
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/assistant',
        name: 'assistant',
        builder: (context, state) => const AssistantScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
