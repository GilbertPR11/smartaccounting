import 'package:flutter/material.dart';

import '../../../../config/constants.dart';
import '../../../../models/business_profile_model.dart';
import '../../../../models/invoice_template_model.dart';

/// The left-hand (or "Edit" tab) panel of the invoice designer.
/// Pure UI: reports every change through the callbacks; owns no data.
class TemplateEditorSections extends StatefulWidget {
  const TemplateEditorSections({
    super.key,
    required this.profile,
    required this.template,
    required this.pickingLogo,
    required this.onProfileChanged,
    required this.onTemplateChanged,
    required this.onPickLogo,
  });

  final BusinessProfile profile;
  final InvoiceTemplate template;
  final bool pickingLogo;
  final ValueChanged<BusinessProfile> onProfileChanged;
  final ValueChanged<InvoiceTemplate> onTemplateChanged;
  final VoidCallback onPickLogo;

  @override
  State<TemplateEditorSections> createState() => _TemplateEditorSectionsState();
}

class _TemplateEditorSectionsState extends State<TemplateEditorSections> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _address = TextEditingController(text: widget.profile.address);
  late final _email = TextEditingController(text: widget.profile.email);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _regNo = TextEditingController(text: widget.profile.registrationNo);
  late final _sstNo = TextEditingController(text: widget.profile.sstNo);
  late final _title = TextEditingController(text: widget.template.title);
  late final _payment = TextEditingController(text: widget.template.paymentInstructions);
  late final _footer = TextEditingController(text: widget.template.footerText);

  @override
  void dispose() {
    for (final c in [_name, _address, _email, _phone, _regNo, _sstNo, _title, _payment, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  BusinessProfile get p => widget.profile;
  InvoiceTemplate get t => widget.template;
  void setP(BusinessProfile v) => widget.onProfileChanged(v);
  void setT(InvoiceTemplate v) => widget.onTemplateChanged(v);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _Section(
          title: 'Look',
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<InvoiceLayout>(
                segments: [
                  for (final l in InvoiceLayout.values)
                    ButtonSegment(value: l, label: Text(l.label)),
                ],
                selected: {t.layout},
                onSelectionChanged: (s) => setT(t.copyWith(layout: s.first)),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Accent colour'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in Constants.invoiceAccentColors)
                  _Swatch(
                    color: Color(c),
                    selected: t.accentColor == c,
                    onTap: () => setT(t.copyWith(accentColor: c)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Document title',
                helperText: 'e.g. INVOICE, TAX INVOICE, RECEIPT',
              ),
              onChanged: (v) => setT(t.copyWith(title: v)),
            ),
          ],
        ),
        _Section(
          title: 'Logo',
          children: [
            Row(
              children: [
                _LogoThumb(template: t),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: widget.pickingLogo ? null : widget.onPickLogo,
                        icon: const Icon(Icons.upload_outlined, size: 18),
                        label: Text(t.hasLogo ? 'Replace' : 'Upload logo'),
                      ),
                      if (t.hasLogo)
                        OutlinedButton(
                          onPressed: () => setT(t.copyWith(clearLogo: true)),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (t.hasLogo) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const _Label('Size'),
                  const Spacer(),
                  SegmentedButton<LogoSize>(
                    showSelectedIcon: false,
                    segments: [
                      for (final s in LogoSize.values)
                        ButtonSegment(value: s, label: Text(s.label)),
                    ],
                    selected: {t.logoSize},
                    onSelectionChanged: (s) => setT(t.copyWith(logoSize: s.first)),
                  ),
                ],
              ),
              _Toggle('Show logo', t.showLogo, (v) => setT(t.copyWith(showLogo: v))),
            ],
            const SizedBox(height: 4),
            Text('PNG or JPG. A transparent PNG looks best on the Modern layout.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        _Section(
          title: 'Business details',
          children: [
            _Field(_name, 'Business name *', (v) => setP(p.copyWith(name: v))),
            _Field(_address, 'Address', (v) => setP(p.copyWith(address: v)), maxLines: 3),
            _Field(_email, 'Email', (v) => setP(p.copyWith(email: v)),
                keyboard: TextInputType.emailAddress),
            _Field(_phone, 'Phone', (v) => setP(p.copyWith(phone: v)),
                keyboard: TextInputType.phone),
            _Field(_regNo, 'Company registration no. (SSM)',
                (v) => setP(p.copyWith(registrationNo: v))),
            _Field(_sstNo, 'SST registration no.', (v) => setP(p.copyWith(sstNo: v))),
          ],
        ),
        _Section(
          title: 'Show on invoice',
          children: [
            const _Label('Header'),
            _Toggle('Business address', t.showBusinessAddress,
                (v) => setT(t.copyWith(showBusinessAddress: v))),
            _Toggle('Email & phone', t.showBusinessContact,
                (v) => setT(t.copyWith(showBusinessContact: v))),
            _Toggle('Registration no.', t.showRegistrationNo,
                (v) => setT(t.copyWith(showRegistrationNo: v))),
            _Toggle('SST registration no.', t.showSstNo,
                (v) => setT(t.copyWith(showSstNo: v))),
            const Divider(height: 24),
            const _Label('Customer'),
            _Toggle('Customer address', t.showCustomerAddress,
                (v) => setT(t.copyWith(showCustomerAddress: v))),
            _Toggle('Customer email', t.showCustomerEmail,
                (v) => setT(t.copyWith(showCustomerEmail: v))),
            _Toggle('Due date', t.showDueDate, (v) => setT(t.copyWith(showDueDate: v))),
            const Divider(height: 24),
            const _Label('Items & totals'),
            _Toggle('Quantity & unit price columns', t.showQuantityColumns,
                (v) => setT(t.copyWith(showQuantityColumns: v))),
            _Toggle('Tax rate on each item', t.showLineTax,
                (v) => setT(t.copyWith(showLineTax: v))),
            _Toggle('Tax breakdown by rate', t.showTaxBreakdown,
                (v) => setT(t.copyWith(showTaxBreakdown: v)),
                subtitle: 'Off shows a single "Tax" line'),
            _Toggle('Amount paid & amount due', t.showAmountPaid,
                (v) => setT(t.copyWith(showAmountPaid: v))),
            const Divider(height: 24),
            const _Label('Bottom'),
            _Toggle('Invoice notes', t.showNotes, (v) => setT(t.copyWith(showNotes: v))),
            _Toggle('Payment instructions', t.showPaymentInstructions,
                (v) => setT(t.copyWith(showPaymentInstructions: v))),
            if (t.showPaymentInstructions)
              _Field(_payment, 'Payment instructions',
                  (v) => setT(t.copyWith(paymentInstructions: v)),
                  maxLines: 3, hint: 'Bank name, account number, reference to quote'),
            _Toggle('Footer', t.showFooter, (v) => setT(t.copyWith(showFooter: v))),
            if (t.showFooter)
              _Field(_footer, 'Footer text', (v) => setT(t.copyWith(footerText: v))),
          ],
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- pieces

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant));
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged, {this.subtitle});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: onChanged,
      );
}

class _Field extends StatelessWidget {
  const _Field(this.controller, this.label, this.onChanged,
      {this.maxLines = 1, this.keyboard, this.hint});

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextInputType? keyboard;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: 1,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
          decoration: InputDecoration(labelText: label, hintText: hint),
          onChanged: onChanged,
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
        ),
      ),
    );
  }
}

class _LogoThumb extends StatelessWidget {
  const _LogoThumb({required this.template});

  final InvoiceTemplate template;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: template.hasLogo
          ? Image.memory(template.logoBytes!, fit: BoxFit.contain, gaplessPlayback: true)
          : Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
    );
  }
}
