-- Create app_user role for local dev (matches prod)
DO $$ BEGIN
    CREATE ROLE app_user WITH LOGIN PASSWORD 'app_user';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

GRANT ALL PRIVILEGES ON DATABASE pattern_db TO app_user;
