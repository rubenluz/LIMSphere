# TODO

## 1. Main Index / Navigation

- [ ] Add a real home/index page for each major domain instead of relying only on sidebar navigation:
  - Meaning: each top-level domain in the sidebar should have its own landing page, so users can enter that area through a proper home screen instead of only expanding a menu and choosing a child page.
  - Common behavior for every domain index:
    - show a small summary of the most important entities in that domain
    - show quick actions for the most common create/import/operational tasks
    - show recent activity / pending work / alerts
    - provide clear links into the main child pages of that domain
    - act as the first page when the user enters that domain from the sidebar
  - [ ] Culture Collection index
    - purpose: first-stop page for strains, samples, SOPs, requests, and collection operations
    - should include: summary cards, quick actions, pending work, and links to key collection pages
    - implementation checklist:
      - [ ] add a Culture Collection home entry/page
      - [ ] show counts/status for strains, samples, requested strains, and collection readiness
      - [ ] add quick actions for new strain, new sample, import, export, taxonomy, and sequence work
      - [ ] add links to Strains, Samples, SOPs, and Requests
  - [ ] Fish Facility index
    - purpose: first-stop page for stocks, tanks, fish lines, water QC, and facility operations
    - should include: facility KPIs, action shortcuts, alerts, and links to the main fish pages
    - implementation checklist:
      - [ ] add a Fish Facility home entry/page
      - [ ] show counts/status for active tanks, fish stocks, fish lines, breeding groups, and health alerts
      - [ ] add quick actions for breeding, transfers, cryo, health review, and reserve/distribution tasks
      - [ ] add links to Stocks, Tank Map, Fish Lines, Water QC, and SOPs
  - [ ] Resources index
    - purpose: first-stop page for lab spaces, locations, reagents, machines, reservations, and inventory work
    - should include: stock alerts, maintenance/reorder summaries, shortcuts, and links to the main resource pages
    - implementation checklist:
      - [ ] add a Resources home entry/page
      - [ ] show counts/status for locations, reagents, machines, reservations, and reorder needs
      - [ ] add quick actions for low inventory review, maintenance due, calibration due, and space usage
      - [ ] add links to Lab Map, Rooms & Locations, Reagents, Machines, and Reservations
  - [ ] Admin index
    - purpose: first-stop page for system management instead of making admins jump directly into Users/Settings/Audit
    - should include: pending approvals, permission/configuration shortcuts, audit visibility, and backup/admin actions
    - implementation checklist:
      - [ ] add an Admin home entry/page
      - [ ] show counts/status for pending users, audit issues, backup state, and configuration tasks
      - [ ] add quick actions for user review, settings, audit log, backups, and permission management
      - [ ] add links to Users, Settings, Audit Log, and Backups
- [ ] Add a desktop-first workspace mode and a phone-first quick-update mode with simpler scan-driven navigation.
- [ ] Add one global cross-table search from the main index, with results grouped by entity type.
- [ ] Add saved searches / saved filters / recent searches.
- [ ] Add "related records" navigation from search results, not only from inside detail pages.
- [ ] Add a "published/public/private/restricted" badge system in navigation and record chips.
- [ ] Add a "favorites / pinned views / recent records" area on the index.
- [ ] Add user-selectable page/view presets so each role can open directly into its most-used view.
- [ ] Add a universal QR/barcode action launcher so every entity can be opened, edited, moved, counted, or labeled from scan results.
- [ ] Add a clear "Catalog / Distribution" entry in the main index if public-facing strain access is part of scope.
- [ ] Add a "Today / Operations" index view for pending updates, low stock, reorders, overdue actions, and recent scan activity.

## 2. Dashboard Page

- [ ] Add stronger collection-management KPIs:
  - total strains
  - public strains
  - available-for-distribution strains
  - cryopreserved strains
  - pending requested strains / shipments
  - pending compliance actions
- [ ] Add map-based widgets for sample/strain geographic origin.
- [ ] Add saved analytics layouts per user or per institution profile.
- [ ] Add pivot-style widgets and deeper drill-down from cards/charts.
- [ ] Add quick links to saved query dashboards, not only static widgets.
- [ ] Add operational widgets for reorder alerts, pending approvals, overdue maintenance, and records missing QR/GPS metadata.

## 3. Culture Collection Index

- [ ] Create a landing page summarizing Strains, Samples, SOPs, imports, exports, and distribution.
- [ ] Make this the default entry page for the Culture Collection domain, not just a secondary page hidden behind the sidebar.
- [ ] Add a top summary area with:
  - total strains
  - total samples
  - pending requested strains
  - public/published strains
  - cryopreserved strains
- [ ] Add shortcuts for:
  - new strain
  - new sample
  - import
  - export
  - taxonomy browser
  - sequence browser
  - requested strains
