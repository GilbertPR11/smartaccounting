import 'package:flutter/material.dart';

import '../models/business_profile_model.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../models/invoice_template_model.dart';
import '../utils/format.dart';

/// The invoice as the customer sees it, styled by an [InvoiceTemplate].
///
/// This one widget is used by the invoice page AND the design preview, so
/// what users design is exactly what they get. Paper is always white with
/// dark ink, regardless of the app's light/dark theme.
///
/// Status (Paid/Overdue) is deliberately NOT drawn here: it's for the
/// business, not something printed on the customer's copy.
class InvoiceDocument extends StatelessWidget {
  const InvoiceDocument({
    super.key,
    required this.invoice,
    required this.customer,
    required this.profile,
    required this.template,
  });

  final Invoice invoice;
  final Customer? customer;
  final BusinessProfile profile;
  final InvoiceTemplate template;

  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);
  static const _rule = Color(0xFFE5E7EB);

  bool get _compact => template.layout == InvoiceLayout.compact;
  double get _pad => _compact ? 16 : 24;

  @override
  Widget build(BuildContext context) {
    final accent = Color(template.accentColor);
    final base = TextStyle(
      color: _ink,
      fontSize: _compact ? 12 : 13,
      height: 1.35,
      fontWeight: FontWeight.normal,
    );

    return DefaultTextStyle(
      style: base,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(accent),
            Padding(
              padding: EdgeInsets.fromLTRB(_pad, _compact ? 12 : 20, _pad, _pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _billToAndMeta(),
                  SizedBox(height: _compact ? 12 : 20),
                  _items(accent),
                  const SizedBox(height: 12),
                  _totals(accent),
                  ..._bottom(accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ header

  List<String> get _businessLines => [
        if (template.showBusinessAddress && profile.address.isNotEmpty) profile.address,
        if (template.showBusinessContact)
          [profile.email, profile.phone].where((s) => s.isNotEmpty).join('  ·  '),
        if (template.showRegistrationNo && profile.registrationNo.isNotEmpty)
          'Reg. no. ${profile.registrationNo}',
        if (template.showSstNo && profile.sstNo.isNotEmpty) 'SST reg. no. ${profile.sstNo}',
      ].where((s) => s.isNotEmpty).toList();

  Widget? _logo() {
    if (!template.showLogo || !template.hasLogo) return null;
    final h = template.logoSize.height * (_compact ? 0.8 : 1);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: h, maxWidth: h * 3),
      child: Image.memory(template.logoBytes!, fit: BoxFit.contain, gaplessPlayback: true),
    );
  }

  Widget _header(Color accent) {
    final logo = _logo();
    final lines = _businessLines;
    final titleStyle = TextStyle(
      fontSize: _compact ? 18 : 24,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
    );

    switch (template.layout) {
      case InvoiceLayout.modern:
        const onAccent = Colors.white;
        return Container(
          color: accent,
          padding: EdgeInsets.all(_pad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: logo,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name,
                        style: const TextStyle(
                            color: onAccent, fontWeight: FontWeight.w700, fontSize: 15)),
                    for (final l in lines)
                      Text(l, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(template.title, style: titleStyle.copyWith(color: onAccent)),
            ],
          ),
        );

      case InvoiceLayout.compact:
        return Container(
          padding: EdgeInsets.fromLTRB(_pad, _pad, _pad, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: accent, width: 2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (logo != null) ...[logo, const SizedBox(width: 10)],
                  Expanded(
                    child: Text(profile.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Text(template.title, style: titleStyle.copyWith(color: accent)),
                ],
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(lines.join('  |  '), style: const TextStyle(color: _muted, fontSize: 10)),
              ],
            ],
          ),
        );

      case InvoiceLayout.classic:
        return Padding(
          padding: EdgeInsets.fromLTRB(_pad, _pad, _pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (logo != null) ...[logo, const SizedBox(height: 10)],
                        Text(profile.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        for (final l in lines)
                          Text(l, style: const TextStyle(color: _muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(template.title, style: titleStyle.copyWith(color: accent)),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 3, color: accent),
            ],
          ),
        );
    }
  }

  // --------------------------------------------------------- bill to + meta

  Widget _billToAndMeta() {
    final c = customer;
    const label = TextStyle(color: _muted, fontSize: 11);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BILL TO', style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(c?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (c != null && template.showCustomerAddress && c.address.isNotEmpty)
                Text(c.address, style: const TextStyle(color: _muted, fontSize: 11)),
              if (c != null && template.showCustomerEmail && c.email.isNotEmpty)
                Text(c.email, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Invoice no.', style: label),
            Text(invoice.number, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Date', style: label),
            Text(fmtDate(invoice.issueDate)),
            if (template.showDueDate) ...[
              const SizedBox(height: 6),
              const Text('Due', style: label),
              Text(invoice.dueDate == invoice.issueDate ? 'On receipt' : fmtDate(invoice.dueDate)),
            ],
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- items

  Widget _items(Color accent) {
    final showQty = template.showQuantityColumns;
    final head = TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

    Widget row(List<Widget> cells, {Color? background, Border? border}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(color: background, border: border),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          [
            Expanded(flex: 6, child: Text('DESCRIPTION', style: head)),
            if (showQty) ...[
              Expanded(flex: 2, child: Text('QTY', style: head, textAlign: TextAlign.right)),
              Expanded(flex: 3, child: Text('PRICE', style: head, textAlign: TextAlign.right)),
            ],
            Expanded(flex: 3, child: Text('AMOUNT', style: head, textAlign: TextAlign.right)),
          ],
          background: accent.withOpacity(0.08),
          border: Border(bottom: BorderSide(color: accent.withOpacity(0.5))),
        ),
        for (final l in invoice.lines)
          row(
            [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.description),
                    if (template.showLineTax && l.tax != null)
                      Text(l.tax!.label, style: const TextStyle(color: _muted, fontSize: 10)),
                    if (!showQty && l.quantity != 1)
                      Text('${fmtQty(l.quantity)} × ${money(l.unitPrice)}',
                          style: const TextStyle(color: _muted, fontSize: 10)),
                  ],
                ),
              ),
              if (showQty) ...[
                Expanded(flex: 2, child: Text(fmtQty(l.quantity), textAlign: TextAlign.right)),
                Expanded(
                    flex: 3, child: Text(money(l.unitPrice), textAlign: TextAlign.right)),
              ],
              Expanded(flex: 3, child: Text(money(l.subtotal), textAlign: TextAlign.right)),
            ],
            border: const Border(bottom: BorderSide(color: _rule)),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------ totals

  Widget _totals(Color accent) {
    Widget line(String label, String value, {bool bold = false, Color? color}) {
      final style = TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        fontSize: bold ? (_compact ? 13 : 14) : null,
        color: color,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(value, style: style),
          ],
        ),
      );
    }

    final paid = invoice.amountPaid;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          children: [
            line('Subtotal', money(invoice.subtotal)),
            if (template.showTaxBreakdown)
              for (final e in invoice.taxBreakdown.entries) line(e.key, money(e.value))
            else if (invoice.taxTotal > 0)
              line('Tax', money(invoice.taxTotal)),
            const Divider(height: 12, color: _rule),
            line('Total', money(invoice.total), bold: true),
            if (template.showAmountPaid && paid > 0) ...[
              line('Paid', '-${money(paid)}'),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: accent.withOpacity(0.08),
                child: line('Amount due', money(invoice.balance), bold: true, color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ bottom

  List<Widget> _bottom(Color accent) {
    const label = TextStyle(color: _muted, fontSize: 11, letterSpacing: 1);
    return [
      if (template.showNotes && invoice.notes.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('NOTES', style: label),
        const SizedBox(height: 2),
        Text(invoice.notes),
      ],
      if (template.showPaymentInstructions && template.paymentInstructions.isNotEmpty) ...[
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 3)),
            color: accent.withOpacity(0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PAYMENT', style: label),
              const SizedBox(height: 2),
              Text(template.paymentInstructions),
            ],
          ),
        ),
      ],
      if (template.showFooter && template.footerText.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(template.footerText,
            textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 11)),
      ],
    ];
  }
}
