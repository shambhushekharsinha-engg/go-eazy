-- Migration: Add 72-hour auto-pruning for recently_viewed properties
-- Enable the pg_cron extension first
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1. Create a function that deletes old records
CREATE OR REPLACE FUNCTION delete_old_recently_viewed()
RETURNS void AS $$
BEGIN
  DELETE FROM recently_viewed
  WHERE viewed_at < NOW() - INTERVAL '72 hours';
END;
$$ LANGUAGE plpgsql;

-- 2. Schedule the cleanup job to run every hour using dynamic SQL to avoid parse errors
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Safely unschedule previous iterations of the job
        PERFORM cron.unschedule('cleanup-recently-viewed');
        EXECUTE 'SELECT cron.schedule(''cleanup-recently-viewed'', ''0 * * * *'', ''SELECT delete_old_recently_viewed()'')';
    END IF;
END $$;