- [ ] Add a recent/pending work area for:
  - recent imports
  - recent strains/samples
  - pending transfers
  - records missing key metadata
- [ ] Add status summaries for accession, deposit, cryo, public release, and distribution readiness.

## 4. Strains Page

- [ ] Add a true advanced query builder across linked data, not only table filters.
- [ ] Add saved views and reusable filter presets.
- [ ] Add bulk actions for:
  - publish/unpublish
  - mark available/unavailable for distribution
  - export to MIRRI / Darwin Core / NCBI-oriented formats
  - bulk label printing
- [ ] Add visible badges/columns for sequence availability, cryo status, public status, view maps with GPS coordinates and distribution status.
- [ ] Add image thumbnail support directly in the grid.
- [ ] Add stronger cross-links to samples, files, requests, sequences, and publications.
- [ ] Add a "compare selected strains" workflow as a first step toward advanced identification/comparison tooling.

## 5. Strain Detail Page

- [ ] Add a related-record sidebar or tab set for:
  - taxonomy
  - sequences
  - cryopreservation
  - images/media
  - requested strains / distribution
  - publications / external links
  - audit/history
- [ ] Replace URL-only photo fields with managed image attachments and gallery previews.
- [ ] Add a structured provenance timeline: isolation, deposit, publication, release, shipment, updates.
- [ ] Add compliance workflow panels for MTA, Nagoya, restrictions, and approvals.
- [ ] Add explicit public release controls and preview of what is safe to publish.
- [ ] Add comparison / identification entry points for future molecular or polyphasic workflows.
- [ ] Add richer external identifier support for GenBank and related repositories.

## 6. Samples Page

- [ ] Add stronger specimen/event search around collector, date, locality, habitat, and preservation.
- [ ] Add batch imports with reusable templates and import history.
- [ ] Add map filters and locality clustering for geographic-origin exploration.
- [ ] Add a split list/map workflow crossing sample GPS coordinates with locality, project, and derived-strain filters.
- [ ] Add bulk export for standards-oriented specimen data.
- [ ] Add quick navigation from samples to derived strains and vice versa.

## 7. Sample Detail Page

- [ ] Add a structured specimen event section closer to collection-management systems:
  - collecting event
  - locality hierarchy
  - coordinates
  - environment / habitat
  - preservation chain
- [ ] Add attached media instead of plain text-only references where missing.
- [ ] Add a "derived records" panel showing linked strains, extractions, files, and downstream analyses.
- [ ] Add specimen map preview and location validation tools.
- [ ] Add mobile GPS capture/update actions for field sampling and one-tap open-in-map behavior.
- [ ] Add public/private publication controls for specimen-level metadata.
- [ ] Add sample/location tools:
  - coordinate cleaner/validator
  - GPS import helper
  - map preview helper

## 8. Fish Facility Index

- [ ] Create a proper Fish Facility landing page summarizing Stocks, Tank Map, Fish Lines, Water QC, and SOPs.
- [ ] Make this the default entry page for the Fish Facility domain, not just a secondary page hidden behind the sidebar.
- [ ] Add a top summary area with:
  - total active tanks
  - total fish stocks
  - total fish lines
  - active breeding groups
  - health or quarantine flags
- [ ] Add shortcuts for breeding, transfers, cryo, health review, and distribution/reserve stock tasks.
- [ ] Add a recent/pending work area for:
  - recent transfers
  - recent mortality/health events
  - tanks needing cleaning/review
  - upcoming breeding tasks
- [ ] Add overview KPIs for total active tanks, fish counts, breeding groups, health flags, and cryo coverage.

## 9. Fish Stocks Page

- [ ] Add saved views and advanced filters by lineage, life stage, health, breeding status, cryo status, and responsible person.
- [ ] Add better lineage navigation from stock to line to parents to derived offspring groups.
- [ ] Add bulk actions for transfers, labeling, status changes, and reserve/distribution preparation.
- [ ] Add stronger history views for movement, mortality, and health changes.

## 10. Stock Detail Page

- [ ] Add linked record panels for:
  - fish line
  - breeding events
  - movement history
  - mortality history
  - health/treatment history
  - cryo/reserve stock
- [ ] Add a stock timeline view.
- [ ] Add attachment/media support for notes, pathology, or treatment evidence if needed.
- [ ] Add availability/distribution flags if fish materials or lines are to be shared externally.
- [ ] Add clearer QR/barcode-driven workflows for stock actions.

## 11. Tank Map Page

- [ ] Add occupancy history and movement history per position.
- [ ] Add schedule overlays for cleaning, breeding, quarantine, and health review.
- [ ] Add drag/drop or guided move workflows with validation rules.
- [ ] Add capacity warnings and operational analytics by rack/room.

