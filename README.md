# LIMSphere

LIMSphere is a cross-platform application for managing a scientific laboratory. It brings a culture collection, zebrafish facility, reagent stock, machines, reservations, labels, and practical laboratory tools into one connected workspace.

The goal is not to build an overcomplicated traceability system. LIMSphere is designed to make everyday laboratory work simple: records from different areas should connect naturally, QR codes should open the correct information across desktop and mobile, and users should be able to make quick updates from a phone.

The interface should remain easy to understand, easy to set up, and consistent across every page. Similar actions and records should use the same layouts and interaction patterns throughout the application.

## Current scope

- Culture collection: strains, samples, linked detail records, imports, exports, maps, and SOPs
- Zebrafish facility: stocks, tanks, fish lines, water quality, feeding, and daily facility work
- Laboratory resources: reagent inventory, rooms and storage locations, machines, and reservations
- Connected workflows: QR codes, mobile record lookup, quick updates, requests, and laboratory chat
- Labels and printing: label design, templates, QR labels, and printer support
- Administration: users, permissions, backups, settings, and database setup
- Laboratory tools: a completed randomizer and additional practical tools still to be developed

The Culture Collection and Fish Facility are mostly implemented. Current work is focused on polishing their workflows and adding useful tools rather than expanding them with unnecessary complexity. Machines and Reservations still need clearer layouts and faster day-to-day workflows. Label printing also needs better compatibility with legacy printers.

The planned improvements and known gaps are tracked in the [project roadmap](TODO.md).

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

LIMSphere is under active development and is not yet presented as a finished production release. The main Culture Collection and Fish Facility workflows are in place, while usability improvements, visual consistency, machines, reservations, laboratory tools, mapping, and legacy-printer support remain active priorities.

See [TODO.md](TODO.md) for the detailed roadmap and current implementation status.

## Repository

[github.com/rubenluz/LIMSphere](https://github.com/rubenluz/LIMSphere)
