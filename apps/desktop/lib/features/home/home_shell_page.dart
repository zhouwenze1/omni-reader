import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_paths.dart';
import '../../utils/window_util.dart';

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

  void _goBranch(BuildContext context, int index) {
    navigationShell.goBranch(index,
        initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexFromLocation(location);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _goBranch(context, index),
            labelType: NavigationRailLabelType.all,
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: () => context.push(RoutePaths.settingsHome),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      IconButton(
                        tooltip: 'Exit App',
                        onPressed: () => WindowUtil.requestExit(context),
                        icon: const Icon(Icons.power_settings_new),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: Text('Reading'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books),
                label: Text('Library'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Me'),
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