## 12. Fish Lines Page

- [ ] Add stronger genotype/pedigree views.
- [ ] Add a proper lineage tree / parent-offspring graph.
- [ ] Add cryopreservation inventory and reserve-stock tracking.
- [ ] Add publication, barcode, external-ID, and distribution status summaries.
- [ ] Add sequence/genotype attachment support if fish lines need molecular backing.

## 13. Fish Line Detail Page

- [ ] Add a dedicated pedigree visual.
- [ ] Add cryo and barcode sections as first-class panels.
- [ ] Add linked stocks, breeding events, publications, and attached documents/media.
- [ ] Add a release/distribution readiness workflow if lines are shared externally.

## 14. Water QC Page

- [ ] Add stronger file/report attachment support.
- [ ] Add import pipelines from instruments where relevant.
- [ ] Add better long-range trend analytics and report templates.
- [ ] Add exception workflows tied to tanks/lines/stocks when water quality events affect them.

## 15. Resources Index

- [ ] Create a proper Resources landing page summarizing Lab Map, Locations, Reagents, Machines, and Reservations.
- [ ] Make this the default entry page for the Resources domain, not just a secondary page hidden behind the sidebar.
- [ ] Add a top summary area with:
  - total tracked locations
  - low-stock reagents
  - machines due for maintenance/calibration
  - current/upcoming reservations
  - items below reorder threshold
- [ ] Add shortcuts for stock management, low inventory, calibration due, maintenance due, and space utilization.
- [ ] Add a recent/pending work area for:
  - recently updated inventory items
  - overdue maintenance/calibration
  - pending reservations
  - reorder actions that need review
- [ ] Add a dedicated material reorder summary area showing what needs ordering now, what is pending, and what is overdue.

## 16. Lab Map Page

- [ ] Add richer navigation between physical spaces and stored biological materials.
- [ ] Add deeper visual overlays for freezers, cryo, quarantine, and restricted-access zones.
- [ ] Add cross-links from map zones to stored specimens/materials.

## 17. Rooms & Locations Page

- [ ] Add more collection-oriented storage modeling:
  - freezer -> shelf -> box -> position
  - cryo storage hierarchy
  - barcode scanning for retrieval
- [ ] Add chain-of-custody history for stored materials.
- [ ] Add occupancy and free-capacity analytics.

## 18. Reagents Page

- [ ] Add stronger stock-management workflows:
  - reorder rules
  - lot/batch lineage
  - supplier/client document links
  - invoice/order linkage
- [ ] Add min/max/par-level tracking, vendor lead time, reorder quantity suggestions, and "days left" estimates.
- [ ] Add attachment support for SDS, certificates, and QC documents.
- [ ] Add batch receive / consume / discard workflows.

## 19. Machines Page

- [ ] Add more instrument-centered attachment/import support.
- [ ] Add direct links between machines and generated data/files.
- [ ] Add richer calibration/maintenance/event history.
- [ ] Add reservation + usage + output traceability on one page.

## 20. Reservations Page

- [ ] Add project/experiment linkage.
- [ ] Add approval workflows and reservation policies.
- [ ] Add attachment or note support for experiment context and output references.

## 21. Labels Page

- [ ] Add more reporting/template behavior:
  - collection labels
  - shipment labels
  - barcode/QR templates per entity type
  - standards-aware specimen labels
- [ ] Add template presets tied to public catalog, cryo, shipment, and accession workflows.
- [ ] Ensure every major entity has a QR code and printable label flow by default, not just selected modules.

## 22. Tools Page

- [ ] Finalize the tools that already exist but still feel partial or isolated.
- [ ] Add a proper tools index with categories like calculations, planning, validation, labels, and imports.

## 23. Requests Page

- [ ] Split generic internal requests from true culture-collection distribution workflows.
- [ ] Build a real `Requested Strains` UI on top of the existing schema foundation in [lib/supabase/core_tables_sql.dart](</c:/Users/ruben/Documents/blue_open_lims/lib/supabase/core_tables_sql.dart:369>).
- [ ] Add workflow states for:
  - received
  - reviewed
  - approved
  - prepared
  - shipped
  - completed
  - refused
- [ ] Add requester/institution details, MTA, Nagoya, shipment, tracking, viability, and batch metadata.
- [ ] Add an operator view for pending compliance and shipment actions.
- [ ] Add a customer-facing/public-request path if public catalog distribution is in scope.

## 24. Chat Page

- [ ] Add record-scoped comments/discussions on strains, samples, stocks, and requests.
- [ ] Add mentionable links to records and change events.
- [ ] Add a way to turn discussions into tasks or requests.

## 25. Audit Log Page

- [ ] Extend auditability and record-history tracking:
  - easier record history drill-down
  - compare old vs new values
  - filter by page/entity/user/date
  - better export
