-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;

-- Road network edges table
CREATE TABLE edges (
  id BIGINT PRIMARY KEY,
  source BIGINT,
  target BIGINT,
  distance_m FLOAT,
  air_pm25 FLOAT DEFAULT 0,
  accident_risk FLOAT DEFAULT 0,
  geom geometry(LineString, 4326)
);

-- Create spatial index on geometry column
CREATE INDEX edges_geom_idx ON edges USING GIST (geom);

-- Create indexes for routing
CREATE INDEX edges_source_idx ON edges(source);
CREATE INDEX edges_target_idx ON edges(target);

-- Weight computation SQL storage table
CREATE TABLE weights (
  id INT PRIMARY KEY DEFAULT 1,
  fn TEXT,
  generated_on DATE
);

-- Create view for edge costs with the current weight function
CREATE OR REPLACE VIEW vw_edge_costs AS
SELECT 
  id, 
  source, 
  target, 
  distance_m,
  air_pm25,
  accident_risk,
  CASE 
    WHEN w.fn IS NOT NULL THEN
      (SELECT eval_sql(w.fn, e.distance_m, e.air_pm25, e.accident_risk))
    ELSE
      distance_m -- Default to distance if no weight function
  END AS cost,
  geom
FROM 
  edges e,
  (SELECT fn FROM weights ORDER BY generated_on DESC LIMIT 1) w;

-- User route request history
CREATE TABLE route_requests (
  id SERIAL PRIMARY KEY,
  user_id TEXT,
  home_lat FLOAT,
  home_lon FLOAT,
  work_lat FLOAT,
  work_lon FLOAT,
  distance_m FLOAT,
  distance_optimal_m FLOAT,
  pm25_reduction_pct FLOAT,
  request_time TIMESTAMP DEFAULT NOW()
);

-- Function to evaluate SQL weight expressions
CREATE OR REPLACE FUNCTION eval_sql(sql_expr TEXT, distance_m FLOAT, air_pm25 FLOAT, accident_risk FLOAT)
RETURNS FLOAT AS $$
DECLARE
  result FLOAT;
BEGIN
  EXECUTE 'SELECT ' || sql_expr INTO result USING distance_m, air_pm25, accident_risk;
  RETURN result;
EXCEPTION WHEN OTHERS THEN
  -- If the expression fails, return distance as fallback
  RETURN distance_m;
END;
$$ LANGUAGE plpgsql; 