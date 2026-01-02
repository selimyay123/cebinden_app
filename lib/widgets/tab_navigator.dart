import 'package:flutter/material.dart';

class TabNavigator extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const TabNavigator({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          builder: (context) => child,
        );
      },
    );
  }
}
