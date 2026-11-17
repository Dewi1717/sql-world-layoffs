# World Layoffs 2020–2023: Data Cleaning & EDA dengan MySQL

Proyek SQL end-to-end: membersihkan data PHK perusahaan teknologi global (Maret 2020 – Maret 2023), lalu mengeksplorasinya untuk mencari pola. Proyek ini mengikuti seri MySQL dari [Alex The Analyst](https://github.com/AlexTheAnalyst/MySQL-YouTube-Series).

**Tools:** MySQL 8.4 · MySQL Workbench
**Teknik SQL:** CTE · window function (`ROW_NUMBER`, `DENSE_RANK`, `SUM() OVER`) · self-join `UPDATE` · `STR_TO_DATE` · `ALTER TABLE`

---

## Dataset
- Sumber: `layoffs.csv` dari repo Alex The Analyst (data asli dari Layoffs.fyi)
- 2.361 baris, 9 kolom: `company`, `location`, `industry`, `total_laid_off`, `percentage_laid_off`, `date`, `stage`, `country`, `funds_raised_millions`

## Struktur file
| File | Isi |
|---|---|
| `layoffs.csv` | Data mentah |
| `00_import_layoffs.sql` | Membuat database `world_layoffs` dan tabel `layoffs` (2.361 baris) |
| `data_cleaning.sql` | 4 langkah pembersihan data → tabel `layoffs_staging2` |
| `eda.sql` | 10 pertanyaan analisis + kesimpulan |

**Urutan menjalankan:** `00_import_layoffs.sql` → `data_cleaning.sql` → `eda.sql`

---

## Bagian 1: Data Cleaning

Semua perubahan dikerjakan di tabel *staging* supaya data mentah tetap utuh.

| Langkah | Yang dilakukan | Baris |
|---|---|---|
| 0. Staging | Salin `layoffs` → `layoffs_staging` | 2.361 |
| 1. Hapus duplikat | `ROW_NUMBER() OVER (PARTITION BY` semua kolom`)`, hapus `row_num > 1` (Casper, Cazoo, Hibob, Wildlife Studios, Yahoo) | 2.356 |
| 2. Standardisasi | `TRIM` nama perusahaan · `Crypto Currency`/`CryptoCurrency` → `Crypto` · `United States.` → `United States` · teks `date` → tipe `DATE` | 2.356 |
| 3. NULL & kosong | `industry` kosong → NULL, lalu diisi dari baris lain perusahaan yang sama lewat self-join (Airbnb, Juul, Carvana). Bally's Interactive tetap NULL karena tidak punya baris pembanding. | 2.356 |
| 4. Hapus yang tidak terpakai | Hapus 361 baris tanpa `total_laid_off` **dan** tanpa `percentage_laid_off`; hapus kolom bantu `row_num` | **1.995** |

**Ringkasan:** 2.361 − 5 duplikat − 361 baris kosong = **1.995 baris bersih**

---

## Bagian 2: Exploratory Data Analysis

| # | Pertanyaan | Hasil |
|---|---|---|
| 1 | PHK terbesar dalam satu kejadian | 12.000 orang (Google, Jan 2023) |
| 2 | Kejadian PHK 100% (perusahaan tutup) | 116 kejadian. Pendanaan terbesar: Britishvolt (USD 2,4 miliar), Quibi (USD 1,8 miliar) |
| 3 | Rentang waktu | 11 Mar 2020 – 6 Mar 2023 |
| 4 | 5 perusahaan dengan total PHK terbanyak | Amazon 18.150 · Google 12.000 · Meta 11.000 · Salesforce 10.090 · Philips 10.000 |
| 5 | 3 industri teratas | Consumer 45.182 · Retail 43.613 · Other 36.289 |
| 6 | 3 negara teratas | United States 256.559 · India 35.993 · Netherlands 17.220 |
| 7 | 3 tahap pendanaan teratas | Post-IPO 204.132 · Unknown 40.716 · Acquired 27.576 |
| 8 | Total PHK per tahun | 2020: 80.998 · 2021: 15.823 · 2022: 160.661 · 2023: 125.677 *(s.d. 6 Mar)* |
| 9 | Total kumulatif bulanan (CTE + `SUM() OVER`) | 36 bulan, mencapai 383.159 pada Mar 2023 |
| 10 | Peringkat 1 per tahun (`DENSE_RANK`) | 2020 Uber · 2021 Bytedance · 2022 Meta · 2023 Google |

Contoh query (no. 10): dua CTE berurutan dan ranking per tahun.
```sql
WITH per_perusahaan_tahun AS (
  SELECT company, YEAR(`date`) AS tahun, SUM(total_laid_off) AS total_phk
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY company, YEAR(`date`)
),
peringkat AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY tahun ORDER BY total_phk DESC) AS ranking
  FROM per_perusahaan_tahun
  WHERE total_phk IS NOT NULL
)
SELECT tahun, ranking, company, total_phk
FROM peringkat
WHERE ranking <= 5
ORDER BY tahun, ranking;
```

---

## Temuan Utama
<!-- TODO: TULIS ULANG bagian ini dengan kata-kata Anda sendiri (draft dari asisten). -->
1. **PHK memuncak di 2022 dan semakin cepat di 2023.** Data 2023 baru mencakup Jan – 6 Mar, tapi angkanya sudah 125.677 (78% dari total setahun penuh 2022).
2. **Perusahaan besar yang sudah IPO paling terdampak.** Tahap Post-IPO menyumbang 53% dari total PHK, dan 5 teratas semuanya perusahaan teknologi besar.
3. **Pendanaan besar tidak menjamin bertahan.** Ada 116 kejadian PHK 100%, termasuk Britishvolt yang sudah mengumpulkan USD 2,4 miliar.

## Keterbatasan
- 361 baris dibuang karena tidak punya angka PHK sama sekali, jadi total sebenarnya lebih besar.
- 500 PHK tidak punya tanggal sehingga tidak masuk analisis per tahun dan per bulan.
- Data 2023 hanya sampai 6 Maret; perbandingan antar tahun belum setara.
- Banyak baris hanya mencantumkan persentase tanpa jumlah orang, sehingga total PHK cenderung *underestimate*.
