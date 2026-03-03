import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../routes/route_paths.dart';

class HomeShellPage extends StatelessWidget {
  const HomeShellPage({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  int _indexFromLocation(String location) {
    if (location.startsWith(RoutePaths.readingNow)) {
      return 0;
    }
    if (location.startsWith(RoutePaths.library)) {
      return 1;
    }
    return 2;
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexFromLocation(location);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: _goBranch,
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: Text(l10n.tabReadingNow),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.library_books_outlined),
                selectedIcon: const Icon(Icons.library_books),
                label: Text(l10n.tabLibrary),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: Text(l10n.tabMe),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
