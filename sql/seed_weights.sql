-- Insert a safe default weight formula
-- This weights pollution and safety higher than distance
-- Format: distance_m + (air_pm25 * 3) + (accident_risk * 2)
INSERT INTO weights (id, fn, generated_on)
VALUES (
  1, 
  'distance_m + (air_pm25 * 3) + (accident_risk * 2)', 
  CURRENT_DATE
)
ON CONFLICT (id) DO UPDATE
SET 
  fn = EXCLUDED.fn,
  generated_on = EXCLUDED.generated_on;

-- Create a materialized view for faster route computation
-- This will be refreshed nightly after the weight function is updated
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_edge_costs AS
SELECT * FROM vw_edge_costs;

-- Create indexes on the materialized view for faster routing
CREATE INDEX IF NOT EXISTS mv_edge_costs_source_idx ON mv_edge_costs(source);
CREATE INDEX IF NOT EXISTS mv_edge_costs_target_idx ON mv_edge_costs(target); 