import 'dart:async';

class ScreenRefreshService {
  static final ScreenRefreshService _instance = ScreenRefreshService._internal();
  factory ScreenRefreshService() => _instance;
  ScreenRefreshService._internal();

  final _tabController = StreamController<int>.broadcast();
  Stream<int> get onTabChanged => _tabController.stream;

  final _tabChangeRequestController = StreamController<int>.broadcast();
  Stream<int> get onTabChangeRequested => _tabChangeRequestController.stream;

  void notifyTabChanged(int index) {
    _tabController.add(index);
  }

  void requestTabChange(int index) {
    _tabChangeRequestController.add(index);
  }
  
  void dispose() {
    _tabController.close();
    _tabChangeRequestController.close();
  }
}
