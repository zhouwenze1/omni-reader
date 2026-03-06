import 'home_tab.dart';

class HomeState {
  const HomeState({this.tab = HomeTab.readingNow});

  final HomeTab tab;

  HomeState copyWith({HomeTab? tab}) {
    return HomeState(tab: tab ?? this.tab);
  }
}
