import 'dart:async';

class ScreenRefreshService {
  static final ScreenRefreshService _instance = ScreenRefreshService._internal();
  factory ScreenRefreshService() => _instance;
  ScreenRefreshService._internal();

  final _tabController = StreamController<int>.broadcast();
  Stream<int> get onTabChanged => _tabController.stream;

  void notifyTabChanged(int index) {
    _tabController.add(index);
  }
  
  void dispose() {
    _tabController.close();
  }
}
