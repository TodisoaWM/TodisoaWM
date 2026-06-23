import sqlite3
import os
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(__file__), 'factures.db')


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    c = conn.cursor()

    c.executescript('''
        CREATE TABLE IF NOT EXISTS clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT,
            phone TEXT,
            address TEXT,
            city TEXT,
            country TEXT DEFAULT 'Madagascar',
            created_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number TEXT NOT NULL UNIQUE,
            client_id INTEGER NOT NULL,
            issue_date TEXT NOT NULL,
            due_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'brouillon',
            notes TEXT,
            tax_rate REAL DEFAULT 20.0,
            discount REAL DEFAULT 0.0,
            created_at TEXT DEFAULT (datetime('now')),
            updated_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (client_id) REFERENCES clients(id)
        );

        CREATE TABLE IF NOT EXISTS invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            description TEXT NOT NULL,
            quantity REAL NOT NULL DEFAULT 1,
            unit_price REAL NOT NULL,
            FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        );
    ''')

    defaults = [
        ('company_name', 'Mon Entreprise'),
        ('company_address', ''),
        ('company_email', ''),
        ('company_phone', ''),
        ('company_city', ''),
        ('currency', 'Ar'),
        ('invoice_prefix', 'FACT-'),
        ('next_number', '1'),
    ]
    for key, value in defaults:
        c.execute('INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)', (key, value))

    conn.commit()
    conn.close()


def get_setting(key, default=''):
    conn = get_db()
    row = conn.execute('SELECT value FROM settings WHERE key=?', (key,)).fetchone()
    conn.close()
    return row['value'] if row else default


def set_setting(key, value):
    conn = get_db()
    conn.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', (key, value))
    conn.commit()
    conn.close()


def next_invoice_number():
    prefix = get_setting('invoice_prefix', 'FACT-')
    n = int(get_setting('next_number', '1'))
    number = f"{prefix}{n:04d}"
    set_setting('next_number', str(n + 1))
    return number


def invoice_total(invoice_id):
    conn = get_db()
    items = conn.execute(
        'SELECT quantity, unit_price FROM invoice_items WHERE invoice_id=?', (invoice_id,)
    ).fetchall()
    subtotal = sum(r['quantity'] * r['unit_price'] for r in items)
    inv = conn.execute('SELECT tax_rate, discount FROM invoices WHERE id=?', (invoice_id,)).fetchone()
    conn.close()
    if not inv:
        return 0, 0, 0, 0
    discount_amt = subtotal * inv['discount'] / 100
    taxable = subtotal - discount_amt
    tax_amt = taxable * inv['tax_rate'] / 100
    total = taxable + tax_amt
    return subtotal, discount_amt, tax_amt, total
