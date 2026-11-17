-- =====================================================================
-- Proyek 2: Data Cleaning in MySQL  (ikuti video Alex The Analyst)
-- Dataset : layoffs.csv  (PHK perusahaan dunia)
-- Database: world_layoffs   Tabel mentah: layoffs  (JANGAN diubah)
-- Penulis : (nama Anda)     Tanggal: ...
-- =====================================================================
-- Template ini berisi KERANGKA + query pengecekan.
-- Isi bagian "-- TULIS DI SINI" sambil menonton video.
-- =====================================================================

USE world_layoffs;

-- CEK AWAL: catat jumlah baris setelah impor dan cocokkan dengan video Alex.
SELECT COUNT(*) AS baris_mentah FROM layoffs;
-- Target: 2361 (jumlah baris data di layoffs.csv). Hasil saya: ......


-- ---------------------------------------------------------------------
-- LANGKAH 0. Buat tabel staging (salinan kerja)
--   Sama seperti "Working Sheet" di proyek Excel: data mentah tetap utuh.
-- ---------------------------------------------------------------------
-- DROP dulu supaya script aman dijalankan ulang dari awal.
DROP TABLE IF EXISTS layoffs_staging;

-- LIKE = salin STRUKTUR (kolom + tipe data) saja, tanpa isi.
CREATE TABLE layoffs_staging LIKE layoffs;

-- Salin ISINYA.
INSERT INTO layoffs_staging
SELECT * FROM layoffs;

-- Cek: jumlah baris staging harus sama dengan mentah -> 2361
SELECT COUNT(*) AS baris_staging FROM layoffs_staging;


-- ---------------------------------------------------------------------
-- LANGKAH 1. Hapus duplikat
--   ROW_NUMBER() OVER (PARTITION BY semua kolom) -> baris dengan row_num > 1 = duplikat.
--   (Hari 8 window function + Hari 9 CTE)
-- ---------------------------------------------------------------------

-- 1a. LIHAT duplikat dulu (belum menghapus apa pun).
--     Tabel ini tidak punya kolom ID, jadi baris dianggap duplikat kalau
--     SEMUA 9 kolom sama persis. `date` pakai backtick karena kata khusus SQL.
WITH duplicate_cte AS (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY company, location, industry, total_laid_off,
                        percentage_laid_off, `date`, stage, country,
                        funds_raised_millions
         ) AS row_num
  FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;
-- Target: 5 baris -> Cazoo, Yahoo, Hibob, Casper, Wildlife Studios

-- 1b. MySQL tidak bisa DELETE dari CTE, jadi buat tabel baru
--     dengan kolom tambahan row_num yang tersimpan permanen.
DROP TABLE IF EXISTS layoffs_staging2;

CREATE TABLE layoffs_staging2 (
  company               TEXT,
  location              TEXT,
  industry              TEXT,
  total_laid_off        INT,
  percentage_laid_off   TEXT,
  `date`                TEXT,
  stage                 TEXT,
  country               TEXT,
  funds_raised_millions INT,
  row_num               INT
);

INSERT INTO layoffs_staging2
SELECT *,
       ROW_NUMBER() OVER (
         PARTITION BY company, location, industry, total_laid_off,
                      percentage_laid_off, `date`, stage, country,
                      funds_raised_millions
       ) AS row_num
FROM layoffs_staging;

-- 1c. Cek ulang SEBELUM menghapus: harus 5 baris yang sama seperti 1a.
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;

-- 1d. Hapus duplikatnya. (SAFE_UPDATES dimatikan agar DELETE tanpa kunci primer diizinkan.)
SET SQL_SAFE_UPDATES = 0;

DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- Cek setelah DELETE: duplikat harus 0, total baris harus 2356 (2361 - 5)
SELECT COUNT(*) AS sisa_duplikat FROM layoffs_staging2 WHERE row_num > 1;
SELECT COUNT(*) AS baris_setelah_langkah1 FROM layoffs_staging2;


-- ---------------------------------------------------------------------
-- LANGKAH 2. Standarisasi data
--   company  : spasi berlebih -> TRIM
--   industry : 'Crypto', 'CryptoCurrency', ... -> satu nama
--   country  : 'United States.' (titik di akhir) -> 'United States'
--   date     : teks -> tipe DATE (STR_TO_DATE lalu ALTER TABLE)
--   (Hari 6 string functions)
-- ---------------------------------------------------------------------
-- Pola setiap sub-langkah: LIHAT (SELECT lama vs baru) -> UBAH (UPDATE) -> CEK.

-- 2a. company: buang spasi di awal/akhir nama.
SELECT company, TRIM(company) AS company_baru
FROM layoffs_staging2
WHERE company <> TRIM(company);
-- Target: 11 baris (mis. 'WeWork ', ' Included Health', ' E Inc.')

UPDATE layoffs_staging2
SET company = TRIM(company);

SELECT COUNT(*) AS sisa_spasi FROM layoffs_staging2 WHERE company <> TRIM(company);
-- Target: 0


-- 2b. industry: 3 penulisan untuk industri yang sama.
SELECT DISTINCT industry FROM layoffs_staging2 ORDER BY 1;
-- Terlihat: 'Crypto', 'Crypto Currency', 'CryptoCurrency'

SELECT industry, COUNT(*) AS jumlah
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%'
GROUP BY industry;
-- Target: Crypto 99, sisanya 3 baris -> total 102

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

SELECT industry, COUNT(*) AS jumlah
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%'
GROUP BY industry;
-- Target: hanya 1 baris -> Crypto 102


