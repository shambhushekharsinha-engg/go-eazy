-- Migration: 20260726000000_unlocked_rpc_functions.sql
-- Description: Creates the missing RPC functions get_unlocked_property_details and get_unlocked_service_details.

-- 1. Create RPC function get_unlocked_property_details
CREATE OR REPLACE FUNCTION public.get_unlocked_property_details(prop_id uuid)
RETURNS TABLE (
  contact_phone text,
  contact_email text,
  exact_location text
) SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Verify if the requester is the landlord of the property
  -- OR has an active unlock record in unlocked_properties
  IF EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = prop_id AND p.landlord_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.unlocked_properties up
    WHERE up.property_id = prop_id AND up.user_id = auth.uid()
  ) THEN
    RETURN QUERY 
    SELECT p.contact_phone, p.contact_email, p.exact_location
    FROM public.properties p 
    WHERE p.id = prop_id;
  ELSE
    RAISE EXCEPTION 'Access Denied: Property contact details are locked.';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 2. Create RPC function get_unlocked_service_details
CREATE OR REPLACE FUNCTION public.get_unlocked_service_details(prov_id uuid)
RETURNS TABLE (
  contact_phone text,
  contact_email text,
  address text
) SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Verify if the requester is authenticated (logged in)
  -- Note: Service contact details are free but require a user session to unlock.
  IF auth.role() = 'authenticated' THEN
    RETURN QUERY 
    SELECT sp.contact_phone, sp.contact_email, sp.address
    FROM public.service_providers sp 
    WHERE sp.id = prov_id;
  ELSE
    RAISE EXCEPTION 'Access Denied: Please log in to view contact details.';
  END IF;
END;
$$ LANGUAGE plpgsql;
