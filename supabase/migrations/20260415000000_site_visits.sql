-- 20260415000000_site_visits.sql
-- Create site_visits table
CREATE TABLE IF NOT EXISTS public.site_visits (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  landlord_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  visit_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined')),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.site_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Site visits policies
DO $$ BEGIN
  CREATE POLICY "Users can view their own visits" ON public.site_visits FOR SELECT USING (auth.uid() = user_id OR auth.uid() = landlord_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can create their own visits" ON public.site_visits FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Landlords can update their property visits" ON public.site_visits FOR UPDATE USING (auth.uid() = landlord_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Notifications policies
DO $$ BEGIN
  CREATE POLICY "Users can view their notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Drop the insecure public insert policy
DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;

DO $$ BEGIN
  CREATE POLICY "Users can update their notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Trigger to automatically create notifications on site visit insert or update
CREATE OR REPLACE FUNCTION handle_site_visit_change()
RETURNS TRIGGER AS $$
DECLARE
  p_title text;
BEGIN
  -- Get property title
  SELECT title INTO p_title FROM public.properties WHERE id = NEW.property_id;

  IF (TG_OP = 'INSERT') THEN
    -- Notify the landlord when a user requests a visit
    INSERT INTO public.notifications (user_id, message)
    VALUES (NEW.landlord_id, 'New site visit request received for "' || COALESCE(p_title, 'Property') || '".');
  ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
    -- Notify the tenant when the landlord approves/declines
    INSERT INTO public.notifications (user_id, message)
    VALUES (NEW.user_id, 'Your site visit request for "' || COALESCE(p_title, 'Property') || '" has been ' || NEW.status || '.');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_site_visit_change
  AFTER INSERT OR UPDATE ON public.site_visits
  FOR EACH ROW
  EXECUTE FUNCTION handle_site_visit_change();

