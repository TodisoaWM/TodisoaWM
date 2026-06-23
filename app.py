from flask import Flask, render_template, request, redirect, url_for, flash, send_file
from datetime import datetime, timedelta
import io
import os

from database import (
    init_db, get_db, get_setting, set_setting,
    next_invoice_number, invoice_total
)
from pdf_generator import generate_pdf

app = Flask(__name__)
app.secret_key = 'factures-secret-key-2024'


@app.template_filter('currency')
def currency_filter(value):
    currency = get_setting('currency', 'Ar')
    try:
        return f"{float(value):,.0f} {currency}".replace(',', ' ')
    except (TypeError, ValueError):
        return f"0 {currency}"


@app.template_filter('dateformat')
def dateformat(value):
    if not value:
        return ''
    try:
        return datetime.strptime(value, '%Y-%m-%d').strftime('%d/%m/%Y')
    except Exception:
        return value


# ── Dashboard ────────────────────────────────────────────────────────────────

@app.route('/')
def dashboard():
    conn = get_db()
    today = datetime.today().strftime('%Y-%m-%d')

    total_invoices = conn.execute('SELECT COUNT(*) as c FROM invoices').fetchone()['c']
    paid = conn.execute("SELECT COUNT(*) as c FROM invoices WHERE status='payée'").fetchone()['c']
    pending = conn.execute(
        "SELECT COUNT(*) as c FROM invoices WHERE status IN ('envoyée','brouillon')"
    ).fetchone()['c']
    overdue = conn.execute(
        "SELECT COUNT(*) as c FROM invoices WHERE status NOT IN ('payée','annulée') AND due_date < ?",
        (today,)
    ).fetchone()['c']

    recent = conn.execute('''
        SELECT i.*, c.name as client_name
        FROM invoices i JOIN clients c ON i.client_id = c.id
        ORDER BY i.created_at DESC LIMIT 5
    ''').fetchall()

    monthly = conn.execute('''
        SELECT strftime('%Y-%m', issue_date) as month, COUNT(*) as count
        FROM invoices
        WHERE issue_date >= date('now', '-6 months')
        GROUP BY month ORDER BY month
    ''').fetchall()

    revenue_paid = conn.execute('''
        SELECT i.id, i.tax_rate, i.discount
        FROM invoices i WHERE i.status='payée'
    ''').fetchall()
    total_revenue = sum(invoice_total(r['id'])[3] for r in revenue_paid)

    conn.close()

    recent_with_totals = []
    for inv in recent:
        _, _, _, total = invoice_total(inv['id'])
        recent_with_totals.append({'invoice': inv, 'total': total})

    return render_template('dashboard.html',
        total_invoices=total_invoices,
        paid=paid,
        pending=pending,
        overdue=overdue,
        total_revenue=total_revenue,
        recent=recent_with_totals,
        monthly_labels=[r['month'] for r in monthly],
        monthly_counts=[r['count'] for r in monthly],
        currency=get_setting('currency', 'Ar'),
    )


# ── Clients ───────────────────────────────────────────────────────────────────

@app.route('/clients')
def clients_list():
    conn = get_db()
    q = request.args.get('q', '')
    if q:
        clients = conn.execute(
            "SELECT * FROM clients WHERE name LIKE ? OR email LIKE ? ORDER BY name",
            (f'%{q}%', f'%{q}%')
        ).fetchall()
    else:
        clients = conn.execute('SELECT * FROM clients ORDER BY name').fetchall()
    conn.close()
    return render_template('clients/list.html', clients=clients, q=q)


@app.route('/clients/new', methods=['GET', 'POST'])
def client_new():
    if request.method == 'POST':
        name = request.form['name'].strip()
        if not name:
            flash('Le nom est obligatoire.', 'danger')
            return render_template('clients/form.html', client=None, action='Créer')
        conn = get_db()
        conn.execute(
            'INSERT INTO clients (name, email, phone, address, city, country) VALUES (?,?,?,?,?,?)',
            (name, request.form.get('email', ''), request.form.get('phone', ''),
             request.form.get('address', ''), request.form.get('city', ''),
             request.form.get('country', 'Madagascar'))
        )
        conn.commit()
        conn.close()
        flash('Client créé avec succès.', 'success')
        return redirect(url_for('clients_list'))
    return render_template('clients/form.html', client=None, action='Créer')


@app.route('/clients/<int:cid>/edit', methods=['GET', 'POST'])
def client_edit(cid):
    conn = get_db()
    client = conn.execute('SELECT * FROM clients WHERE id=?', (cid,)).fetchone()
    if not client:
        conn.close()
        flash('Client introuvable.', 'danger')
        return redirect(url_for('clients_list'))
    if request.method == 'POST':
        conn.execute(
            'UPDATE clients SET name=?,email=?,phone=?,address=?,city=?,country=? WHERE id=?',
            (request.form['name'], request.form.get('email', ''), request.form.get('phone', ''),
             request.form.get('address', ''), request.form.get('city', ''),
             request.form.get('country', 'Madagascar'), cid)
        )
        conn.commit()
        conn.close()
        flash('Client mis à jour.', 'success')
        return redirect(url_for('clients_list'))
    conn.close()
    return render_template('clients/form.html', client=client, action='Modifier')