-- 2c. country: 'United States.' (ada titik di akhir).
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country) AS country_baru
FROM layoffs_staging2
WHERE country LIKE 'United States%';

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

SELECT COUNT(*) AS sisa_titik FROM layoffs_staging2 WHERE country = 'United States.';
-- Target: 0


-- 2d. date: teks '3/6/2023' (bulan/hari/tahun) -> tipe DATE. DUA langkah, urutan penting.
SELECT `date`, STR_TO_DATE(`date`, '%m/%d/%Y') AS date_baru
FROM layoffs_staging2
LIMIT 10;

-- (1) Ubah ISI teks menjadi format tanggal standar 'YYYY-MM-DD' (kolom masih bertipe TEXT).
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- (2) Baru ubah TIPE kolomnya menjadi DATE.
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

SELECT MIN(`date`) AS tgl_awal, MAX(`date`) AS tgl_akhir,
       SUM(`date` IS NULL) AS tgl_kosong
FROM layoffs_staging2;
-- Target: 2020-03-11 | 2023-03-06 | 1  (1 baris memang tanpa tanggal di data asli)


-- CEK AKHIR LANGKAH 2: jumlah baris tidak berubah
SELECT COUNT(*) AS baris_setelah_langkah2 FROM layoffs_staging2;
-- Target: 2356


-- ---------------------------------------------------------------------
-- LANGKAH 3. NULL dan nilai kosong
--   industry kosong -> isi dari baris lain milik perusahaan yang sama (self join, Hari 5)
-- ---------------------------------------------------------------------
-- LIHAT masalahnya: '' (teks kosong) dan NULL itu BERBEDA bagi SQL.
SELECT company, industry
FROM layoffs_staging2
WHERE industry IS NULL OR industry = ''
ORDER BY company;
-- Target: 4 baris -> Airbnb (''), Bally's Interactive (NULL), Carvana (''), Juul ('')

-- Apakah perusahaan yang sama punya baris lain dengan industry terisi?
SELECT company, industry
FROM layoffs_staging2
WHERE company IN ('Airbnb', 'Juul', 'Carvana', 'Bally''s Interactive')
ORDER BY company;
-- Airbnb -> Travel, Juul -> Consumer, Carvana -> Transportation, Bally's -> tidak ada


-- 3a. Samakan dulu: '' -> NULL, supaya cukup satu kondisi (IS NULL) di langkah berikutnya.
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';


-- 3b. Self join: pasangkan baris yang kosong (t1) dengan baris perusahaan yang sama
--     yang industrinya terisi (t2). LIHAT dulu sebelum mengubah.
SELECT t1.company, t1.industry AS industry_kosong, t2.industry AS industry_pengisi
FROM layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
  ON t1.company = t2.company
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;
-- Target: 4 pasangan -> Airbnb/Travel, Carvana/Transportation (2x, Carvana punya 2 baris terisi), Juul/Consumer


-- 3c. Isi nilai kosong. Pola UPDATE + JOIN: UPDATE -> JOIN -> SET -> WHERE.
UPDATE layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;


-- CEK: berapa industry yang masih kosong?
SELECT company, industry
FROM layoffs_staging2
WHERE industry IS NULL OR industry = '';
-- Target: 1 baris -> Bally's Interactive. Hanya punya 1 baris, tidak ada sumber pengisi,
--         jadi DIBIARKAN NULL (lebih jujur daripada mengarang industrinya).

-- Catatan: total_laid_off / percentage_laid_off yang kosong TIDAK diisi, karena
-- data jumlah total karyawan tidak tersedia untuk menghitungnya. Diurus di Langkah 4.

SELECT COUNT(*) AS baris_setelah_langkah3 FROM layoffs_staging2;
-- Target: 2356


-- ---------------------------------------------------------------------
-- LANGKAH 4. Hapus baris & kolom yang tidak berguna
--   baris tanpa total_laid_off DAN tanpa percentage_laid_off; kolom row_num
-- ---------------------------------------------------------------------
-- 4a. Baris tanpa total_laid_off DAN tanpa percentage_laid_off tidak memberi informasi
--     tentang PHK sama sekali -> tidak berguna untuk analisis (EDA) berikutnya.
--     Yang kosong SALAH SATU saja tetap dipertahankan (masih ada informasinya).
--     LIHAT dulu:
SELECT COUNT(*) AS akan_dihapus
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;
-- Target: 361

DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;


-- 4b. Kolom bantu row_num sudah tidak diperlukan (hanya dipakai di Langkah 1).
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;


-- CEK AKHIR
SELECT COUNT(*) AS baris_bersih FROM layoffs_staging2;
-- Target: 1995  (2361 mentah - 5 duplikat - 361 tanpa data PHK)

SELECT * FROM layoffs_staging2 LIMIT 10;
-- Harus 9 kolom (tanpa row_num), tanggal berformat YYYY-MM-DD.

-- =====================================================================
-- RINGKASAN PEMBERSIHAN (untuk README portofolio)
--   Baris mentah                         : 2361
--   - Duplikat persis (9 kolom sama)     :    5
--   - Tanpa total & persentase PHK       :  361
--   = Baris bersih                       : 1995
--   Standarisasi: 11 nama perusahaan di-TRIM, 3 penulisan Crypto disatukan,
--   'United States.' diperbaiki (4), kolom date -> tipe DATE.
--   Nilai kosong: industry 3 diisi via self join; Bally's Interactive tetap NULL.
-- Tabel hasil: world_layoffs.layoffs_staging2  (tabel mentah layoffs tetap utuh)
-- =====================================================================
