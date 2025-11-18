-- SQL Script untuk membuat tabel notes dengan Storage di Supabase
-- Jalankan script ini di Supabase Dashboard -> SQL Editor

-- Buat tabel notes
CREATE TABLE IF NOT EXISTS notes (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Buat index untuk performa query yang lebih cepat
CREATE INDEX IF NOT EXISTS notes_user_id_idx ON notes(user_id);
CREATE INDEX IF NOT EXISTS notes_created_at_idx ON notes(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Policy: User hanya bisa melihat notes mereka sendiri (READ)
CREATE POLICY "Users can view their own notes"
  ON notes
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: User hanya bisa menambah notes untuk diri mereka sendiri (CREATE)
CREATE POLICY "Users can create their own notes"
  ON notes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: User hanya bisa mengupdate notes mereka sendiri (UPDATE)
CREATE POLICY "Users can update their own notes"
  ON notes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: User hanya bisa menghapus notes mereka sendiri (DELETE)
CREATE POLICY "Users can delete their own notes"
  ON notes
  FOR DELETE
  USING (auth.uid() = user_id);

-- Fungsi untuk auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger untuk auto-update updated_at
CREATE TRIGGER update_notes_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Verifikasi tabel sudah dibuat
SELECT 'Notes table created successfully!' AS status;

-- ==================================================
-- STORAGE BUCKET SETUP
-- ==================================================
-- NOTE: Storage bucket harus dibuat melalui Dashboard atau menggunakan script berikut
-- Jalankan ini di Supabase Dashboard -> Storage -> Create bucket

-- Atau jalankan SQL ini untuk membuat bucket:
INSERT INTO storage.buckets (id, name, public)
VALUES ('notes-images', 'notes-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies untuk bucket 'notes-images'

-- Policy: Semua user bisa SELECT/READ gambar (karena bucket public)
CREATE POLICY "Public Access"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'notes-images');

-- Policy: User hanya bisa upload ke folder mereka sendiri (CREATE)
CREATE POLICY "Users can upload their own images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Policy: User hanya bisa update file di folder mereka sendiri (UPDATE)
CREATE POLICY "Users can update their own images"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Policy: User hanya bisa delete file di folder mereka sendiri (DELETE)
CREATE POLICY "Users can delete their own images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Verifikasi storage setup
SELECT 'Storage policies created successfully!' AS status;
