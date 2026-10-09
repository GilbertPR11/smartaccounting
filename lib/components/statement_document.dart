import 'package:flutter/material.dart';

import '../models/business_profile_model.dart';
import '../models/customer_model.dart';
import '../models/invoice_template_model.dart';
import '../utils/format.dart';
import '../utils/statement.dart';

/// A customer statement as the customer sees it: white paper, the invoice
/// design's logo and accent colour, then either the outstanding invoices or
/// the account activity for a period. Pass exactly one of [outstanding] or
/// [activity].
class StatementDocument extends StatelessWidget {
  const StatementDocument({
    super.key,
    required this.customer,
    required this.profile,
    required this.template,
    this.outstanding,
    this.activity,
  }) : assert((outstanding == null) != (activity == null));

  final Customer customer;
  final BusinessProfile profile;
  final InvoiceTemplate template;
  final OutstandingStatement? outstanding;
  final ActivityStatement? activity;

  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);
  static const _rule = Color(0xFFE5E7EB);
  static const _small = TextStyle(color: _muted, fontSize: 11);

  @override
  Widget build(BuildContext context) {
    final accent = Color(template.accentColor);
    return DefaultTextStyle(
      style: const TextStyle(color: _ink, fontSize: 12.5, height: 1.35),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(accent),
            const SizedBox(height: 14),
            Container(height: 3, color: accent),
            const SizedBox(height: 16),
            _parties(),
            const SizedBox(height: 18),
            _summary(accent),
            const SizedBox(height: 18),
            ..._table(accent),
            if (template.showPaymentInstructions &&
                template.paymentInstructions.isNotEmpty &&
                _amountDue > 0.004) ...[
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
                    const Text('PAYMENT', style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(template.paymentInstructions),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double get _amountDue => outstanding?.total ?? activity!.closing;

  Widget _header(Color accent) {
    final logo = template.showLogo && template.hasLogo
        ? ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: template.logoSize.height, maxWidth: template.logoSize.height * 3),
            child: Image.memory(template.logoBytes!, fit: BoxFit.contain, gaplessPlayback: true),
          )
        : null;
    final contact = [profile.email, profile.phone].where((s) => s.isNotEmpty).join('  ·  ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[logo, const SizedBox(height: 10)],
              Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (template.showBusinessAddress && profile.address.isNotEmpty)
                Text(profile.address, style: _small),
              if (template.showBusinessContact && contact.isNotEmpty) Text(contact, style: _small),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text('STATEMENT',
            style: TextStyle(
                color: accent, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
      ],
    );
  }

  Widget _parties() {
    final o = outstanding;
    final a = activity;
    final period = o != null
        ? 'Outstanding as of ${fmtDate(o.asOf)}'
        : '${fmtDate(a!.from)} – ${fmtDate(a.to)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('STATEMENT FOR',
                  style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (template.showCustomerAddress && customer.address.isNotEmpty)
                Text(customer.address, style: _small),
              if (customer.email.isNotEmpty) Text(customer.email, style: _small),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(o != null ? 'Type' : 'Period', style: _small),
            Text(o != null ? 'Outstanding invoices' : 'Account activity',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(period, style: _small),
          ],
        ),
      ],
    );
  }

  Widget _summary(Color accent) {
    final o = outstanding;
    final a = activity;
    final rows = <(String, double)>[
      if (a != null) ...[
        ('Balance brought forward', a.opening),
        ('Invoiced', a.invoiced),
        ('Payments', -a.paid),
      ],
      if (o != null)
        for (final e in o.aging.entries)
          if (e.value > 0) (e.key == 'Not yet due' ? e.key : '${e.key} overdue', e.value),
    ];
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [Expanded(child: Text(label)), Text(money(value))]),
              ),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: accent.withOpacity(0.08),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Amount due',
                        style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                  ),
                  Text(money(_amountDue),
                      style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _table(Color accent) {
    final head = TextStyle(
        color: accent, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5);

    Widget row(List<(String, int, TextAlign)> cells, {TextStyle? style, bool header = false}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: header ? accent.withOpacity(0.08) : null,
            border: Border(
                bottom: BorderSide(color: header ? accent.withOpacity(0.5) : _rule)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (value, flex, align) in cells)
                Expanded(flex: flex, child: Text(value, style: style, textAlign: align)),
            ],
          ),
        );

    const l = TextAlign.left;
    const r = TextAlign.right;
    final o = outstanding;
    if (o != null) {
      if (o.items.isEmpty) return [const Text('No outstanding invoices. Thank you!')];
      return [
        row([('INVOICE', 3, l), ('DUE', 3, l), ('TOTAL', 3, r), ('PAID', 3, r), ('DUE NOW', 3, r)],
            style: head, header: true),
        for (final i in o.items)
          row([
            (i.invoice.number, 3, l),
            (i.daysOverdue > 0
                ? '${fmtDate(i.invoice.dueDate)}\n${i.daysOverdue} days late'
                : fmtDate(i.invoice.dueDate), 3, l),
            (money(i.invoice.total), 3, r),
            (money(i.invoice.amountPaid), 3, r),
            (money(i.invoice.balance), 3, r),
          ]),
      ];
    }
    final a = activity!;
    return [
      row([('DATE', 3, l), ('DETAILS', 6, l), ('AMOUNT', 3, r), ('BALANCE', 3, r)],
          style: head, header: true),
      row([
        (fmtDate(a.from), 3, l),
        ('Balance brought forward', 6, l),
        ('', 3, r),
        (money(a.opening), 3, r),
      ]),
      for (final e in a.entries)
        row([
          (fmtDate(e.date), 3, l),
          ('${e.reference}\n${e.description}', 6, l),
          (e.isInvoice ? money(e.amount) : '-${money(e.amount)}', 3, r),
          (money(e.balance), 3, r),
        ]),
      if (a.entries.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('No invoices or payments in this period.', style: _small),
        ),
    ];
  }
}
