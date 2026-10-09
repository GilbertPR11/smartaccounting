import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/setting/setting_bloc.dart';
import '../../../components/invoice_document.dart';
import '../../../config/constants.dart';
import '../../../config/layout.dart';
import '../../../models/business_profile_model.dart';
import '../../../models/customer_model.dart';
import '../../../models/invoice_model.dart';
import '../../../models/invoice_template_model.dart';
import '../../../repository/setting_repository.dart';
import 'widgets/template_editor_sections.dart';

/// Invoice design: logo, layout, colour, what to show, business details.
///
/// Edits are a local draft with a live preview; nothing changes on real
/// invoices until Save. Wide screens: editor left, preview right.
/// Phones: Edit / Preview tabs.
class InvoiceTemplatePage extends StatefulWidget {
  const InvoiceTemplatePage({super.key});

  @override
  State<InvoiceTemplatePage> createState() => _InvoiceTemplatePageState();
}

class _InvoiceTemplatePageState extends State<InvoiceTemplatePage> {
  late BusinessProfile _profile;
  late InvoiceTemplate _template;
  bool _dirty = false;
  bool _pickingLogo = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingBloc>().state;
    _profile = s.profile;
    _template = s.template;
  }

  void _setProfile(BusinessProfile p) => setState(() {
        _profile = p;
        _dirty = true;
      });

  void _setTemplate(InvoiceTemplate t) => setState(() {
        _template = t;
        _dirty = true;
      });

  Future<void> _pickLogo() async {
    setState(() => _pickingLogo = true);
    try {
      // Resized on pick so a 12 MP phone photo doesn't end up on every invoice.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > Constants.maxLogoBytes) {
        _snack('That image is too large. Please choose one under 2 MB.');
        return;
      }
      _setTemplate(_template.copyWith(logoBytes: bytes, showLogo: true));
    } catch (e) {
      if (mounted) _snack('Could not open the image: $e');
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  void _save() => context
      .read<SettingBloc>()
      .add(SaveInvoiceSettings(profile: _profile, template: _template));

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your invoice design changes have not been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return leave == true;
  }

  /// Most recent real invoice, or a built-in sample when there are none.
  (Invoice, Customer?) _previewInvoice() {
    final invoices = context.watch<InvoiceBloc>().state.invoices;
    if (invoices.isNotEmpty) {
      final inv = invoices.first;
      return (inv, context.watch<CustomerBloc>().state.byId(inv.customerId));
    }
    final today = context.read<SettingRepository>().today;
    return (
      Invoice(
        id: 'sample',
        number: 'INV-0001',
        customerId: 'sample',
        issueDate: today,
        dueDate: today.add(const Duration(days: 30)),
        lines: [
          InvoiceLine(
              description: 'Consulting (per hour)',
              quantity: 3,
              unitPrice: 250,
              tax: Constants.taxes.first),
          const InvoiceLine(description: 'Setup fee', unitPrice: 500),
        ],
        notes: 'Sample invoice for preview.',
        amountPaid: 200,
      ),
      const Customer(
          id: 'sample',
          name: 'Sample Customer Sdn Bhd',
          email: 'accounts@customer.example',
          address: '1, Jalan Sampel, 50000 Kuala Lumpur'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving =
        context.select<SettingBloc, bool>((b) => b.state.saveStatus == SaveStatus.saving);
    final (invoice, customer) = _previewInvoice();

    final editor = TemplateEditorSections(
      profile: _profile,
      template: _template,
      pickingLogo: _pickingLogo,
      onProfileChanged: _setProfile,
      onTemplateChanged: _setTemplate,
      onPickLogo: _pickLogo,
    );

    Widget preview(double maxWidth) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: LayoutBuilder(builder: (context, c) {
            final pad = sidePadding(c.maxWidth, maxWidth: maxWidth);
            return ListView(
              padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
              children: [
                InvoiceDocument(
                  invoice: invoice,
                  customer: customer,
                  profile: _profile,
                  template: _template,
                ),
              ],
            );
          }),
        );

    return BlocListener<SettingBloc, SettingState>(
      listenWhen: (a, b) => a.saveStatus != b.saveStatus,
      listener: (context, state) {
        if (state.saveStatus == SaveStatus.saved) {
          setState(() => _dirty = false);
          _snack('Invoice design saved');
        } else if (state.saveStatus == SaveStatus.failed) {
          _snack(state.error ?? 'Could not save.');
        }
      },
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _confirmDiscard() && context.mounted) {
            setState(() => _dirty = false);
            Navigator.pop(context);
          }
        },
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= Breakpoints.twoPane;
          // AppBar stretches actions to the full toolbar height; Center keeps
          // the buttons at their natural size, vertically centred on the title.
          final actions = <Widget>[
            Center(
              child: TextButton(
                onPressed: () => _setTemplate(_template.resetDesign()),
                child: const Text('Reset design'),
              ),
            ),
            const SizedBox(width: 8),
            Center(
              child: FilledButton(
                onPressed: _dirty && !saving ? _save : null,
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ),
            const SizedBox(width: 16),
          ];

          if (wide) {
            return Scaffold(
              appBar: AppBar(title: const Text('Invoice design'), actions: actions),
              body: Row(
                children: [
                  SizedBox(width: c.maxWidth >= 1300 ? 440 : 400, child: editor),
                  const VerticalDivider(width: 1),
                  Expanded(child: preview(820)),
                ],
              ),
            );
          }

          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Invoice design'),
                actions: actions,
                bottom: const TabBar(tabs: [Tab(text: 'Edit'), Tab(text: 'Preview')]),
              ),
              body: TabBarView(
                // Swiping would fight with the sliders/switches in the editor.
                physics: const NeverScrollableScrollPhysics(),
                children: [editor, preview(720)],
              ),
            ),
          );
        }),
      ),
    );
  }
}