@app.route('/clients/<int:cid>/delete', methods=['POST'])
def client_delete(cid):
    conn = get_db()
    conn.execute('DELETE FROM clients WHERE id=?', (cid,))
    conn.commit()
    conn.close()
    flash('Client supprimé.', 'info')
    return redirect(url_for('clients_list'))


# ── Factures ──────────────────────────────────────────────────────────────────

@app.route('/factures')
def invoices_list():
    conn = get_db()
    status_filter = request.args.get('status', '')
    q = request.args.get('q', '')

    query = '''
        SELECT i.*, c.name as client_name
        FROM invoices i JOIN clients c ON i.client_id = c.id
        WHERE 1=1
    '''
    params = []
    if status_filter:
        query += ' AND i.status=?'
        params.append(status_filter)
    if q:
        query += ' AND (c.name LIKE ? OR i.number LIKE ?)'
        params += [f'%{q}%', f'%{q}%']
    query += ' ORDER BY i.created_at DESC'

    invoices = conn.execute(query, params).fetchall()
    conn.close()

    invoices_with_totals = []
    today = datetime.today().strftime('%Y-%m-%d')
    for inv in invoices:
        _, _, _, total = invoice_total(inv['id'])
        is_overdue = inv['status'] not in ('payée', 'annulée') and inv['due_date'] < today
        invoices_with_totals.append({'invoice': inv, 'total': total, 'overdue': is_overdue})

    return render_template('invoices/list.html',
        invoices=invoices_with_totals,
        status_filter=status_filter,
        q=q,
    )


@app.route('/factures/new', methods=['GET', 'POST'])
def invoice_new():
    conn = get_db()
    clients = conn.execute('SELECT * FROM clients ORDER BY name').fetchall()

    if request.method == 'POST':
        client_id = request.form.get('client_id')
        if not client_id:
            flash('Veuillez sélectionner un client.', 'danger')
            conn.close()
            return render_template('invoices/form.html', invoice=None, items=[], clients=clients,
                                   action='Créer', today=datetime.today().strftime('%Y-%m-%d'))

        number = next_invoice_number()
        issue_date = request.form['issue_date']
        due_date = request.form['due_date']
        tax_rate = float(request.form.get('tax_rate', 20))
        discount = float(request.form.get('discount', 0))
        notes = request.form.get('notes', '')
        status = request.form.get('status', 'brouillon')

        cur = conn.execute(
            '''INSERT INTO invoices (number, client_id, issue_date, due_date, tax_rate, discount, notes, status)
               VALUES (?,?,?,?,?,?,?,?)''',
            (number, client_id, issue_date, due_date, tax_rate, discount, notes, status)
        )
        inv_id = cur.lastrowid

        descriptions = request.form.getlist('desc[]')
        quantities = request.form.getlist('qty[]')
        prices = request.form.getlist('price[]')
        for desc, qty, price in zip(descriptions, quantities, prices):
            if desc.strip():
                conn.execute(
                    'INSERT INTO invoice_items (invoice_id, description, quantity, unit_price) VALUES (?,?,?,?)',
                    (inv_id, desc.strip(), float(qty or 1), float(price or 0))
                )

        conn.commit()
        conn.close()
        flash(f'Facture {number} créée.', 'success')
        return redirect(url_for('invoice_view', inv_id=inv_id))

    today = datetime.today().strftime('%Y-%m-%d')
    due = (datetime.today() + timedelta(days=30)).strftime('%Y-%m-%d')
    conn.close()
    return render_template('invoices/form.html', invoice=None, items=[], clients=clients,
                           action='Créer', today=today, due=due,
                           tax_rate=20, discount=0)


@app.route('/factures/<int:inv_id>')
def invoice_view(inv_id):
    conn = get_db()
    inv = conn.execute(
        'SELECT i.*, c.name as client_name, c.email as client_email, c.phone as client_phone, '
        'c.address as client_address, c.city as client_city, c.country as client_country '
        'FROM invoices i JOIN clients c ON i.client_id=c.id WHERE i.id=?', (inv_id,)
    ).fetchone()
    if not inv:
        conn.close()
        flash('Facture introuvable.', 'danger')
        return redirect(url_for('invoices_list'))
    items = conn.execute('SELECT * FROM invoice_items WHERE invoice_id=?', (inv_id,)).fetchall()
    conn.close()
    subtotal, discount_amt, tax_amt, total = invoice_total(inv_id)
    today = datetime.today().strftime('%Y-%m-%d')
    is_overdue = inv['status'] not in ('payée', 'annulée') and inv['due_date'] < today
    return render_template('invoices/view.html',
        inv=inv, items=items,
        subtotal=subtotal, discount_amt=discount_amt, tax_amt=tax_amt, total=total,
        company=_company_info(), is_overdue=is_overdue,
    )


