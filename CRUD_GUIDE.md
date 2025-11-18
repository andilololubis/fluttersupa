# 📝 Flutter Supabase CRUD + Storage - Notes App

Aplikasi manajemen catatan lengkap dengan Authentication, CRUD, dan Storage untuk upload gambar menggunakan Flutter & Supabase.

## ✨ Fitur Lengkap

### 🔐 Authentication
- ✅ Register akun baru dengan email & password
- ✅ Login dengan email & password
- ✅ Logout
- ✅ Session management otomatis
- ✅ Protected routes (hanya user yang login bisa akses)

### 📋 CRUD Operations (Notes)
- ✅ **CREATE** - Tambah catatan baru dengan gambar opsional
- ✅ **READ** - Tampilkan semua catatan user dengan gambar
- ✅ **UPDATE** - Edit catatan dan ganti/hapus gambar
- ✅ **DELETE** - Hapus catatan beserta gambarnya
- ✅ **FILTER** - Hanya tampil catatan milik user yang login (RLS)

### 🖼️ Storage Operations (Images)
- ✅ **UPLOAD** - Upload gambar ke Supabase Storage
- ✅ **DISPLAY** - Tampilkan gambar dari public URL
- ✅ **UPDATE** - Ganti gambar yang sudah ada
- ✅ **DELETE** - Hapus gambar dari storage
- ✅ **PREVIEW** - Preview gambar sebelum upload & full screen view
- ✅ **OPTIMIZATION** - Kompresi gambar otomatis (max 1024x1024, quality 85%)

## 🚀 Setup Database & Storage

### 1. Buat Tabel di Supabase

Buka **Supabase Dashboard** → **SQL Editor** → Jalankan script dari `supabase_setup.sql`:

```sql
-- Buat tabel notes dengan kolom image_url
CREATE TABLE notes (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- RLS Policies untuk notes (sama seperti sebelumnya)
-- ... (lihat supabase_setup.sql)
```

### 2. Buat Storage Bucket

**Cara 1: Via Dashboard (Recommended)**
1. Buka **Supabase Dashboard**
2. Pergi ke **Storage**
3. Klik **New bucket**
4. Nama: `notes-images`
5. ✅ Centang **Public bucket**
6. Klik **Create bucket**

**Cara 2: Via SQL**
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('notes-images', 'notes-images', true);
```

### 3. Setup Storage Policies

```sql
-- Public read access
CREATE POLICY "Public Access"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'notes-images');

-- User dapat upload di folder mereka
CREATE POLICY "Users can upload their own images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- User dapat update file mereka
CREATE POLICY "Users can update their own images"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- User dapat delete file mereka
CREATE POLICY "Users can delete their own images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'notes-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

### 4. Enable Email Authentication

1. Buka **Supabase Dashboard**
2. Pergi ke **Authentication** → **Providers**
3. Pastikan **Email** provider sudah enabled
4. (Opsional) Disable "Confirm email" untuk testing

## 📱 Cara Menjalankan

```bash
# Masuk ke direktori project
cd testproject

# Install dependencies
flutter pub get

# Jalankan aplikasi
flutter run -d chrome    # Untuk web
flutter run -d windows   # Untuk desktop
flutter run              # Pilih device
```

## 🎯 Struktur Kode

### CRUD Operations

#### READ - Fetch Data
```dart
final data = await supabase
    .from('notes')
    .select()
    .eq('user_id', userId)
    .order('created_at', ascending: false);
```

#### CREATE - Insert Data dengan Gambar
```dart
// 1. Upload gambar dulu
final imageUrl = await _uploadImage(imageBytes, fileName);

// 2. Insert note dengan image_url
await supabase.from('notes').insert({
  'user_id': userId,
  'title': title,
  'content': content,
  'image_url': imageUrl,
  'created_at': DateTime.now().toIso8601String(),
});
```

#### UPDATE - Modify Data & Gambar
```dart
// 1. Upload gambar baru jika ada
String? finalImageUrl = existingImageUrl;
if (newImageBytes != null) {
  finalImageUrl = await _uploadImage(newImageBytes, newFileName);
}

// 2. Update note
await supabase
    .from('notes')
    .update({
      'title': newTitle,
      'content': newContent,
      'image_url': finalImageUrl,
    })
    .eq('id', noteId);
```

#### DELETE - Remove Data & Gambar
```dart
// 1. Hapus gambar dari storage
if (note['image_url'] != null) {
  await supabase.storage
      .from('notes-images')
      .remove([filePath]);
}

// 2. Hapus note dari database
await supabase.from('notes').delete().eq('id', noteId);
```

### Storage Operations

#### UPLOAD - Upload Gambar
```dart
Future<String?> _uploadImage(Uint8List imageBytes, String fileName) async {
  final userId = supabase.auth.currentUser?.id;
  final filePath = '$userId/$fileName';
  
  // Upload binary untuk web compatibility
  await supabase.storage.from('notes-images').uploadBinary(
    filePath,
    imageBytes,
    fileOptions: const FileOptions(
      cacheControl: '3600',
      upsert: false,
    ),
  );

  // Get public URL
  return supabase.storage
      .from('notes-images')
      .getPublicUrl(filePath);
}
```

#### PICK - Pilih Gambar
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

#### DISPLAY - Tampilkan Gambar
```dart
// Di ListView
Image.network(
  imageUrl,
  height: 200,
  width: double.infinity,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) =>
      Icon(Icons.broken_image),
)

// Full screen dengan zoom
InteractiveViewer(
  child: Image.network(imageUrl),
)
```

## 🔒 Security Features

