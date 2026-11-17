-- =====================================================================
-- Proyek 2 (lanjutan): Exploratory Data Analysis in MySQL
-- Ikuti video Alex The Analyst "MySQL Exploratory Data Analysis"
-- Tabel: world_layoffs.layoffs_staging2  (hasil data_cleaning.sql, 1995 baris)
-- =====================================================================
-- Setiap pertanyaan diberi TARGET supaya Anda bisa mengecek hasil sendiri.
-- Isi bagian "-- TULIS DI SINI".
-- =====================================================================

USE world_layoffs;


-- ---------------- A. Gambaran umum ----------------

-- 1. PHK terbesar dalam satu kejadian, dan persentase PHK tertinggi.
SELECT MAX(total_laid_off) AS phk_terbesar,
       MAX(CAST(percentage_laid_off AS DECIMAL(5,2))) AS persen_tertinggi
FROM layoffs_staging2;
-- CAST: kolom persentase bertipe TEXT, jadi diubah ke angka dulu agar MAX membandingkan angka.

-- Target: 12000 | 1  (1 = 100% karyawan di-PHK, perusahaan tutup)


-- 2. Berapa perusahaan yang mem-PHK 100% karyawannya? Mana yang pendanaannya terbesar?
SELECT COUNT(*) AS jumlah_tutup
FROM layoffs_staging2
WHERE CAST(percentage_laid_off AS DECIMAL(5,2)) = 1;

SELECT company, total_laid_off, funds_raised_millions
FROM layoffs_staging2
WHERE CAST(percentage_laid_off AS DECIMAL(5,2)) = 1
ORDER BY funds_raised_millions DESC
LIMIT 5;

-- Target: 116 kejadian. Pendanaan terbesar: Britishvolt (2400 jt), Quibi (1800), Deliveroo Australia (1700)


-- 3. Rentang waktu data.
SELECT MIN(`date`) AS tgl_awal, MAX(`date`) AS tgl_akhir
FROM layoffs_staging2;

-- Target: 2020-03-11 s.d. 2023-03-06


-- ---------------- B. Siapa paling terdampak? (GROUP BY + SUM) ----------------

-- 4. Total PHK per perusahaan, 5 teratas.
SELECT company, SUM(total_laid_off) AS total_phk
FROM layoffs_staging2
GROUP BY company
ORDER BY total_phk DESC
LIMIT 5;
-- SUM, bukan MAX: satu perusahaan bisa melakukan PHK beberapa kali.

-- Target: Amazon 18150 | Google 12000 | Meta 11000 | Salesforce 10090 | Philips 10000


-- 5. Total PHK per industri, 3 teratas.
SELECT industry, SUM(total_laid_off) AS total_phk
FROM layoffs_staging2
GROUP BY industry
ORDER BY total_phk DESC
LIMIT 3;

-- Target: Consumer 45182 | Retail 43613 | Other 36289


-- 6. Total PHK per negara, 3 teratas.
SELECT country, SUM(total_laid_off) AS total_phk
FROM layoffs_staging2
GROUP BY country
ORDER BY total_phk DESC
LIMIT 3;

-- Target: United States 256559 | India 35993 | Netherlands 17220


-- 7. Total PHK per tahap pendanaan (stage), 3 teratas.
SELECT stage, SUM(total_laid_off) AS total_phk
FROM layoffs_staging2
GROUP BY stage
ORDER BY total_phk DESC
LIMIT 3;

-- Target: Post-IPO 204132 | Unknown 40716 | Acquired 27576


-- ---------------- C. Tren waktu ----------------

-- 8. Total PHK per tahun (pakai YEAR(`date`)).
SELECT YEAR(`date`) AS tahun, SUM(total_laid_off) AS total_phk
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY tahun;
-- YEAR() hanya bisa karena kolom date sudah bertipe DATE (Langkah 2d cleaning).

-- Target: 2020 80998 | 2021 15823 | 2022 160661 | 2023 125677 | NULL 500
-- Perhatikan: 2023 hanya berisi data Jan - awal Mar, tapi angkanya sudah 125677!


-- 9. Total PHK per bulan + total kumulatif (rolling total). Pakai CTE + SUM() OVER (ORDER BY bulan).
--    Petunjuk: SUBSTRING(`date`, 1, 7) -> '2022-11'
WITH per_bulan AS (
  SELECT SUBSTRING(`date`, 1, 7) AS bulan,      -- '2022-11-25' -> '2022-11'
         SUM(total_laid_off) AS total_phk
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY bulan
)
SELECT bulan,
       total_phk,
       SUM(total_phk) OVER (ORDER BY bulan) AS kumulatif
FROM per_bulan
ORDER BY bulan;
-- Langkah 1 (CTE): total per bulan. Langkah 2 (window): dijumlah berjalan dari bulan pertama.

-- Target: baris terakhir (2023-03) kumulatif = 383159  (total semua = 383659, 500 di antaranya tanpa tanggal)


-- ---------------- D. Ranking (window function) ----------------

-- 10. Perusahaan dengan PHK terbanyak di SETIAP tahun (5 teratas per tahun, DENSE_RANK).
WITH per_perusahaan_tahun AS (
  SELECT company,
         YEAR(`date`) AS tahun,
         SUM(total_laid_off) AS total_phk
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY company, YEAR(`date`)
),
peringkat AS (
  SELECT *,
         DENSE_RANK() OVER (PARTITION BY tahun ORDER BY total_phk DESC) AS ranking
  FROM per_perusahaan_tahun
  WHERE total_phk IS NOT NULL
)
SELECT tahun, ranking, company, total_phk
FROM peringkat
WHERE ranking <= 5
ORDER BY tahun, ranking;
-- Dua CTE berurutan: (1) total per perusahaan per tahun, (2) ranking di dalam setiap tahun.
-- DENSE_RANK: kalau ada yang seri, keduanya mendapat peringkat sama (lihat Hari 8).

-- Target peringkat 1: 2020 Uber 7525 | 2021 Bytedance 3600 | 2022 Meta 11000 | 2023 Google 12000


-- =====================================================================
-- KESIMPULAN - DRAFT dari asisten. GANTI dengan kata-kata Anda sendiri sebelum dipakai
--             di README/portofolio, dan pastikan Anda bisa menjelaskan angkanya.
-- 1. PHK memuncak di 2022 (160.661), dan 2023 baru Jan - 6 Mar sudah 125.677:
--    laju 2023 jauh lebih cepat dari tahun sebelumnya.
-- 2. Perusahaan besar yang sudah IPO paling terdampak: tahap Post-IPO = 204.132 dari
--    383.659 total (53%); 5 teratas semuanya perusahaan besar (Amazon, Google, Meta, Salesforce, Philips).
-- 3. 116 kejadian PHK 100% (perusahaan tutup), termasuk startup bermodal besar seperti
--    Britishvolt (USD 2,4 miliar) -> pendanaan besar tidak menjamin bertahan.
-- Keterbatasan: 361 baris tanpa angka PHK dibuang saat cleaning; 500 PHK tanpa tanggal;
--               data 2023 hanya sampai 6 Maret.
-- =====================================================================