- [ ] Add undo/rollback support for selected admin-safe actions where feasible.

## 26. Users Page

Done now

- [x] Add a JSON-backed granular permission model on top of the legacy per-module permission columns.
- [x] Add admin-only editing of granular page rules in the user detail page.
- [x] Add configurable page-level controls for:
  - page access
  - actions
  - record scope
  - publication access
  - responsibility scope
  - record-lock bypass
  - workflow edit states
- [x] Restrict role and permission editing so only admins can change user access, while users can still edit their own profile fields.
- [x] Wire the shared permission resolver into menu visibility / access checks and the requests page behavior.

Foundation done, enforcement still needed

- [ ] Extend granular permissions from page-level control to true record-level enforcement.
- [ ] Enforce action-level permissions separately across all pages for:
  - view
  - insert
  - edit
  - delete
  - approve
  - export
  - print
  - bulk-update
- [ ] Enforce scope-aware permissions in queries and actions:
  - own records
  - team records
  - institution records
  - all records
- [ ] Enforce publication-access rules in real publication / catalog workflows.
- [ ] Enforce record-lock and workflow-state restrictions in actual edit flows so some records are editable only in allowed statuses.
- [ ] Enforce institution / collection responsibility scopes in actual record ownership and responsibility workflows.

Not started yet

- [ ] Add external/public roles if catalog publication is introduced.

## 27. Settings Page

- [ ] Add metadata-driven configuration for fields, forms, columns, and visibility.
- [ ] Add schema/admin tools for a more configurable data-model approach.
- [ ] Add export profile configuration for MIRRI / Darwin Core / NCBI / custom templates.
- [ ] Add publication settings for public catalog exposure.
- [ ] Add per-page view presets and dashboard presets.
- [ ] Add a permission matrix editor for page-level, record-level, and action-level access rules.
- [ ] Add device-specific configuration for desktop dense views vs phone quick-update views.
- [ ] Add required-field/data-quality rules, including QR required and GPS required where relevant.

## 28. Backups Page

- [ ] Add standards-oriented export packages in addition to raw local backups.
- [ ] Add named snapshot exports for collection release, partner sharing, and public catalog publishing.
- [ ] Add restore-preview and validation tooling.

## 29. New Pages Needed

- [ ] Taxonomy page
  - hierarchical taxonomy browser
  - synonym handling
  - nomenclature updates
- [ ] Sequence page
  - linked DNA/RNA/protein records
  - FASTA import/export
  - alignment/BLAST integration hooks
  - trace-file storage roadmap
- [ ] Preservation / Cryo page
  - cryovials
  - methods
  - locations
  - recovery / viability checks
- [ ] Images / Media page
  - central media library
  - thumbnails
  - measurements/annotations later if needed
- [ ] Requested Strains / Distribution page
  - dedicated operational workflow for outgoing material
- [ ] Clients / Institutions page
  - recipients
  - collaborators
  - contact history
- [ ] MTA / Compliance Documents page
  - agreements
  - permits
  - signatures
  - review status
- [ ] Query Builder / Reports page
  - saved cross-table queries
  - templated reports
  - export profiles
- [ ] Material Reorder page
  - items below minimum
  - reorder suggestions
  - purchase status
  - vendor tracking
  - pending deliveries
  - received vs ordered history
- [ ] Public Catalog / Web Publication page
  - publish selected records
  - search portal
  - request/cart workflow
- [ ] GIS / Geographic Explorer page
  - map-based browsing of samples/strains by origin
  - GPS quality checks
  - layer filters by project, collector, period, and taxon
- [ ] Access Control / Permissions page
  - page matrix
  - record scope rules
  - action-level permissions
  - status locks
- [ ] Mobile Scan / Rapid Update page
  - scan inbox
  - quick actions by QR
  - fast count/update flows
  - offline capture queue
- [ ] Identification / Comparison workspace
  - phased roadmap toward phenotypic + molecular comparison tools

## 30. Highest-Value First Wave

- [ ] Build Culture Collection index.
- [ ] Build Fish Facility index.
- [ ] Build Resources index.
- [ ] Build Admin index.
- [ ] Build the Mobile Scan / Rapid Update flow for phone use.
- [ ] Make QR code coverage mandatory for all core entities.
- [ ] Add global search + saved views.
- [ ] Add Requested Strains page on top of the existing schema.
- [ ] Add Material Reorder page and reorder alerts.
- [ ] Add action-level permissions and a permission matrix editor.
- [ ] Add Taxonomy page and Sequence page.
- [ ] Add managed file/image attachments for strains and samples.
- [ ] Add public/private/publication workflow for strains and samples.
- [ ] Add map/geographic browsing for sample and strain origin.
- [ ] Add standards-aware exports and reporting templates.
