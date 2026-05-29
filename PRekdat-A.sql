USE restaurant_db;

-- =====================================================
-- b. DATA CLEANING
-- =====================================================

UPDATE resto_customers
SET email = 'unknown@email.com'
WHERE email IS NULL 
OR TRIM(email) = '';

UPDATE resto_customers
SET status_member = 'Unknown'
WHERE status_member IS NULL 
OR TRIM(status_member) = '';

UPDATE resto_transactions
SET id_customer = -1
WHERE id_customer IS NULL;

UPDATE resto_transaction_items
SET quantity = 1
WHERE quantity IS NULL OR quantity <= 0;

UPDATE resto_customers
SET email = LOWER(email);

UPDATE resto_customers
SET status_member = UPPER(TRIM(status_member));


-- =====================================================
-- c. VALIDASI EMAIL (REGEX)
-- =====================================================

DROP VIEW IF EXISTS view_invalid_customer_email;

-- Membuat view untuk menyaring daftar customer dengan format email tidak valid
CREATE VIEW view_invalid_customer_email AS
SELECT
    id_customer,
    nama,
    email
FROM resto_customers
WHERE email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$';


-- =====================================================
-- d. VALIDASI PERHITUNGAN TRANSAKSI
-- =====================================================

DROP VIEW IF EXISTS view_transaction_validation;

-- Membuat view untuk mengaudit kesesuaian total belanja dan menentukan status VALID/INVALID
CREATE VIEW view_transaction_validation AS
SELECT
    t.id_transaction,
    t.id_branch,
    t.total_bayar AS total_tercatat,
    ROUND(SUM(ti.quantity * m.harga), 2) AS total_seharusnya,
    CASE
        WHEN ABS(t.total_bayar - SUM(ti.quantity * m.harga)) < 1 THEN 'VALID'
        ELSE 'INVALID'
    END AS transaction_status
FROM resto_transactions t
JOIN resto_transaction_items ti ON t.id_transaction = ti.id_transaction
JOIN resto_menu m ON ti.id_menu = m.id_menu
GROUP BY t.id_transaction, t.id_branch, t.total_bayar;


-- =====================================================
-- e. ANALISIS VIEW PERFORMA BISNIS
-- =====================================================

DROP VIEW IF EXISTS view_branch_revenue;
DROP VIEW IF EXISTS view_menu_popularity;
DROP VIEW IF EXISTS view_member_behavior;

-- 1. View Performa Pendapatan Cabang
CREATE VIEW view_branch_revenue AS
SELECT
    id_branch,
    ROUND(SUM(total_bayar), 2) total_revenue,
    COUNT(id_transaction) total_transactions
FROM resto_transactions
GROUP BY id_branch;

-- 2. View Popularitas Menu Terjual
CREATE VIEW view_menu_popularity AS
SELECT
    m.id_menu,
    m.nama_menu,
    m.kategori,
    SUM(ti.quantity) total_unit_terjual
FROM resto_menu m
JOIN resto_transaction_items ti ON m.id_menu = ti.id_menu
GROUP BY m.id_menu, m.nama_menu, m.kategori;

-- 3. View Perilaku Belanja Member vs Non-Member
CREATE VIEW view_member_behavior AS
SELECT
    c.status_member,
    COUNT(DISTINCT t.id_transaction) total_transaksi,
    ROUND(AVG(t.total_bayar), 2) avg_pengeluaran_per_transaksi,
    SUM(ti.quantity) total_item_dibeli
FROM resto_customers c
JOIN resto_transactions t ON c.id_customer = t.id_customer
JOIN resto_transaction_items ti ON t.id_transaction = ti.id_transaction
GROUP BY c.status_member;

-- =====================================================
-- OUTPUT SELURUH VIEW
-- =====================================================

-- Menampilkan daftar pelanggan yang format penulisan emailnya salah atau tidak valid berdasarkan aturan REGEX
SELECT * FROM view_invalid_customer_email;

-- Menampilkan status keabsahan transaksi ('VALID' atau 'INVALID') dengan mencocokkan nilai total_bayar terhadap hasil kalkulasi ulang quantity dikali harga menu
SELECT * FROM view_transaction_validation;

-- Menampilkan total pendapatan finansial dan performa jumlah transaksi yang berhasil diraup oleh tiap cabang restoran
SELECT * FROM view_branch_revenue;

-- Menampilkan urutan produk menu makanan/minuman yang paling laku keras berdasarkan akumulasi jumlah quantity terjual
SELECT * FROM view_menu_popularity;

-- Menampilkan perbandingan karakteristik belanja, frekuensi makan, dan rata-rata pengeluaran antara kelompok pelanggan member vs non-member
SELECT * FROM view_member_behavior;
