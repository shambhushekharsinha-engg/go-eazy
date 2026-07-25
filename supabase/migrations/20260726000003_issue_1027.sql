-- Migration: 20260726000003_issue_1027.sql
-- Description: Add rating column to public.properties and trigger on public.property_reviews

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS rating numeric(3,2) DEFAULT 0.00;

CREATE OR REPLACE FUNCTION public.update_property_average_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.properties
  SET rating = COALESCE((
    SELECT ROUND(AVG(rating), 2)
    FROM public.property_reviews
    WHERE property_id = COALESCE(NEW.property_id, OLD.property_id)
  ), 0.00)
  WHERE id = COALESCE(NEW.property_id, OLD.property_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE TRIGGER on_review_change
  AFTER INSERT OR UPDATE OR DELETE ON public.property_reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.update_property_average_rating();
