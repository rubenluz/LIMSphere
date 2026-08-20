# TODO

This roadmap keeps LIMSphere focused on a simple and connected laboratory workflow. Features should improve daily work without making the application harder to understand, configure, or maintain. Existing pages should be improved before new standalone pages are introduced.

## Product principles

- Keep setup straightforward for a laboratory administrator.
- Use the same layout, actions, terminology, and interaction patterns across all pages.
- Prefer clear, fast workflows over complex scientific traceability features.
- Connect records across modules so users do not need to enter or find the same information repeatedly.
- Make QR codes useful across desktop and mobile for lookup and quick updates.
- Add tools only when they solve a real laboratory task.

## Current priorities

### Culture collection polish

- [x] Link samples and strains in both directions.
- [x] Add map-based GPS selection with synchronized GPS, latitude, and longitude fields.
- [ ] Add a Samples overview-map button at appbar that plots all sample locations.
- [ ] Let the overview map filter points by geographic location and by selected samples.
- [ ] Let the map show or filter strains by inferring their locations from linked samples.
- [ ] Improve sample and strain filters, saved views, bulk actions, and related-record navigation.
- [ ] Improve imports, exports, attachments, and validation of collection metadata and coordinates.
- [ ] Polish the existing Culture Collection tools and workflows instead of adding unnecessary pages.

### Fish facility polish

- [ ] Improve stock filters, fish-line links, tank workflows, and movement history.
- [ ] Improve breeding, mortality, health, pedigree, and cryopreservation workflows.
- [ ] Add clearer tank occupancy and capacity warnings.
- [x] Let users configure monitored Water QC maintenance items.
- [ ] Improve Water QC reports, trends, attachments, and links to affected tanks or stocks.
- [ ] Review all Fish Facility pages for consistent layout and faster routine data entry.

### Machines and reservations

- [ ] Redesign Machine list and detail layouts for clearer maintenance, calibration, files, and usage information.
- [ ] Simplify creating, editing, and reviewing reservations.
- [ ] Make machine availability and reservation conflicts immediately visible.
- [ ] Reduce the number of steps required for common machine and reservation tasks.
- [ ] Align both areas with the shared layout used by the rest of LIMSphere.

### Reagents and storage

- [x] Support stable room and child-location codes.
- [x] Allow reagents to be stored at room level or in a child location.
- [ ] Improve reagent stock levels, reorder warnings, lots, suppliers, and stock history.
- [ ] Improve room and storage navigation, occupancy information, and barcode lookup.
- [ ] Show useful low-stock information on the Reagents page and dashboard.

### Laboratory tools

- [x] Complete the randomizer.
- [ ] Define the small set of additional tools that laboratories genuinely need.
- [ ] Implement each tool with the same simple layout and clear inputs/outputs.
- [ ] Avoid adding tools that duplicate existing workflows or increase complexity without a clear benefit.

### Labels and legacy printers

- [ ] Investigate and document the current failures with legacy label printers.
- [ ] Improve printer detection, connection feedback, and actionable error messages.
- [ ] Add compatible output settings or drivers for supported legacy printers.
- [ ] Test label dimensions, QR readability, alignment, and print density on real hardware.
- [ ] Complete useful label presets for core LIMSphere records.

### Connected desktop and mobile workflows

- [x] Give core records canonical LIMSphere QR links.
- [x] Open verified records from QR scans.
- [x] Keep mobile workflows focused on scanning, lookup, and quick updates.
- [ ] Review quick-update actions for samples, strains, fish stocks, reagents, machines, and rooms.
- [ ] Ensure links between modules always open the correct detail page.
- [ ] Keep global search fast, clear, and consistent with QR navigation.

### Consistency and setup

- [ ] Create and apply a shared list-page layout across all modules.
- [ ] Create and apply a shared detail-page layout across all modules.
- [ ] Standardize filters, dialogs, empty states, loading states, forms, and save feedback.
- [ ] Simplify first-run database setup and explain failures in plain language.
- [ ] Review mobile and desktop layouts together for every major workflow.
- [ ] Keep documentation aligned with the actual implemented state.

## Completed foundation

- [x] Add granular user permissions and admin permission editing.
- [x] Use shared access checks for menu visibility and page actions.
- [x] Connect the Culture Collection, Fish Facility, resources, users, requests, chat, labels, and QR workflows to the same Supabase-backed application.
- [x] Add desktop management layouts and mobile QR scanning.

## Later, only if clearly needed

These are possible extensions, not commitments. They should only be developed when laboratories have a clear workflow that requires them.

- Advanced cross-table reports
- Public collection catalog or distribution portal
- Sequence, molecular, or phenotypic comparison tools
- External client integrations
