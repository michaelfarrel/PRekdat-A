CREATE DATABASE restaurant_db;
USE restaurant_db;

SET SQL_SAFE_UPDATES = 0;

-- DATA CLEANING
-- a. tabel resto_customers
SELECT * FROM resto_customers;

SELECT 
    id_customer,
    nama,
    email
FROM resto_customers
WHERE email IS NULL
OR TRIM(email) = '';
   
SELECT id_customer,
    nama,
    email
FROM resto_customers
WHERE email NOT REGEXP '^user[0-9]+@email\.com$';

UPDATE resto_customers
SET email = CONCAT('user', id_customer, '@email.com')
WHERE email IS NULL 
OR TRIM(email) = ''
OR email NOT REGEXP '^user[0-9]+@email\.com$';


-- b. tabel resto_menu
-- Pada saat upload data ke SQL, ubah type data harga dari double ke text untuk sementara. Hal ini agar baris dengan NULL dapat terbaca.
SELECT * FROM resto_menu;

SELECT * FROM resto_menu
WHERE harga IS NULL
OR harga = '';

UPDATE resto_menu 
SET harga = NULL 
WHERE harga = '';

ALTER TABLE resto_menu 
MODIFY harga INT NULL;

SELECT kategori, ROUND(AVG(harga)) FROM resto_menu
WHERE harga IS NOT NULL
GROUP BY kategori;

UPDATE resto_menu AS m
JOIN (SELECT kategori, ROUND(AVG(harga)) AS avg_harga 
		FROM resto_menu
        WHERE harga IS NOT NULL
		GROUP BY kategori) as n
ON m.kategori = n.kategori
SET m.harga = n.avg_harga
WHERE harga IS NULL;


-- c. tabel resto_transactions
-- Pada saat upload data ke SQL, ubah type data id_customer dari double ke text untuk sementara. Hal ini agar baris dengan NULL dapat terbaca.
SELECT * FROM resto_transactions;

SELECT * FROM resto_transactions
WHERE id_customer IS NULL
OR id_customer = '';
-- nilai kosong pada id_customer diisi dengan dummy variable 0
-- karena tidak ada informasi lain yang dapat membantu untuk mengisi nilai kosong
UPDATE resto_transactions 
SET id_customer = 0 
WHERE id_customer = '';
ALTER TABLE resto_transactions 
MODIFY id_customer INT;

-- kolom tanggal_transaksi diubah formatnya menjadi date
ALTER TABLE resto_transactions
MODIFY tanggal_transaksi DATE;

-- d. tabel resto_transaction_items
SELECT * FROM resto_transaction_items;

SELECT * FROM resto_transaction_items
WHERE quantity IS NULL
OR quantity = '';

-- quantity dianggap text karena terdapat nilai kosong
UPDATE resto_transaction_items  
SET quantity = NULL 
WHERE quantity = '';
ALTER TABLE resto_transaction_items 
MODIFY quantity INT NULL;

-- nilai quantity kosong di tabel resto_transaction_items, 
-- diisi dengan pembagian subtotal dengan harga di resto_menu 
-- harga di resto_menu dianggap final
UPDATE resto_transaction_items AS ti
JOIN resto_menu AS m
ON ti.id_menu = m.id_menu
SET ti.quantity = ROUND(ti.subtotal/m.harga)
WHERE ti.quantity IS NULL;

-- Cek perhitungan transaksi di tabel resto_transaction_item
SELECT 
	ti.id_item, 
    ti.id_transaction, 
	ti.id_menu, 
    ti.quantity, 
    m.harga AS harga_satuan,
    ti.subtotal AS subtotal_tercatat,
    ti.quantity * m.harga AS subtotal_seharusnya,
    CASE
		WHEN ti.subtotal = ti.quantity * m.harga THEN 'Sesuai'
        ELSE 'Tidak Sesuai'
	END AS Keterangan
FROM resto_transaction_items AS ti
JOIN resto_menu AS m
ON ti.id_menu = m.id_menu;


-- Buat View
-- View branch_revenue
CREATE VIEW view_branch_revenue AS
SELECT
    id_branch,
    COUNT(id_transaction) AS jumlah_transaksi,
    SUM(total_bayar) AS total_pendapatan
FROM resto_transactions
GROUP BY id_branch;

SELECT * FROM view_branch_revenue;	

-- View menu_popularity
CREATE VIEW view_menu_popularity AS
SELECT
    m.id_menu,
    m.nama_menu,
    m.kategori,
    SUM(ti.quantity) AS total_menu_terjual
FROM resto_menu AS m
JOIN resto_transaction_items AS ti 
ON m.id_menu = ti.id_menu
GROUP BY 
	m.id_menu, 
	m.nama_menu, 
	m.kategori
ORDER BY m.id_menu;

SELECT * FROM view_menu_popularity;

-- View member_behavior
CREATE VIEW view_member_behavior AS
SELECT
    c.status_member,
    COUNT(DISTINCT c.id_customer) AS jumlah_customer,
    COUNT(t.id_transaction) AS jumlah_transaksi,
    SUM(t.total_bayar) AS total_pengeluaran,
    ROUND(AVG(t.total_bayar), 2) AS avg_pengeluaran_per_transaksi
FROM resto_customers AS c
JOIN resto_transactions AS t
ON c.id_customer = t.id_customer
GROUP BY c.status_member;

SELECT * FROM view_member_behavior;

-- View transaction_validation
CREATE VIEW view_transaction_validation AS
SELECT 
    t.id_transaction,
    t.total_bayar,
    SUM(ti.quantity * m.harga) AS total_seharusnya,
    CASE
		WHEN t.total_bayar = SUM(ti.quantity * m.harga) THEN 'VALID'
        ELSE 'INVALID'
	END AS Keterangan_validasi
FROM resto_transactions AS t
JOIN resto_transaction_items AS ti
    ON t.id_transaction = ti.id_transaction
JOIN resto_menu AS m
    ON ti.id_menu = m.id_menu
GROUP BY 
	t.id_transaction, 
    t.total_bayar;

SELECT * FROM view_transaction_validation;

