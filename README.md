# LIMSphere

LIMSphere is a cross-platform Laboratory Information Management System (LIMS) built with Flutter and Supabase. It brings biological collection records, fish-facility operations, laboratory resources, inventory, labels, and administrative workflows into one application.

The project is currently under active development. It is intended for laboratories that need a practical operational workspace rather than a single-purpose sample database. Desktop layouts support data-heavy management work, while the mobile application includes QR scanning and quick record access.

## Current scope

- Culture collections: strains, samples, detailed records, imports, exports, and SOPs
- Fish facilities: stocks, tanks, fish lines, water quality, feeding, and operational history
- Laboratory resources: rooms and storage locations, reagents, machines, reservations, and a visual lab map
- Traceability tools: QR scanning, item logs, label design, label printing, and backup/export workflows
- Collaboration and administration: requests, laboratory chat, users, granular permissions, audit logs, and settings
- General laboratory tools: concentration and dilution calculators, unit conversion, and well randomization

The planned work, priorities, and known gaps are tracked in the [project roadmap](TODO.md).

## Technology

- Flutter and Dart for Windows, Linux, macOS, Android, iOS, and web targets
- Supabase for database access, authentication, and backend services
- Material 3 with responsive desktop and mobile interfaces
- Local preferences for saved connections, sessions, and application settings

## Getting started

### Requirements

- A Flutter SDK compatible with the Dart constraint in `pubspec.yaml`
- A Supabase project URL and publishable key
- Platform tooling for the target you want to run

### Run locally

```sh
flutter pub get
flutter run
```

On first launch, add a Supabase connection. LIMSphere can validate the database and guide an administrator through initial setup before login.

### Development checks

```sh
flutter analyze
flutter test
```

## Project layout

```text
lib/
  culture_collection/   Strains, samples, imports, and collection workflows
  fish_facility/        Stocks, tanks, fish lines, and water quality
  resources/            Locations, reagents, machines, reservations, and lab map
  labels/               Label creation, printing, and printer drivers
  supabase/             Supabase client management and database foundations
  users/                User profiles and access management
android/                Android platform project
ios/                    iOS platform project
linux/                  Linux desktop project
macos/                  macOS desktop project
web/                    Web platform project
windows/                Windows desktop project
```

## Status and roadmap

LIMSphere is not yet presented as a finished production release. The current codebase contains substantial working functionality, while global search, deeper record-level authorization, distribution workflows, and improvements to existing collection-management pages remain planned.

See [TODO.md](TODO.md) for the detailed roadmap and current implementation status.

## Repository

[github.com/rubenluz/LIMSphere](https://github.com/rubenluz/LIMSphere)
