# Log Prompt Gemini Canvas (Soal 3.1a)

Tempel 3 prompt ini satu per satu di Gemini Canvas. Screenshot hasil tiap prompt ke folder `bukti-screenshot/`.
Versi final kode ada di `soal-3/voucher.html`.

1. Buat satu file HTML (Tailwind CDN dan JavaScript) untuk Voucher Kas Keluar: input tanggal, nomor bukti, deskripsi, dan tabel baris jurnal dinamis (akun, debit, kredit, tambah/hapus baris).

2. Tambahkan indikator total debit, total kredit, dan selisih secara real-time (hijau jika seimbang, merah jika tidak). Submit aktif hanya jika Debit = Kredit > 0, minimal 2 baris, tiap baris punya akun dan satu sisi terisi. Hitung dalam sen (integer).

3. Voucher wajib mengkredit akun Kas/Bank dan tidak boleh mendebitnya. Submit memanggil Supabase RPC post_cash_out_voucher(p_trx_date, p_reference_no, p_description, p_lines jsonb).

# Log NotebookLM (Soal 3.1b) -- isi setelah kamu menjalankannya sendiri
Sumber yang diunggah: PSAK 2, PSAK 1 (materi kuliah / situs IAI), voucher.html, 03_soal3_audit_immutability.sql
Pertanyaan 1: Apa definisi kas dan setara kas menurut PSAK 2?
Pertanyaan 2: Apakah aturan bisnis pada kode (kas keluar = kredit akun kas/bank, akun kas tidak boleh didebit, koreksi lewat jurnal pembalik) sesuai PSAK?
Pertanyaan 3: Apa yang perlu diungkapkan terkait kas yang penggunaannya dibatasi?
Jawaban NotebookLM (tempel / screenshot): ...
