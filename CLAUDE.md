# BlueOpenLIMS — CLAUDE.md

Flutter + Supabase desktop LIMS app.
Primary target: Windows desktop, should also be fully compatible with phone (Android and iOS; layout may change for compatibility purposes).
Uses Material 3 with light and dark theme.

---

## Project structure

```
lib/
  main.dart                          # App entry point
  startup_page.dart                  # Splash screen + routing logic (StartupPage)
  menu/
    menu_page.dart                   # Root shell: sidebar nav, permission checks, connectivity timer
    app_nav.dart                     # Global scaffold key (openAppDrawer) — avoids circular imports
  theme/
    theme.dart                       # AppDS design tokens + AppThemeContext extension
    theme_controller.dart            # ThemeMode persistence (light/dark/system)
    module_permission.dart           # ModulePermission InheritedWidget + context extensions
    grid_widgets.dart                # Shared data-table scrollbar thumbs used across grid pages
  supabase/
    supabase_manager.dart            # Supabase init/restore helpers
    core_tables_sql.dart             # SQL schema strings
  core/
    local_storage.dart               # SharedPreferences helpers (connections, session, settings)
    data_cache.dart
    fish_db_schema.dart / sop_db_schema.dart
  admin/
    app_settings.dart                # Visible module groups + other global settings
    settings_page.dart
    backup_service.dart              # Backup logic
    backups_page.dart                # Backups UI (desktop-only)
  audit_log/
    audit_log.dart                   # Read-only admin-only audit log page
  camera/                            # Mobile-only camera hub
    camera_page.dart                 # Entry point: QR scan + item register tiles
    qr_scanner/
      qr_scanner_page.dart
      qr_code_rules.dart             # QR routing rules (shared with menu_page & label_page)
    item_log/
      item_register_page.dart
  dashboard/                         # Dashboard page + widgets subdirectory
  culture_collection/
    strains/                         # StrainsPage, StrainDetailPage, design tokens, columns
    samples/                         # SamplesPage, SampleDetailPage, design tokens, columns
    function_excel_import_page.dart
    excel_import_widgets.dart
  fish_facility/
    shared_widgets.dart              # FishDS tokens + InlineEditCell (permission-aware)
    add_stock_dialog.dart
    stocks/ lines/ tanks/
    water_qc/                        # Water quality control page (desktop + mobile views)
  locations/
    locations_page.dart              # Standalone top-level module (not under resources/)
    location_detail_page.dart
    location_model.dart
    locations_widgets.dart
  resources/
    reagents/ machines/ reservations/
  labels/                            # Label designer + printer driver (ZPL / Brother QL)
    label_page.dart                  # Main part file — defines LabelField, LabelTemplate, PrinterConfig, _ConnState
    builder/                         # Label canvas designer, palette, properties, DB field picker
    print/                           # Print page: record list, filters, print dispatch
    printer_drivers/                 # ZPL driver, Brother QL-570/700, settings page
    templates/                       # Template listing, preview canvas, template dialog
  requests/
    requests_page.dart               # Unified request management (any user can create)
  sops/                              # PDF/DOCX viewer, SOP list
  lab_chat/
  login/ database_connection/ users/
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
- Mobile drawer: call `openAppDrawer` (from `lib/menu/app_nav.dart`) — never import `menu_page.dart` from pages (circular dependency).

### Part files
`label_page.dart` uses `part` / `part of` for all files under `builder/`, `print/`, `printer_drivers/`, and `templates/`. Shared types (`LabelField`, `LabelTemplate`, `PrinterConfig`, `_ConnState`, etc.) must be declared in the main `label_page.dart` file.

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
Stored as columns in the `users` table:
`user_table_dashboard`, `user_table_chat`, `user_table_culture_collection`, `user_table_fish_facility`, `user_table_resources`, `user_table_backups`.
Values: `'none'` | `'read'` | `'write'`.

Admins/superadmins always get `'write'` regardless of column values.

### Module → permission column mapping (in `_modulePermColumn`, `menu_page.dart`)
| Module id | Permission column |
|---|---|
| `dashboard`, `labels` | `user_table_dashboard` |
| `chat` | `user_table_chat` |
| `backups` | `user_table_backups` |
| `strains`, `samples`, `sops_inventory` | `user_table_culture_collection` |
| `fish_stock`, `fish_tankmap`, `fish_lines`, `fish_water_qc`, `sops_fish` | `user_table_fish_facility` |
| `locations`, `reagents`, `equipment`, `reservations` | `user_table_resources` |
| `requests` | `null` (all authenticated users) |
| `audit` | role gate: `admin` |
| `camera` | mobile-only, no permission gate |

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
`user_email`, `user_name`, `user_role`, `user_status` (`'pending'` | `'active'`), `user_last_login`, `user_table_dashboard`, `user_table_chat`, `user_table_culture_collection`, `user_table_fish_facility`, `user_table_resources`, `user_table_backups`.

---

## Connectivity

### Startup check (`lib/startup_page.dart`)
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
| `openAppDrawer` | `lib/menu/app_nav.dart` | Opens mobile nav drawer from any page without circular import |
| `AppHorizontalThumb` / `AppVerticalThumb` | `lib/theme/grid_widgets.dart` | Shared custom scrollbar thumbs for data grids |
| `InlineEditCell` | `lib/fish_facility/shared_widgets.dart` | Permission-aware double-tap-to-edit cell |
| `StrainsDS` | `lib/culture_collection/strains/strains_design_tokens.dart` | Strains grid colors/dims |
| `SamplesDS` | `lib/culture_collection/samples/samples_design_tokens.dart` | Samples grid colors/dims |
| `LabelField`, `LabelTemplate`, `_ConnState` | `lib/labels/label_page.dart` | Shared types for the labels subsystem |

---

## Coding conventions

- **No trailing summaries** in responses — the user reads the diff directly.
- **No extra comments** on unchanged code. Only add a comment when logic is non-obvious.
- **No unused imports** — the project uses `flutter_lints`; treat warnings as errors.
- Dart 3 patterns (`switch` expressions, exhaustive `switch`, records) are allowed — SDK `^3.11.4`.
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
- Do not import `menu_page.dart` from pages — use `app_nav.dart` for drawer access instead.
