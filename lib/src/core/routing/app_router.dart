import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/word_lists/presentation/screens/word_list_browser_screen.dart';
import '../../features/word_lists/presentation/screens/word_list_detail_screen.dart';
import '../../features/study/presentation/screens/study_setup_screen.dart';
import '../../features/study/presentation/screens/study_session_screen.dart';
import '../../features/study/presentation/screens/quiz_screen.dart';
import '../../features/study/presentation/screens/kanji_reading_quiz_screen.dart';
import '../../features/study/presentation/screens/kanji_selection_quiz_screen.dart';
import '../../features/study/presentation/screens/session_summary_screen.dart';
import '../../features/audio_review/presentation/screens/audio_review_setup_screen.dart';
import '../../features/audio_review/presentation/screens/audio_review_screen.dart';
import '../../features/ai_passage/presentation/screens/daily_passage_screen.dart';
import '../../features/ai_passage/presentation/screens/passage_history_screen.dart';
import '../../features/ai_passage/presentation/screens/passage_quiz_screen.dart';
import '../../features/checkin/presentation/screens/checkin_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../constants/app_constants.dart';
import '../../common_widgets/responsive_layout.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/word-lists',
            name: 'wordLists',
            builder: (context, state) => const WordListBrowserScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'wordListDetail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return WordListDetailScreen(wordListId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/study/setup',
            name: 'studySetup',
            builder: (context, state) => const StudySetupScreen(),
          ),
          GoRoute(
            path: '/study/session',
            name: 'studySession',
            builder: (context, state) => const StudySessionScreen(),
          ),
          GoRoute(
            path: '/study/quiz',
            name: 'studyQuiz',
            builder: (context, state) => const QuizScreen(),
          ),
          GoRoute(
            path: '/study/kanji-reading',
            name: 'kanjiReadingQuiz',
            builder: (context, state) => const KanjiReadingQuizScreen(),
          ),
          GoRoute(
            path: '/study/kanji-selection',
            name: 'kanjiSelectionQuiz',
            builder: (context, state) => const KanjiSelectionQuizScreen(),
          ),
          GoRoute(
            path: '/study/summary',
            name: 'sessionSummary',
            builder: (context, state) => const SessionSummaryScreen(),
          ),
          GoRoute(
            path: '/audio-review/setup',
            name: 'audioReviewSetup',
            builder: (context, state) => const AudioReviewSetupScreen(),
          ),
          GoRoute(
            path: '/audio-review/session',
            name: 'audioReviewSession',
            builder: (context, state) => const AudioReviewScreen(),
          ),
          GoRoute(
            path: '/ai-passage',
            name: 'dailyPassage',
            builder: (context, state) => const DailyPassageScreen(),
          ),
          GoRoute(
            path: '/ai-passage/quiz',
            name: 'passageQuiz',
            builder: (context, state) => const PassageQuizScreen(),
          ),
          GoRoute(
            path: '/ai-passage/history',
            name: 'passageHistory',
            builder: (context, state) => const PassageHistoryScreen(),
          ),
          GoRoute(
            path: '/checkin',
            name: 'checkin',
            builder: (context, state) => const CheckinScreen(),
          ),
          GoRoute(
            path: '/statistics',
            name: 'statistics',
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

/// App shell with responsive navigation (bottom bar on mobile, side rail on desktop)
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: '首页', path: '/'),
    (icon: Icons.book_outlined, selectedIcon: Icons.book, label: '词单', path: '/word-lists'),
    (icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: '统计', path: '/statistics'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: '设置', path: '/settings'),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    context.go(_navItems[index].path);
  }

  int _getSelectedIndex(String location) {
    for (int i = 0; i < _navItems.length; i++) {
      if (location == _navItems[i].path ||
          (i > 0 && location.startsWith(_navItems[i].path))) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    _selectedIndex = _getSelectedIndex(location);

    // Hide navigation on study/audio/quiz screens
    final hideNav = location.startsWith('/study/session') ||
        location.startsWith('/study/quiz') ||
        location.startsWith('/study/kanji-reading') ||
        location.startsWith('/study/kanji-selection') ||
        location.startsWith('/audio-review/session') ||
        location.startsWith('/ai-passage/quiz');

    if (hideNav) {
      return widget.child;
    }

    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              destinations: _navItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: _navItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}
