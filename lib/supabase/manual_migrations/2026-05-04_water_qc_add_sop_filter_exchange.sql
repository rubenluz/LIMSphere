-- Add SOP filter exchange tracking to Water QC.
-- Run in Supabase SQL Editor against the existing database.

ALTER TABLE water_qc
ADD COLUMN IF NOT EXISTS sop_filter_exchange DATE;

INSERT INTO water_qc_maintenance (key, last_done_date, optimal_days)
SELECT 'sop_filter_exchange', NULL, 30
WHERE NOT EXISTS (
  SELECT 1
  FROM water_qc_maintenance
  WHERE key = 'sop_filter_exchange'
);
