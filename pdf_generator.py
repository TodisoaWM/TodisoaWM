from fpdf import FPDF
from datetime import datetime


def generate_pdf(inv, items, subtotal, discount_amt, tax_amt, total, company):
    pdf = FPDF()
    pdf.add_page()
    currency = company.get('currency', 'Ar')

    # ── En-tête ──────────────────────────────────────────────────────────────
    pdf.set_fill_color(37, 99, 235)
    pdf.rect(0, 0, 210, 40, 'F')

    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Helvetica', 'B', 22)
    pdf.set_xy(15, 8)
    pdf.cell(100, 10, company.get('name', 'Mon Entreprise'))

    pdf.set_font('Helvetica', '', 9)
    pdf.set_xy(15, 20)
    pdf.cell(100, 5, company.get('address', ''))
    pdf.set_xy(15, 26)
    pdf.cell(100, 5, company.get('city', ''))
    pdf.set_xy(15, 32)
    pdf.cell(100, 5, company.get('email', '') + '  ' + company.get('phone', ''))

    pdf.set_font('Helvetica', 'B', 28)
    pdf.set_xy(130, 8)
    pdf.cell(65, 12, 'FACTURE', align='R')

    pdf.set_font('Helvetica', '', 10)
    pdf.set_xy(130, 22)
    pdf.cell(65, 6, f"N° {inv['number']}", align='R')
    pdf.set_xy(130, 28)
    issue = _fmt_date(inv['issue_date'])
    pdf.cell(65, 6, f"Date : {issue}", align='R')
    pdf.set_xy(130, 34)
    due = _fmt_date(inv['due_date'])
    pdf.cell(65, 6, f"Échéance : {due}", align='R')

    # ── Statut ───────────────────────────────────────────────────────────────
    pdf.set_xy(0, 0)
    status_colors = {
        'payée': (22, 163, 74),
        'brouillon': (107, 114, 128),
        'envoyée': (37, 99, 235),
        'annulée': (185, 28, 28),
    }
    sc = status_colors.get(inv['status'], (107, 114, 128))
    pdf.set_fill_color(*sc)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_xy(155, 5)
    pdf.cell(40, 7, inv['status'].upper(), align='C', fill=True)

    # ── Info client ───────────────────────────────────────────────────────────
    pdf.set_text_color(30, 30, 30)
    pdf.set_xy(15, 50)
    pdf.set_font('Helvetica', 'B', 10)
    pdf.cell(80, 6, 'FACTURER À :')
    pdf.set_font('Helvetica', 'B', 11)
    pdf.set_xy(15, 57)
    pdf.cell(80, 6, inv['client_name'])
    pdf.set_font('Helvetica', '', 9)
    y = 64
    for field in ['client_address', 'client_city', 'client_country', 'client_email', 'client_phone']:
        val = (inv[field] if field in inv.keys() else '') or ''
        if val:
            pdf.set_xy(15, y)
            pdf.cell(80, 5, val)
            y += 5

    # ── Séparateur ────────────────────────────────────────────────────────────
    pdf.set_draw_color(200, 200, 200)
    pdf.line(15, max(y, 85), 195, max(y, 85))
    y = max(y, 85) + 5

    # ── Tableau des articles ──────────────────────────────────────────────────
    pdf.set_fill_color(37, 99, 235)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_xy(15, y)
    col_widths = [90, 25, 30, 30]
    headers = ['Description', 'Qté', f'Prix unit. ({currency})', f'Total ({currency})']
    for i, (h, w) in enumerate(zip(headers, col_widths)):
        pdf.cell(w, 8, h, fill=True, border=0, align='C' if i > 0 else 'L')
    y += 8

    pdf.set_text_color(30, 30, 30)
    pdf.set_font('Helvetica', '', 9)
    for idx, item in enumerate(items):
        bg = (248, 250, 252) if idx % 2 == 0 else (255, 255, 255)
        pdf.set_fill_color(*bg)
        line_total = item['quantity'] * item['unit_price']
        pdf.set_xy(15, y)
        pdf.cell(col_widths[0], 8, item['description'], fill=True, border=0)
        pdf.cell(col_widths[1], 8, str(int(item['quantity'])), fill=True, border=0, align='C')
        pdf.cell(col_widths[2], 8, _fmt_num(item['unit_price']), fill=True, border=0, align='R')
        pdf.cell(col_widths[3], 8, _fmt_num(line_total), fill=True, border=0, align='R')
        y += 8

    y += 5

    # ── Totaux ───────────────────────────────────────────────────────────────
    def total_row(label, value, bold=False):
        nonlocal y
        pdf.set_xy(120, y)
        if bold:
            pdf.set_font('Helvetica', 'B', 10)
            pdf.set_fill_color(37, 99, 235)
            pdf.set_text_color(255, 255, 255)
            pdf.cell(40, 9, label, fill=True, border=0, align='L')
            pdf.cell(35, 9, f"{_fmt_num(value)} {currency}", fill=True, border=0, align='R')
        else:
            pdf.set_font('Helvetica', '', 9)
            pdf.set_text_color(80, 80, 80)
            pdf.cell(40, 7, label, border=0, align='L')
            pdf.cell(35, 7, f"{_fmt_num(value)} {currency}", border=0, align='R')
        y += 9 if bold else 7

    tax_rate = inv['tax_rate'] if 'tax_rate' in inv.keys() else 20
    discount = inv['discount'] if 'discount' in inv.keys() else 0

    total_row('Sous-total', subtotal)
    if discount > 0:
        total_row(f'Remise ({discount}%)', -discount_amt)
    total_row(f'TVA ({tax_rate}%)', tax_amt)
    pdf.set_draw_color(37, 99, 235)
    pdf.line(120, y, 195, y)
    y += 2
    total_row('TOTAL', total, bold=True)

    # ── Notes ─────────────────────────────────────────────────────────────────
    notes = (inv['notes'] if 'notes' in inv.keys() else '') or ''
    if notes:
        y += 10
        pdf.set_text_color(30, 30, 30)
        pdf.set_font('Helvetica', 'B', 9)
        pdf.set_xy(15, y)
        pdf.cell(100, 6, 'Notes :')
        pdf.set_font('Helvetica', 'I', 9)
        pdf.set_xy(15, y + 6)
        pdf.multi_cell(160, 5, notes)

    # ── Pied de page ──────────────────────────────────────────────────────────
    pdf.set_y(-20)
    pdf.set_draw_color(200, 200, 200)
    pdf.line(15, pdf.get_y(), 195, pdf.get_y())
    pdf.set_font('Helvetica', 'I', 8)
    pdf.set_text_color(150, 150, 150)
    pdf.set_y(-15)
    footer = f"Genere le {datetime.now().strftime('%d/%m/%Y a %H:%M')} - {company.get('name', '')}"
    pdf.cell(0, 5, footer, align='C')

    return pdf.output()


def _fmt_date(d):
    try:
        return datetime.strptime(d, '%Y-%m-%d').strftime('%d/%m/%Y')
    except Exception:
        return d or ''


def _fmt_num(v):
    try:
        return f"{float(v):,.0f}".replace(',', ' ')
    except Exception:
        return '0'
