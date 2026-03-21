// module_permission.dart - ModulePermission InheritedWidget that propagates
// the current page's read/write permission; context.canEditModule and
// context.warnReadOnly() helpers.

import 'package:flutter/material.dart';

/// Carries the current module's permission down the widget tree so any page
/// can check whether the user is allowed to edit without needing the full
/// user-info map passed through constructors.
///
/// Values: 'none' | 'read' | 'write'
class ModulePermission extends InheritedWidget {
  final String permission;

  const ModulePermission({
    super.key,
    required this.permission,
    required super.child,
  });

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ModulePermission>()
          ?.permission ??
          'write'; // default: allow (pages outside MenuPage context)

  @override
  bool updateShouldNotify(ModulePermission old) => permission != old.permission;
}

extension ModulePermissionContext on BuildContext {
  /// True when the current module grants write access.
  bool get canEditModule => ModulePermission.of(this) == 'write';

  /// Shows a "View only" snackbar — call this when a blocked edit is attempted.
  void warnReadOnly() {
    ScaffoldMessenger.of(this).showSnackBar(const SnackBar(
      duration: Duration(seconds: 3),
      content: Row(children: [
        Icon(Icons.visibility_outlined, color: Color(0xFFD97706), size: 16),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'View only — contact an admin to request edit access.',
            style: TextStyle(color: Color(0xFF334155), fontSize: 13),
          ),
        ),
      ]),
    ));
  }
}
