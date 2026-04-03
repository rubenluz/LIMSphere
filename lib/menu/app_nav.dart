import 'package:flutter/material.dart';

/// Global scaffold key exposing the root mobile Scaffold so any embedded page
/// can open the navigation drawer without importing menu_page.dart (which would
/// create a circular dependency since menu_page.dart imports every page).
final menuScaffoldKey = GlobalKey<ScaffoldState>();

/// Opens the mobile navigation drawer from anywhere in the widget tree.
void openAppDrawer() => menuScaffoldKey.currentState?.openDrawer();
