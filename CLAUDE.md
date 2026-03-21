# BlueOpenLIMS — CLAUDE.md

Flutter + Supabase desktop LIMS app. 
Primary target: Windows desktop, shoudl also be fully compatabilble with phone (android and iOS; layout may change for compatability purposes). 
Uses Material 3 with light and dark theme.

---

## Project structure

```
lib/
  main.dart                          # App entry, StartupPage (splash + routing logic)
  menu/menu_page.dart                # Root shell: sidebar nav, permission checks, connectivity timer
  theme/
    theme.dart                       # AppDS design tokens + AppThemeContext extension
    theme_controller.dart            # ThemeMode persistence (light/dark/system)
    module_permission.dart           # ModulePermission InheritedWidget + context extensions
  supabase/
    supabase_manager.dart            # Supabase init/restore helpers
    core_tables_sql.dart             # SQL schema strings
  core/
    local_storage.dart               # SharedPreferences helpers (connections, session, settings)
    fish_db_schema.dart / sop_db_schema.dart
  admin/
    app_settings.dart                # Visible module groups + other global settings
    settings_page.dart
  dashboard/                         # Dashboard page + widgets
  culture_collection/
    strains/                         # StrainsPage, StrainDetailPage, design tokens, columns
    samples/                         # SamplesPage, SampleDetailPage, design tokens, columns
    function_excel_import_page.dart
  fish_facility/
    shared_widgets.dart              # FishDS tokens + InlineEditCell (permission-aware)
    stocks/ lines/ tanks/
  resources/
    reagents/ machines/ reservations/ locations/
  printing/                          # Label designer + printer driver (ZPL / Brother QL)
    printing_page.dart               # Main part file (uses `part` for sub-files)
  sops/                              # PDF/DOCX viewer, SOP list
  lab_chat/
  login/ database_connection/ users/ qr_scanner/
```

---

## Architecture rules

### Page layout
- Pages are **not** full `Scaffold`s — they are `Column` widgets embedded in `MenuPage`'s content area.
- **Exceptions that own a Scaffold**: `StrainsPage`, `SamplesPage` (have their own `AppBar`), all detail pages pushed via `Navigator`.
- Fish facility pages: `Column` with a dark toolbar row at top. No `AppBar`.
- Detail pages: push a new route with `Navigator.push(MaterialPageRoute(...))` — they have their own `Scaffold + AppBar`.

### Navigation
- Central router lives in `MenuPage._groups` / `MenuPage._topItems`.
- Module selection: `_select(id)` — checks role + per-user permission before switching.
- Named routes (`/connections`, `/login`, `/menu`, etc.) are only for the auth/startup flow.

### Part files
`printing_page.dart` uses `part` / `part of` for `printing_builder_page.dart`, `printer_settings_page.dart`, `templates_dialog.dart`, `printing_db_field_picker.dart`. Shared types (`LabelField`, `LabelTemplate`, `_ConnState`, etc.) must be declared in the main `printing_page.dart` file.

---

## Design system

### Token class — `AppDS` (`lib/theme/theme.dart`)
Use `AppDS.*` constants for **fixed dark-chrome areas** (toolbars, sidebar, table headers, dialogs, AppBars of detail pages).

```dart
AppDS.bg        // 0xFF0F172A  — page background
AppDS.surface   // 0xFF1E293B  — cards, rows, panels
AppDS.surface2  // 0xFF1A2438
AppDS.surface3  // 0xFF243044
AppDS.border    // 0xFF334155
AppDS.border2   // 0xFF2D3F55
AppDS.accent    // 0xFF38BDF8  sky-400
AppDS.green     // 0xFF22C55E
AppDS.yellow    // 0xFFEAB308
AppDS.orange    // 0xFFF97316
AppDS.red       // 0xFFEF4444
AppDS.purple    // 0xFFA855F7
AppDS.pink      // 0xFFEC4899
AppDS.textPrimary   // 0xFFF1F5F9
AppDS.textSecondary // 0xFF94A3B8
AppDS.textMuted     // 0xFF64748B
```

### Adaptive context extension — `AppThemeContext` (`lib/theme/theme.dart`)
Use `context.app*` getters for **page content areas** that must flip between light and dark mode:

```dart
context.appBg          // page scaffold background
context.appSurface     // card / panel background
context.appSurface2 / appSurface3
context.appBorder / appBorder2
context.appTextPrimary
context.appTextSecondary
context.appTextMuted
context.appHeaderBg / appHeaderText  // data-table column headers
```

**Rule**: toolbar rows, `AppBar`, sidebar → `AppDS.*`; main content area → `context.app*`.

### Typography
- Body / UI labels: `GoogleFonts.spaceGrotesk(...)` or `AppDS.ui(size, color, weight)`
- Numbers / codes / mono: `GoogleFonts.jetBrainsMono(...)` or `AppDS.mono(size, color, weight)`

### Deprecation rules
- Use `.withValues(alpha: x)` — **not** `.withOpacity(x)` (deprecated).
- Use `activeThumbColor` — **not** `activeColor` on `Switch` (deprecated).

### Amber / warning color
`const Color(0xFFF59E0B)` — used for offline banners, driverOnly printer state, read-only "View only" snackbar icon.

---

## Permission system

### Role hierarchy (weakest → strongest)
`viewer` < `technician` < `researcher` < `admin` < `superadmin`

