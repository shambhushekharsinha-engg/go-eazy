-- Migration: 20260726000002_issue_1025.sql
-- Description: Drop old policy and add admin-inclusive policy for service-documents

DROP POLICY IF EXISTS "Providers can view their own documents" ON storage.objects;

CREATE POLICY "Providers and Admins can view service documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'service-documents' AND (
      auth.uid()::text = (storage.foldername(name))[1] OR
      EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND role = 'admin'
      )
    )
  );
