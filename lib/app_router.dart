import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/days_overview_screen.dart';
import 'screens/day_detail_screen.dart';
import 'screens/extras_screen.dart';
import 'screens/packing_screen.dart';
import 'screens/practical_screen.dart';
import 'screens/conversations_screen.dart';
import 'screens/gorges_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/plan_library_screen.dart';
import 'screens/trip_meta_edit_screen.dart';
import 'screens/extras_edit_screen.dart';
import 'screens/side_sections_edit_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (ctx, st) => const HomeScreen(),
    ),
    GoRoute(
      path: '/days',
      builder: (ctx, st) => const DaysOverviewScreen(),
    ),
    GoRoute(
      path: '/day/:id',
      builder: (ctx, st) => DayDetailScreen(dayId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/extras',
      builder: (ctx, st) => const ExtrasScreen(),
    ),
    GoRoute(
      path: '/packing',
      builder: (ctx, st) => const PackingScreen(),
    ),
    GoRoute(
      path: '/practical',
      builder: (ctx, st) => const PracticalScreen(),
    ),
    GoRoute(
      path: '/conversations',
      builder: (ctx, st) => const ConversationsScreen(),
    ),
    GoRoute(
      path: '/gorges',
      builder: (ctx, st) => const GorgesScreen(),
    ),
    GoRoute(
      path: '/emergency',
      builder: (ctx, st) => const EmergencyScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (ctx, st) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/library',
      builder: (ctx, st) => const PlanLibraryScreen(),
    ),
    // ===== Edit routes =====
    GoRoute(
      path: '/edit/meta',
      builder: (ctx, st) => const TripMetaEditScreen(),
    ),
    GoRoute(
      path: '/edit/extras',
      builder: (ctx, st) => const ExtrasEditListScreen(),
    ),
    GoRoute(
      path: '/edit/packing',
      builder: (ctx, st) => const PackingEditScreen(),
    ),
    GoRoute(
      path: '/edit/emergency',
      builder: (ctx, st) => const EmergencyEditScreen(),
    ),
    GoRoute(
      path: '/edit/contingency',
      builder: (ctx, st) => const ContingencyEditScreen(),
    ),
  ],
  errorBuilder: (ctx, st) => Scaffold(
    appBar: AppBar(title: const Text('Błąd nawigacji')),
    body: Center(child: Text(st.error.toString())),
  ),
);
