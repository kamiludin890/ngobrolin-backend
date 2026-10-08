# Chat Backend

Backend REST API untuk autentikasi pengguna dan percakapan chat, dibuat dengan Ruby on Rails dan PostgreSQL. API menggunakan JSON, UUID, JWT, dan Action Cable untuk event real-time.

## Persyaratan

- Ruby yang kompatibel dengan Rails `~> 8.1.4`
- Bundler
- PostgreSQL

## Menjalankan secara lokal

1. Instal dependensi Ruby:

	 ```sh
	 bundle install
	 ```

2. Pastikan PostgreSQL berjalan. Database development bernama `chat_backend_development`; sesuaikan `config/database.yml` atau atur `DATABASE_URL` bila konfigurasi lokal berbeda.

3. Atur secret JWT melalui Rails credentials. Jalankan `bin/rails credentials:edit`, lalu tambahkan:

	 ```yaml
	 jwt:
		 secret: secret-random-yang-panjang
	 ```

	 Jangan masukkan secret produksi ke repository.

4. Siapkan database dan jalankan server di port `3001` agar tidak bentrok dengan frontend Next.js pada port `3000`:

	 ```sh
	 bin/rails db:prepare
	 PORT=3001 bin/rails server
	 ```

	 Alternatifnya, `bin/setup --skip-server` memasang dependensi, menyiapkan database, serta membersihkan log dan temporary files. Frontend menggunakan API di `http://localhost:3001/api/v1`.

Untuk menjalankan test:

```sh
bin/rails test
```

## Konvensi API

- Base URL lokal untuk frontend: `http://localhost:3001/api/v1`
- Request dan response menggunakan JSON.
- Kirim `Content-Type: application/json` untuk request dengan body.
- Semua endpoint kecuali register dan login membutuhkan header `Authorization: Bearer <accessToken>`.
- Token berlaku selama 7 hari.
- Waktu pada response menggunakan ISO 8601.
- Error memiliki bentuk `{ "error": { "code": "...", "message": "..." } }`.

Contoh header:

```http
Authorization: Bearer <accessToken>
Content-Type: application/json
```

## Autentikasi

### Daftar

`POST /auth/register`

```json
{
	"name": "Ayu",
	"email": "ayu@example.com",
	"password": "kata-sandi",
	"password_confirmation": "kata-sandi"
}
```

Response `201 Created` berisi `user` dan `accessToken`:

```json
{
	"user": {
		"id": "<uuid>",
		"name": "Ayu",
		"email": "ayu@example.com"
	},
	"accessToken": "<jwt>"
}
```

Email dinormalisasi menjadi huruf kecil dan tanpa spasi di awal/akhir. Nama maksimal 100 karakter.

### Login

`POST /auth/login`

```json
{
	"email": "ayu@example.com",
	"password": "kata-sandi"
}
```

Response sukses berisi bentuk `user` dan `accessToken` yang sama dengan register. Kredensial salah menghasilkan `401` dengan kode `INVALID_CREDENTIALS`.

### Pengguna saat ini

`GET /auth/me`

Response:

```json
{
	"user": {
		"id": "<uuid>",
		"name": "Ayu",
		"email": "ayu@example.com"
	}
}
```

### Pencarian kontak

`GET /users?search={nama-atau-email}` mengembalikan maksimal 50 user selain pengguna yang sedang login. Pencarian memakai PostgreSQL `ILIKE`.

### Ubah profil

`PATCH /auth/profile` menerima `name` dan `email`; validasi user disimpan ke tabel PostgreSQL `users`.

## Percakapan

### Daftar percakapan

`GET /conversations`

Query opsional:

| Parameter | Keterangan |
| --- | --- |
| `filter` | `all` (default), `unread`, atau `favorite` |
| `search` | Mencari judul percakapan atau nama peserta lain |
| `limit` | Jumlah hasil, default `30`, maksimum `100` |

Response berisi `items` dan `nextCursor`. Saat ini `nextCursor` selalu `null`, sehingga endpoint ini belum menyediakan pagination cursor. Objek percakapan mencakup `id`, `kind`, `title`, `avatarUrl`, `participantCount`, `isFavorite`, `unreadCount`, dan `lastMessage`.

Catatan implementasi: filter `unread` saat ini memilih percakapan yang memiliki `last_read_message_id`, bukan menghitung apakah benar-benar ada pesan belum dibaca. Perilaku ini perlu diperbaiki bila filter tersebut digunakan oleh client.

### Membuat percakapan

`POST /conversations` menerima `kind` dan `participantIds`. Untuk `direct`, kirim UUID user tujuan; user login otomatis ditambahkan. Conversation dan participant disimpan dalam transaksi PostgreSQL. Direct conversation yang sudah ada akan dikembalikan agar tidak terduplikasi.

### Mengubah favorit

`PATCH /conversations/:id`

```json
{
	"isFavorite": true
}
```

Response berupa objek percakapan yang diperbarui. Pengguna harus menjadi peserta percakapan.

### Menandai pesan sudah dibaca

`POST /conversations/:id/read`

```json
{
	"lastReadMessageId": "<uuid-pesan>"
}
```

Pesan harus berada dalam percakapan tersebut. Response sukses memuat `success`, `conversationId`, dan `lastReadMessageId`. Event `conversation.read` juga dikirim melalui Action Cable.

## Pesan

### Mengambil pesan

`GET /conversations/:conversation_id/messages`

Query opsional `limit` default `50` dengan maksimum `100`, dan `before` berisi ID pesan untuk mengambil halaman yang lebih lama.

Response berbentuk `{ "items": [...], "nextCursor": "<uuid-atau-null>" }`. Item memuat `id`, `conversationId`, `senderId`, `text`, `createdAt`, dan `status` (`sent`). Pesan pada tiap halaman dikembalikan dari yang lebih lama ke yang lebih baru.

### Mengirim pesan

`POST /conversations/:conversation_id/messages`

```json
{
	"clientMessageId": "client-generated-unique-id",
	"text": "Halo!"
}
```

`clientMessageId` wajib diisi dan unik dalam satu percakapan. Sebagai alternatif, ID dapat dikirim melalui header `Idempotency-Key`. Mengirim ulang ID yang sama mengembalikan pesan yang sudah dibuat tanpa membuat duplikat. Teks tidak boleh kosong dan maksimum 5000 karakter.

Response sukses pertama kali adalah `201 Created`, dengan objek pesan. Pesan baru juga memancarkan event Action Cable `message.created`.

## Action Cable

WebSocket tersedia di `/cable`. Kirim JWT sebagai query parameter `token`, misalnya `ws://localhost:3000/cable?token=<accessToken>`. Koneksi tanpa token valid ditolak.

Setelah terhubung, subscribe ke channel percakapan dengan identifier:

```json
{
	"channel": "ChatChannel",
	"conversation_id": "<uuid-percakapan>"
}
```

Hanya anggota percakapan yang dapat subscribe. Channel mengirim payload `message.created` dan `conversation.read` untuk event terkait. `PresenceChannel` mengirim event `presence.changed` dengan `userId` dan `online` saat subscribe/unsubscribe. Adapter Action Cable mengikuti konfigurasi environment (`async` pada development); untuk penggunaan multi-proses/produksi, pastikan adapter dan database cable sudah dikonfigurasi sesuai deployment.

## CORS

Konfigurasi saat ini hanya mengizinkan origin `http://localhost:3000`. Untuk frontend di origin lain, ubah `config/initializers/cors.rb` dan restart server. Hindari mengizinkan semua origin di lingkungan produksi tanpa pertimbangan keamanan.