@app.route('/factures/<int:inv_id>/edit', methods=['GET', 'POST'])
def invoice_edit(inv_id):
    conn = get_db()
    inv = conn.execute('SELECT * FROM invoices WHERE id=?', (inv_id,)).fetchone()
    clients = conn.execute('SELECT * FROM clients ORDER BY name').fetchall()
    items = conn.execute('SELECT * FROM invoice_items WHERE invoice_id=?', (inv_id,)).fetchall()

    if request.method == 'POST':
        client_id = request.form.get('client_id')
        issue_date = request.form['issue_date']
        due_date = request.form['due_date']
        tax_rate = float(request.form.get('tax_rate', 20))
        discount = float(request.form.get('discount', 0))
        notes = request.form.get('notes', '')
        status = request.form.get('status', 'brouillon')

        conn.execute(
            '''UPDATE invoices SET client_id=?,issue_date=?,due_date=?,tax_rate=?,
               discount=?,notes=?,status=?,updated_at=datetime('now') WHERE id=?''',
            (client_id, issue_date, due_date, tax_rate, discount, notes, status, inv_id)
        )
        conn.execute('DELETE FROM invoice_items WHERE invoice_id=?', (inv_id,))

        descriptions = request.form.getlist('desc[]')
        quantities = request.form.getlist('qty[]')
        prices = request.form.getlist('price[]')
        for desc, qty, price in zip(descriptions, quantities, prices):
            if desc.strip():
                conn.execute(
                    'INSERT INTO invoice_items (invoice_id, description, quantity, unit_price) VALUES (?,?,?,?)',
                    (inv_id, desc.strip(), float(qty or 1), float(price or 0))
                )

        conn.commit()
        conn.close()
        flash('Facture mise à jour.', 'success')
        return redirect(url_for('invoice_view', inv_id=inv_id))

    conn.close()
    return render_template('invoices/form.html', invoice=inv, items=items, clients=clients,
                           action='Modifier', today=inv['issue_date'], due=inv['due_date'],
                           tax_rate=inv['tax_rate'], discount=inv['discount'])


@app.route('/factures/<int:inv_id>/status', methods=['POST'])
def invoice_status(inv_id):
    status = request.form.get('status')
    conn = get_db()
    conn.execute("UPDATE invoices SET status=?,updated_at=datetime('now') WHERE id=?", (status, inv_id))
    conn.commit()
    conn.close()
    flash(f'Statut mis à jour : {status}', 'success')
    return redirect(url_for('invoice_view', inv_id=inv_id))


@app.route('/factures/<int:inv_id>/delete', methods=['POST'])
def invoice_delete(inv_id):
    conn = get_db()
    conn.execute('DELETE FROM invoices WHERE id=?', (inv_id,))
    conn.commit()
    conn.close()
    flash('Facture supprimée.', 'info')
    return redirect(url_for('invoices_list'))


@app.route('/factures/<int:inv_id>/pdf')
def invoice_pdf(inv_id):
    conn = get_db()
    inv = conn.execute(
        'SELECT i.*, c.name as client_name, c.email as client_email, c.phone as client_phone, '
        'c.address as client_address, c.city as client_city, c.country as client_country '
        'FROM invoices i JOIN clients c ON i.client_id=c.id WHERE i.id=?', (inv_id,)
    ).fetchone()
    items = conn.execute('SELECT * FROM invoice_items WHERE invoice_id=?', (inv_id,)).fetchall()
    conn.close()

    subtotal, discount_amt, tax_amt, total = invoice_total(inv_id)
    pdf_bytes = generate_pdf(inv, items, subtotal, discount_amt, tax_amt, total, _company_info())
    return send_file(
        io.BytesIO(pdf_bytes),
        mimetype='application/pdf',
        as_attachment=True,
        download_name=f"facture_{inv['number']}.pdf"
    )


# ── Paramètres ────────────────────────────────────────────────────────────────

@app.route('/parametres', methods=['GET', 'POST'])
def settings():
    keys = ['company_name', 'company_address', 'company_email', 'company_phone',
            'company_city', 'currency', 'invoice_prefix']
    if request.method == 'POST':
        for key in keys:
            set_setting(key, request.form.get(key, ''))
        flash('Paramètres enregistrés.', 'success')
        return redirect(url_for('settings'))
    current = {k: get_setting(k) for k in keys}
    return render_template('settings.html', settings=current)


def _company_info():
    return {
        'name': get_setting('company_name'),
        'address': get_setting('company_address'),
        'email': get_setting('company_email'),
        'phone': get_setting('company_phone'),
        'city': get_setting('company_city'),
        'currency': get_setting('currency'),
    }


if __name__ == '__main__':
    init_db()
    print("\n✅ Gestionnaire de Factures démarré !")
    print("👉  Ouvrez votre navigateur sur : http://localhost:5000\n")
    app.run(debug=False, port=5000)
