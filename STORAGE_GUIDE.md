# 🖼️ Supabase Storage Implementation Guide

## 📚 Fitur Storage yang Diterapkan

### Berdasarkan Dokumentasi Resmi Supabase:

✅ **Upload File** - `storage.from('bucket').uploadBinary()`
✅ **Download/Display** - `storage.from('bucket').getPublicUrl()`
✅ **Delete File** - `storage.from('bucket').remove()`
✅ **Public Bucket** - Untuk akses gambar tanpa auth
✅ **Row Level Security** - User hanya bisa manage file mereka sendiri
✅ **Image Picker** - Pilih gambar dari galeri
✅ **Image Preview** - Tampilkan gambar dengan InteractiveViewer

---

## 🚀 Setup Storage di Supabase

### 1. Buat Storage Bucket

**Opsi A: Via Dashboard (Recommended)**
1. Buka **Supabase Dashboard**
2. Pergi ke **Storage**
3. Klik **New bucket**
4. Nama: `notes-images`
5. ✅ Centang **Public bucket**
6. Klik **Create bucket**

**Opsi B: Via SQL**
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('notes-images', 'notes-images', true);
```

### 2. Setup Storage Policies (RLS)

Jalankan di **SQL Editor**:

```sql
-- Policy: Semua user bisa lihat gambar (public bucket)
CREATE POLICY "Public Access"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'notes-images');

-- Policy: User hanya bisa upload ke folder mereka
CREATE POLICY "Users can upload their own images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Policy: User hanya bisa update file mereka
CREATE POLICY "Users can update their own images"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Policy: User hanya bisa delete file mereka
CREATE POLICY "Users can delete their own images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

### 3. Update Tabel Notes

Tambahkan kolom `image_url`:

```sql
ALTER TABLE notes ADD COLUMN IF NOT EXISTS image_url TEXT;
```

---

## 💻 Implementasi di Flutter

### 1. Upload Image

```dart
Future<String?> _uploadImage(Uint8List imageBytes, String fileName) async {
  final userId = supabase.auth.currentUser?.id;
  final filePath = '$userId/$fileName';
  
  // Upload dengan uploadBinary untuk web compatibility
  await supabase.storage.from('notes-images').uploadBinary(
    filePath,
    imageBytes,
    fileOptions: const FileOptions(
      cacheControl: '3600',
      upsert: false,
    ),
  );

  // Get public URL
  final imageUrl = supabase.storage
      .from('notes-images')
      .getPublicUrl(filePath);
  
  return imageUrl;
}
```

### 2. Pick Image from Gallery

```dart
final ImagePicker _picker = ImagePicker();

Future<Map<String, dynamic>?> _pickImage() async {
  final XFile? image = await _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );

  if (image != null) {
    final bytes = await image.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
    return {'bytes': bytes, 'fileName': fileName};
  }
  return null;
}
```

### 3. Display Image

```dart
// List view
Image.network(
  imageUrl,
  height: 200,
  width: double.infinity,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) =>
      Icon(Icons.broken_image),
)

// Full view with zoom
InteractiveViewer(
  child: Image.network(imageUrl),
)
```

### 4. Delete Image

```dart
// Parse URL to get file path
final uri = Uri.parse(imageUrl);
final pathSegments = uri.pathSegments;
final bucketIndex = pathSegments.indexOf('notes-images');

if (bucketIndex != -1) {
  final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
  await supabase.storage
      .from('notes-images')
      .remove([filePath]);
}
```

---

## 📁 Struktur File Storage

```
notes-images/
├── {user_id_1}/
│   ├── 1234567890_image1.jpg
│   ├── 1234567891_image2.png
│   └── 1234567892_photo.jpg
├── {user_id_2}/
│   ├── 1234567893_pic1.jpg
│   └── 1234567894_pic2.png
└── ...
```

Setiap user memiliki folder sendiri dengan ID mereka, memastikan isolasi data.

---

## 🔒 Security Features

### 1. **Row Level Security (RLS)**
- User hanya bisa upload/update/delete file di folder mereka
- User bisa melihat semua gambar (public bucket)

### 2. **Folder Isolation**
- File disimpan di: `{user_id}/{filename}`
- RLS check: `(storage.foldername(name))[1] = auth.uid()::text`

### 3. **File Options**
```dart
FileOptions(
  cacheControl: '3600',  // Cache 1 jam
  upsert: false,          // Tidak overwrite existing file
)
```

---

## 📊 Best Practices yang Diterapkan

### ✅ Dari Dokumentasi Supabase Storage:

1. **Upload Binary untuk Web**
   - `uploadBinary()` lebih kompatibel untuk web
   - Langsung terima `Uint8List`

2. **Public Bucket**
   - Gambar bisa diakses tanpa auth
   - Cocok untuk konten publik seperti foto profil/catatan

3. **File Naming**
   - Timestamp + original name
   - Hindari duplikasi: `{timestamp}_{filename}`

4. **Image Optimization**
   ```dart
   maxWidth: 1024,
   maxHeight: 1024,
   imageQuality: 85,
   ```

5. **Error Handling**
   - Try-catch pada setiap operation
   - Error builder untuk broken images
   - User feedback via SnackBar

6. **Loading States**
   - Show progress saat upload
   - Disable button saat loading
   - Clear feedback dengan CircularProgressIndicator

---

## 🎨 UI/UX Features

### 1. **Image Preview**
- Preview sebelum upload
- Remove image option
- Full screen view dengan zoom

### 2. **Upload Progress**
- Loading indicator
- Clear status messages
- Success/error feedback

### 3. **Card with Image**
- Image di atas card
- Tap untuk full view
- Icon indicator untuk notes dengan gambar

---

## 🐛 Troubleshooting

### Error: "Bucket not found"
```bash
Solusi: Buat bucket 'notes-images' di Storage Dashboard
```

### Error: "new row violates row-level security policy"
```bash
Solusi: Jalankan storage policies SQL di atas
```

### Error: "Failed to upload"
```bash
Solusi: 
1. Pastikan bucket public
2. Check storage policies
3. Pastikan folder path sesuai format: {user_id}/{filename}
```

### Gambar tidak tampil
```bash
Solusi:
1. Check bucket public setting
2. Verify image URL di browser
3. Check CORS settings (untuk web)
```

---

## 📖 API Reference

### Upload File
```dart
await supabase.storage
    .from('bucket-name')
    .uploadBinary(path, bytes, fileOptions: options);
```

### Get Public URL
```dart
final url = supabase.storage
    .from('bucket-name')
    .getPublicUrl(path);
```

### Delete File
```dart
await supabase.storage
    .from('bucket-name')
    .remove([path1, path2, ...]);
```

### List Files
```dart
final files = await supabase.storage
    .from('bucket-name')
    .list(path: 'folder/');
```

---

## 🔗 Referensi Dokumentasi

- [Supabase Storage Guide](https://supabase.com/docs/guides/storage)
- [Flutter Storage Reference](https://supabase.com/docs/reference/dart/storage-from-upload)
- [Storage Security](https://supabase.com/docs/guides/storage/security/access-control)
- [Image Picker Package](https://pub.dev/packages/image_picker)

---

## ✨ Features Checklist

- ✅ Upload gambar dari galeri
- ✅ Preview gambar sebelum upload
- ✅ Display gambar di list
- ✅ Full screen image view dengan zoom
- ✅ Update/replace gambar
- ✅ Delete gambar saat delete note
- ✅ Public access untuk display
- ✅ Private upload dengan RLS
- ✅ Error handling & loading states
- ✅ Image compression & optimization
- ✅ Web & mobile compatibility

---

**Happy Coding! 🚀📸**
