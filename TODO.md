# TODO

This roadmap keeps LIMSphere focused on a simple, connected laboratory workflow. Features should improve daily work without making the application harder to understand, configure, or maintain. Existing pages should be improved before new standalone pages are introduced.

## Current priorities

### Culture collection polish

- [ ] Improve sample and strain filters, saved views, bulk actions, and related-record navigation.
- [ ] Improve imports, exports, attachments, and validation of collection metadata.
- [ ] Improve validation of GPS coordinates.
- [ ] Integrate NCBI GenBank through a custom API and expose available metadata, including record update dates and citations, as read-only Strains columns. Support GCA assemblies and the 18S, ITS2/ITS3, and rbcL accession fields through the same workflow.
- [x] Open GenBank accession buttons directly in NCBI Nucleotide BLAST with the accession prefilled as the query.
- [ ] Connect to AlgaeBase and LPSN to retrieve higher taxonomic ranks, taxonomy updates, and related information.

### Fish facility polish

- [ ] Improve stock filters, fish-line links, tank workflows, and movement history.
- [ ] Improve breeding history, quality checks, mortality, health, and pedigree tracking.
- [ ] Add clearer tank occupancy and capacity warnings.
- [ ] Improve Water QC reports and trends, including possible charts.

### Machines and reservations

- [ ] Redesign Machine list and detail layouts for clearer maintenance, calibration, and usage information.
- [ ] Simplify creating, editing, and reviewing reservations.
- [ ] Make machine availability and reservation conflicts immediately visible.
- [ ] Reduce the number of steps required for common machine and reservation tasks.
- [ ] Align both areas with the shared layout used by the rest of LIMSphere.

### Reagents and storage

- [ ] Improve reagent stock levels and reorder warnings.
- [ ] Improve room and storage navigation, occupancy information, and barcode lookup.
- [ ] Show useful low-stock information on the Reagents page and dashboard, including a new custom dashboard widget.

### Labels and legacy printers

- [ ] Investigate and document the current failures with legacy label printers.
- [ ] Improve printer detection, connection feedback, and actionable error messages.
- [ ] Test label dimensions, QR readability, alignment, and print density on real hardware.
- [ ] Complete useful label presets for core LIMSphere records.

### Update mobile workflows

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
