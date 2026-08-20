# TODO

This roadmap keeps LIMSphere focused on improving the workflows and pages that already exist. New standalone pages are not currently planned; related features should be added to the existing domain pages where they are useful.

## Current priorities

### Permissions and security

- [x] Enforce action permissions for view, create, edit, delete, approve, export, print, and bulk updates.
- [ ] Enforce record scope in queries and actions: own, team, institution, or all records.
- [ ] Apply record-lock and workflow-state restrictions to edit flows.
- [ ] Apply publication and collection-responsibility rules where relevant.

### Culture collection

- [ ] Improve strain and sample filtering, saved views, and bulk actions.
- [ ] Add managed image and file attachments to strain and sample details.
- [x] Link sample and strain details in both directions and support linked quick requests.
- [ ] Extend related-record navigation to managed files, sequences, and other downstream records.
- [ ] Add clear public/private, cryopreservation, and distribution status fields.
- [x] Add map-based sample GPS selection with synchronized GPS, latitude, and longitude fields.
- [ ] Improve imports, exports, and broader validation of collection metadata and GPS coordinates.
- [ ] Complete the requested-strains workflow using the existing schema and Requests page.

### Fish facility

- [ ] Improve stock filters, lineage links, and movement, mortality, and health history.
- [ ] Improve fish-line pedigree, linked stocks, breeding records, and cryopreservation details.
- [ ] Add tank occupancy history, capacity warnings, and safer transfer workflows.
- [x] Let users choose monitored Water QC maintenance items and hide disabled items from the overview.
- [ ] Improve Water QC reports, attachments, trends, and links to affected tanks or stocks.

### Resources and inventory

- [ ] Add reagent reorder thresholds, lot tracking, stock history, and document attachments.
- [ ] Show low-stock and reorder information within the existing Reagents page and dashboard.
- [ ] Improve machine maintenance, calibration, usage, reservations, and file history.
- [x] Add stable room and child-location codes and show them in reagent location selectors.
- [x] Allow reagents to be stored at room level or at a specific child location.
- [ ] Improve storage hierarchy, barcode retrieval, occupancy, and chain-of-custody history.

### Navigation and daily work

- [ ] Improve the existing dashboard with pending work, low stock, maintenance, approvals, and collection summaries.
- [ ] Add global search across core records, with results grouped by type.
- [ ] Add saved filters and recent records to existing list pages where they provide value.
- [x] Make QR scanning open the relevant existing record and offer safe quick actions.
- [x] Keep mobile workflows focused on scanning, lookup, and quick updates.

### Traceability and administration

- [x] Give core entities canonical LIMSphere QR links and route scans to verified existing records.
- [ ] Complete printable-label coverage and presets for every core entity category.
- [ ] Improve audit history with record filters and clearer old/new value comparisons.
- [ ] Add required-field and data-quality settings for important metadata.
- [ ] Improve backup validation and standards-oriented export packages.
- [x] Add a compact user list and confirmed, safeguarded user deletion.
- [ ] Finish and polish the tools that already exist.

## Completed foundation

- [x] Add JSON-backed granular permissions alongside legacy module permissions.
- [x] Add admin-only permission editing to user details.
- [x] Support page access, actions, record scope, publication access, responsibility scope, record-lock bypass, and workflow states in the permission model.
- [x] Restrict role and permission editing to administrators.
- [x] Use the shared permission resolver for menu visibility, access checks, and Requests behavior.

## Later, only if required

These are possible extensions, not commitments. They should first be implemented inside an existing page or detail view. A new page should only be introduced when the workflow becomes too large or distinct to fit clearly into the current interface.

- Taxonomy and sequence management
- Advanced cross-table reporting
- Public catalog and external distribution portal
- Geographic collection explorer
- Molecular or phenotypic comparison tools
- External client and compliance-document management
