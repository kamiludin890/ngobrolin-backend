# Ngobrolin Backend

API chat berbasis Ruby on Rails API-only, PostgreSQL, JWT, Active Storage, dan Action Cable. Frontend Next.js berjalan terpisah. Panduan pengguna dan spesifikasi gabungan tersedia di dokumen `Ngobrolin-Panduan-Teknis.docx` pada direktori induk `Code`.

## Spesifikasi dan Kebutuhan

- Ruby `3.4.11` (lihat `.ruby-version`), Bundler, Rails `8.1.4`.
- PostgreSQL; database development default `chat_backend_development`.
- Node.js 20.9+ dan npm hanya diperlukan untuk menjalankan frontend.
- API lokal `http://localhost:3001/api/v1`; Action Cable `ws://localhost:3001/cable`.
- ID tabel utama UUID. Request/response API JSON kecuali upload multipart. Timestamps ISO 8601.

## Setup Lokal

1. Pastikan service PostgreSQL berjalan dan siapkan role/database untuk development. Dengan konfigurasi bawaan Rails memakai user OS lewat Unix socket. Untuk koneksi TCP/TablePlus, lihat bagian [Koneksi TablePlus](#koneksi-tableplus).
2. Dari direktori `ngobrolin-backend`, instal gem: `bundle install`.
3. Buat credential lokal baru dan atur secret JWT. File credential terenkripsi dan master key tidak disimpan di Git. Pada setup awal, jalankan:

   ```sh
   bin/rails credentials:edit
   ```

   Jika file credential belum ada, Rails akan membuat `config/credentials.yml.enc` dan `config/master.key`. Buat secret JWT baru dengan `bin/rails secret`, lalu masukkan hasilnya di editor:

   ```yaml
   jwt:
     secret: tempel-hasil-bin-rails-secret-di-sini
   ```

   Simpan `config/master.key` di tempat aman; jika hilang, credential terenkripsi tidak dapat dibuka lagi. Untuk development, Rails menggunakan file key lokal tersebut. Untuk deployment, simpan key sebagai secret `RAILS_MASTER_KEY`. Jangan salin key/secret dari mesin lain atau commit file `config/credentials*.yml.enc`, `config/credentials/`, ataupun key.
4. Siapkan schema: `bin/rails db:prepare`.
5. Jalankan API di port `3001`: `PORT=3001 bin/rails server`.
6. Di terminal lain, jalankan frontend pada port `3000`. CORS dan Action Cable development mengizinkan origin `http://localhost:3000`.

Alternatif bootstrap dependency dan DB: `bin/setup --skip-server`. Test: `bin/rails test`. Lint Ruby: `bin/rubocop`. CI lengkap: `bin/ci` (memerlukan konfigurasi test database/secret yang valid).

Jangan menjalankan `bin/rails db:seed` pada database berisi data yang ingin dipertahankan: `db/seeds.rb` menjalankan `User.destroy_all` dan `Conversation.destroy_all`. Seed membuat akun contoh `kamil@example.com` dan `nadia@example.com` dengan password demo `Kamil890` dan `Nadia890`; gunakan hanya pada database lokal sementara.

## Struktur Folder

```text
app/controllers/api/v1/  Endpoint REST dan serialisasi response
app/controllers/         Autentikasi Bearer serta helper response/error
app/models/              User, Conversation, Message, dan relasi participant
app/channels/            ChatChannel, UserChannel, PresenceChannel, koneksi token
app/services/jwt_service.rb Membuat dan memvalidasi JWT
config/                  Routes, database, CORS, storage, cable, environment
db/migrate/              Perubahan schema, satu migration per perubahan
db/schema.rb             Schema hasil generate; jangan edit manual
db/seeds.rb              Data demo lokal; destruktif terhadap user/conversation
storage/                 File upload Active Storage saat development
test/                    Test model dan integration API
bin/                     Wrapper Rails, setup, test, audit, lint, CI
```

Untuk mengubah endpoint, mulai dari `config/routes.rb`, lalu controller `app/controllers/api/v1/`, model/validasi yang berkaitan, dan integration test. Untuk schema, buat migration lalu jalankan `bin/rails db:migrate`; Rails memperbarui `db/schema.rb`.

## Database PostgreSQL dan TablePlus

Tabel utama: `users` menyimpan email dan `password_digest`; `conversations` menyimpan jenis/judul/deskripsi; `conversation_participants` menyimpan keanggotaan, favorit, read marker, dan hide/clear per akun; `messages` menyimpan teks, sender, dan kunci idempotensi. Tabel `active_storage_blobs`/`active_storage_attachments` menyimpan metadata file. Blob aktual tidak berada di kolom PostgreSQL: development menyimpannya di `backend/storage`.

Konfigurasi project di `config/database.yml` menggunakan host/username/password default libpq (Unix socket dan user OS lokal). Agar TablePlus dapat masuk via TCP, buat role development khusus pada server PostgreSQL, lalu set kredensial yang sama pada TablePlus dan Rails. Contoh untuk instalasi lokal baru:

```sql
CREATE ROLE ngobrolin_dev LOGIN CREATEDB PASSWORD 'ganti-dengan-password-lokal';
```

Isi koneksi TablePlus: driver PostgreSQL, Host `127.0.0.1`, Port `5432`, User `ngobrolin_dev`, Password yang dibuat di atas, Database `chat_backend_development`. Pilih **Test** lalu **Connect**. Di Rails, konfigurasikan `DATABASE_URL` ke `postgres://ngobrolin_dev:<password>@127.0.0.1:5432/chat_backend_development`, atau isi `username`, `password`, `host: 127.0.0.1`, dan `port: 5432` pada konfigurasi development lokal. Jangan commit password ke repository. `CREATEDB` diperlukan jika role akan menyiapkan database test juga.

Pada instalasi yang sudah berisi database, jangan mengubah owner/role tanpa memeriksa hak akses terlebih dahulu. TablePlus hanya dipakai untuk inspeksi/query tabel; jangan mengedit metadata Active Storage secara manual. Database test bernama `chat_backend_test`; jangan pernah arahkan TablePlus atau Rails test ke database development.

## Kontrak API

Base path `/api/v1`. Semua route selain register/login mewajibkan `Authorization: Bearer <accessToken>`. Token HS256 berlaku 7 hari. Error berbentuk `{ "error": { "code": "...", "message": "..." } }`.

| Method | Path | Perilaku |
| --- | --- | --- |
| `POST` | `/auth/register` | Buat akun; response `201`, user dan accessToken |
| `POST` | `/auth/login` | Login; kredensial salah `401 INVALID_CREDENTIALS` |
| `GET` | `/auth/me` | Ambil user token aktif |
| `PATCH` | `/auth/profile` | Ubah nama/email/avatar (multipart) |
| `GET` | `/users?search=...` | Cari maksimal 50 user lain dengan ILIKE |
| `GET` | `/conversations` | Daftar chat, optional `filter`, `search`, `limit` |
| `POST` | `/conversations` | Buat direct/group chat |
| `PATCH` | `/conversations/:id` | Favorit; atau detail/foto grup |
| `DELETE` | `/conversations/:id` | Sembunyikan hanya untuk pengguna aktif |
| `DELETE` | `/conversations/:id/messages` | Bersihkan tampilan riwayat dan unread pengguna aktif |
| `GET` | `/conversations/:conversation_id/messages` | Riwayat; `limit`, `before`, `search` |
| `POST` | `/conversations/:conversation_id/messages` | Kirim teks/lampiran |
| `POST` | `/conversations/:id/read` | Simpan `lastReadMessageId` |
| `POST` | `/conversations/:conversation_id/participants` | Tambah anggota grup menggunakan `userId` |
| `DELETE` | `/conversations/:conversation_id/participants/:id` | Keluarkan anggota grup |

Daftar chat default maksimum 30, maksimum 100; `nextCursor` saat ini selalu `null`. Daftar pesan default 50, maksimum 100, dan mendukung cursor `before`. Jenis chat `direct` mensyaratkan dua peserta total; direct chat yang sudah ada dipakai kembali. Grup baru harus memiliki minimal tiga anggota total; penghapusan anggota ditolak bila grup akan tersisa kurang dari dua anggota.

Pesan maksimal 5000 karakter dan harus berisi teks atau lampiran. `clientMessageId` (atau header `Idempotency-Key`) wajib dan unik dalam conversation; retry dengan ID sama mengembalikan pesan lama. Maksimal 5 lampiran, 20 MB per file; tipe JPEG/PNG/WebP/GIF, MP4/WebM, PDF, atau teks biasa. Avatar user/grup hanya JPEG/PNG/WebP sampai 5 MB. Deskripsi grup maksimal 2500 karakter.

## Realtime, CORS, dan Penyimpanan

Action Cable berada di `/cable`; JWT dikirim sebagai query `token`. Channel: `ChatChannel` untuk pesan/read event anggota percakapan, `UserChannel` untuk update daftar per pengguna, dan `PresenceChannel` untuk broadcast kehadiran. Frontend saat ini menggunakan dua channel pertama, bukan presence. Development memakai adapter `async` (satu proses); production memakai `solid_cable` dan database cable. Siapkan database solid cache/queue/cable melalui tugas Rails saat deployment.

CORS mengizinkan hanya `http://localhost:3000`. Sesuaikan `config/initializers/cors.rb` dan allowed origins Action Cable untuk domain frontend lain. Development Active Storage memakai disk lokal; backup `storage/` bersama database bila file penting. Metadata database tanpa berkas disk yang cocok tidak cukup untuk memulihkan attachment.

## Keamanan dan Batasan

Jangan commit file credentials terenkripsi (`config/credentials.yml.enc` atau `config/credentials/*.yml.enc`), key (`config/master.key` atau `config/credentials/*.key`), secret JWT plaintext, password database, `.env.local`, atau file upload. JWT browser saat ini disimpan di `sessionStorage`; XSS pada origin aplikasi dapat membaca token. Gunakan HTTPS, secret kuat, pembatasan akses jaringan, dan storage produksi yang sesuai. Jangan buka PostgreSQL ke internet untuk koneksi TablePlus; gunakan localhost, SSH tunnel, atau VPN. Aplikasi belum memiliki rate limiting, E2E encryption, sinkronisasi presence/typing di frontend, panggilan suara/video, dan read receipt yang ditampilkan.