### Database (Notes Table)
Setiap user **HANYA** bisa:
- ✅ Lihat catatan mereka sendiri
- ✅ Tambah catatan atas nama mereka sendiri
- ✅ Edit catatan mereka sendiri
- ✅ Hapus catatan mereka sendiri

### Storage (Images Bucket)
Setiap user **HANYA** bisa:
- ✅ Upload ke folder mereka: `{user_id}/{filename}`
- ✅ Update file di folder mereka
- ✅ Delete file di folder mereka
- ✅ Lihat semua gambar (public bucket)

Semua dijamin oleh **Row Level Security (RLS)** policies.

## 🎨 Fitur UI/UX

### Notes Management
- ✨ Material Design 3
- 🔄 Pull to refresh
- ⌛ Loading indicators
- 📢 Snackbar notifications
- ❓ Confirmation dialogs
- 📱 Responsive layout
- 🎯 Empty state handling

### Image Features
- 📸 Pick dari galeri
- 👁️ Preview sebelum upload
- 🖼️ Display gambar di card
- 🔍 Full screen view dengan zoom
- ✏️ Edit/ganti gambar
- 🗑️ Hapus gambar
- ⚠️ Error handling untuk broken images

## 📚 Best Practices yang Diterapkan

### Dari Dokumentasi Supabase:

#### Database & Auth
1. ✅ **Proper initialization** dengan `WidgetsFlutterBinding.ensureInitialized()`
2. ✅ **Auth state streaming** dengan `onAuthStateChange`
3. ✅ **Current session** menggunakan `currentSession` (v2)
4. ✅ **Row Level Security** untuk data protection
5. ✅ **Filtering dengan `.eq()`** untuk query spesifik
6. ✅ **Ordering dengan `.order()`** untuk sorting data

#### Storage
7. ✅ **Upload Binary** dengan `uploadBinary()` untuk web compatibility
8. ✅ **Public bucket** untuk akses gambar tanpa auth
9. ✅ **Folder isolation** dengan `{user_id}/{filename}`
10. ✅ **File options** untuk cache control & upsert
11. ✅ **Public URL** dengan `getPublicUrl()`
12. ✅ **Storage RLS** untuk file access control

#### General
13. ✅ **Error handling** pada setiap operation
14. ✅ **Loading states** untuk UX yang baik
15. ✅ **Mounted check** sebelum `setState()`
16. ✅ **Proper dispose** untuk controllers
17. ✅ **Image optimization** (compression & resize)
18. ✅ **User feedback** dengan SnackBar

## 📁 Struktur File Project

```
testproject/
├── lib/
│   └── main.dart                    # Main app dengan semua fitur
├── supabase_setup.sql               # SQL untuk setup DB & Storage
├── CRUD_GUIDE.md                    # Guide ini
├── STORAGE_GUIDE.md                 # Detail implementasi Storage
└── pubspec.yaml                     # Dependencies
```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.10.3          # Supabase client
  image_picker: ^1.2.1                # Pick images
```

## 🔧 Troubleshooting

### Database Issues

#### Error: "relation notes does not exist"
```
Solusi: Jalankan SQL script untuk membuat tabel
```

#### Error: "new row violates row-level security policy"
```
Solusi: Pastikan RLS policies sudah dibuat dengan benar
```

### Storage Issues

#### Error: "Bucket not found"
```
Solusi: Buat bucket 'notes-images' di Storage Dashboard
```

#### Error: "Failed to upload"
```
Solusi:
1. Pastikan bucket public
2. Check storage policies
3. Pastikan format path: {user_id}/{filename}
```

#### Gambar tidak tampil
```
Solusi:
1. Check bucket public setting
2. Verify URL di browser
3. Check CORS (untuk web)
```

### General Issues

#### Data tidak muncul setelah insert
```
Solusi: Periksa RLS policies dan user_id
```

#### Email tidak terverifikasi
```
Solusi: Disable "Confirm email" di Auth settings untuk testing
```

## 📖 Referensi

### Supabase Documentation
- [Flutter Client Docs](https://supabase.com/docs/reference/dart/introduction)
- [Auth Guide](https://supabase.com/docs/guides/auth)
- [Database CRUD](https://supabase.com/docs/reference/dart/select)
- [Storage Guide](https://supabase.com/docs/guides/storage)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

### Flutter Packages
- [image_picker](https://pub.dev/packages/image_picker)
- [supabase_flutter](https://pub.dev/packages/supabase_flutter)

## 🎓 Konsep yang Dipelajari

### Flutter
- ✅ State management dengan StatefulWidget
- ✅ Async/await operations
- ✅ Image handling (web & mobile)
- ✅ Dialog & BottomSheet
- ✅ ListView & Cards
- ✅ Error handling & user feedback

### Supabase
- ✅ Authentication & session management
- ✅ PostgreSQL CRUD operations
- ✅ Row Level Security (RLS)
- ✅ Storage upload & management
- ✅ Public vs Private buckets
- ✅ Storage policies & access control

### Best Practices
- ✅ Clean code architecture
- ✅ Error handling patterns
- ✅ Loading states & UX
- ✅ Security best practices
- ✅ Image optimization
- ✅ Proper resource disposal

---

## 🚀 Quick Start

1. **Setup Supabase**: Jalankan `supabase_setup.sql`
2. **Create Storage Bucket**: `notes-images` (public)
3. **Install Dependencies**: `flutter pub get`
4. **Run App**: `flutter run -d chrome`
5. **Register & Login**: Buat akun baru
6. **Add Note**: Klik + dan upload gambar
7. **Test CRUD**: Edit, delete, refresh

---

**Happy Coding! 🚀📸**