Role gates per module: defined in `_moduleRequiredRole` map in `menu_page.dart`.

### Per-user module permissions
Stored as columns in the `users` table: `user_table_dashboard`, `user_table_chat`, `user_table_culture_collection`, `user_table_fish_facility`, `user_table_resources`. Values: `'none'` | `'read'` | `'write'`.

Admins/superadmins always get `'write'` regardless of column values.

### Propagation — `ModulePermission` (`lib/theme/module_permission.dart`)
`MenuPage._getContentWidget` wraps each page in `ModulePermission(permission: perm, child: ...)`.

Inside any page widget:
```dart
// Check before allowing an edit action:
if (!context.canEditModule) { context.warnReadOnly(); return; }

// canEditModule = ModulePermission.of(context) == 'write'
// warnReadOnly() = amber floating snackbar
```

Guard pattern — apply at the **top** of edit methods or in `onDoubleTap` / `onPressed` callbacks:
```dart
onDoubleTap: () {
  if (!context.canEditModule) { context.warnReadOnly(); return; }
  // ... proceed with edit
},
```

---

## Supabase patterns

### Client access
Always use `Supabase.instance.client` (not `SupabaseManager.client`) inside page widgets, as the latter throws if not initialized.

### Standard query pattern
```dart
try {
  final rows = await Supabase.instance.client
      .from('table_name')
      .select()
      .eq('column', value);
  if (!mounted) return;
  setState(() { /* update state */ });
} catch (e) {
  if (!mounted) return;
  // show snackbar or set error state
}
```

### Auth
- Current user email: `Supabase.instance.client.auth.currentSession?.user.email`
- Sign out: `Supabase.instance.client.auth.signOut()`
- `SupabaseManager.restoreLastConnection()` — called once at startup in `StartupPage`.

### Users table columns (relevant)
`user_email`, `user_name`, `user_role`, `user_status` (`'pending'` | `'active'`), `user_last_login`, `user_table_dashboard`, `user_table_chat`, `user_table_culture_collection`, `user_table_fish_facility`, `user_table_resources`.

---

## Connectivity

### Startup check (`main.dart`)
`StartupPage._startupLogic()` runs `checkConnectivity()` (DNS lookup with 4 s timeout) concurrently with an 800 ms minimum splash delay. Sets `_offline = true` → shows amber badge in splash UI.

### Runtime listener (`menu_page.dart`)
`_connectivityTimer` polls every 10 s using the same DNS lookup. Shows floating SnackBar on drop (amber, wifi_off icon) and recovery (green, wifi icon).

---

## CSV export pattern

Used in `fish_lines_page.dart`, `tanks_page.dart`, `reagents_page.dart` (canonical reference):

```dart
Future<void> _exportCsv() async {
  final buf = StringBuffer();
  buf.writeln('Col1,Col2,Col3');
  for (final row in _rows) {
    buf.writeln('"${row['col1']}","${row['col2']}",...');
  }
  final dir = await getDownloadsDirectory();
  final file = File('${dir!.path}/export_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(buf.toString());
  await OpenFilex.open(file.path);
}
```

Required imports: `dart:io`, `package:open_filex/open_filex.dart`, `package:path_provider/path_provider.dart`.

---

## Key shared widgets

| Widget / Class | File | Purpose |
|---|---|---|
| `AppDS` | `lib/theme/theme.dart` | Design tokens (colors, text styles, dimensions) |
| `AppThemeContext` extension | `lib/theme/theme.dart` | Adaptive `context.app*` color getters |
| `ModulePermission` | `lib/theme/module_permission.dart` | Permission InheritedWidget + `context.canEditModule` / `context.warnReadOnly()` |
| `InlineEditCell` | `lib/fish_facility/shared_widgets.dart` | Permission-aware double-tap-to-edit cell |
| `StrainsDS` | `lib/culture_collection/strains/strains_design_tokens.dart` | Strains grid colors/dims |
| `SamplesDS` | `lib/culture_collection/samples/samples_design_tokens.dart` | Samples grid colors/dims |
| `_ConnState` enum | `lib/printing/printing_page.dart` | Printer reachability: `checking / connected / driverOnly / unreachable` |

---

## Coding conventions

- **No trailing summaries** in responses — the user reads the diff directly.
- **No extra comments** on unchanged code. Only add a comment when logic is non-obvious.
- **No unused imports** — the project uses `flutter_lints`; treat warnings as errors.
- Dart 3 patterns (`switch` expressions, exhaustive `switch`, records) are allowed — SDK `^3.11.0`.
- Prefer `const` constructors wherever possible.
- State updates: always check `if (!mounted) return;` after any `await` before calling `setState`.
- Snackbars: use `ScaffoldMessenger.of(context)`, `SnackBarBehavior.floating`, `BorderRadius.circular(10)`, `AppDS.surface` background.
- Error handling: swallow non-critical errors silently with `catch (_) {}`. Surface errors to the user only for user-initiated actions.

---

## What NOT to do

- Do not create a new `Scaffold` inside a page that is embedded in `MenuPage` (it breaks the layout).
- Do not use `.withOpacity()` — use `.withValues(alpha: x)`.
- Do not use `activeColor` on `Switch` — use `activeThumbColor`.
- Do not add docstrings or type annotations to code you haven't changed.
- Do not add fallbacks/defaults for states that cannot occur.
- Do not create helper functions/utilities for single-use operations.
