import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/estimate/estimate_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/setting/setting_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/invoice_document.dart';
import '../../../components/invoice_tile.dart';
import '../../../components/section_header.dart';
import '../../../components/status_chip.dart';
import '../../../exception/app_exception.dart';
import '../../../models/estimate_model.dart';
import '../../../repository/estimate_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../invoice/new_invoice_flow.dart';
import 'estimate_flows.dart';

enum _Action { edit, duplicate, accepted, declined, reset, delete }

/// One estimate: the document, the customer's answer, and "Convert to invoice".
class EstimateDetailPage extends StatefulWidget {
  const EstimateDetailPage({
    super.key,
    required this.estimateId,
    this.justSaved = false,
    this.embedded = false,
  });

  final String estimateId;
  final bool justSaved;

  /// True when shown as the right-hand pane of the list.
  final bool embedded;

  @override
  State<EstimateDetailPage> createState() => _EstimateDetailPageState();
}

class _EstimateDetailPageState extends State<EstimateDetailPage> {
  @override
  void initState() {
    super.initState();
    if (widget.justSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final e = context.read<EstimateBloc>().state.byId(widget.estimateId);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${e?.number ?? 'Estimate'} saved')));
      });
    }
  }

  Future<void> _onAction(_Action action, Estimate e) async {
    final bloc = context.read<EstimateBloc>();
    switch (action) {
      case _Action.edit:
        await openEstimateForm(context, estimate: e);
      case _Action.accepted:
        bloc.add(SetEstimateDecision(e.id, EstimateDecision.accepted));
      case _Action.declined:
        bloc.add(SetEstimateDecision(e.id, EstimateDecision.declined));
      case _Action.reset:
        bloc.add(SetEstimateDecision(e.id, null));
      case _Action.duplicate:
        // Direct repository call: we need the new estimate's id to open it.
        // EstimateBloc picks the change up through the change stream.
        try {
          final copy = await context.read<EstimateRepository>().duplicate(e.id);
          if (mounted) await openEstimateDetail(context, copy.id);
        } on AppException catch (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
          }
        }
      case _Action.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete ${e.number}?'),
            content: const Text('This can\'t be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        bloc.add(DeleteEstimate(e.id));
        if (!widget.embedded) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final e = context.watch<EstimateBloc>().state.byId(widget.estimateId);
    if (e == null) {
      return const Scaffold(body: Center(child: Text('Estimate not found')));
    }
    final customer = context.watch<CustomerBloc>().state.byId(e.customerId);
    final settingState = context.watch<SettingBloc>().state;
    final invoice = context.watch<InvoiceBloc>().state.byId(e.invoiceId);
    final status = e.statusOn(today);
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final canConvert = !e.isConverted && status != EstimateStatus.declined;
    final awaiting = status == EstimateStatus.pending || status == EstimateStatus.expired;

    final statusText = switch (status) {
      EstimateStatus.pending || EstimateStatus.expired => relativeExpiry(e.expiryDate, today),
      EstimateStatus.accepted => 'Accepted. Ready to invoice.',
      EstimateStatus.declined => 'The customer declined this estimate.',
      EstimateStatus.converted => 'Invoiced as ${invoice?.number ?? 'an invoice'}.',
    };

    return BlocListener<EstimateBloc, EstimateState>(
      listenWhen: (prev, next) => next.error != null && prev.error != next.error,
      listener: (context, state) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!))),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: Text(e.number),
          actions: [
            IconButton(
              tooltip: 'Share PDF',
              icon: const Icon(Icons.ios_share),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF export & sending come in a later build.')),
              ),
            ),
            PopupMenuButton<_Action>(
              tooltip: 'More',
              onSelected: (a) => _onAction(a, e),
              itemBuilder: (_) => [
                if (!e.isConverted)
                  const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
                const PopupMenuItem(value: _Action.duplicate, child: Text('Duplicate')),
                if (!e.isConverted && e.decision != null)
                  const PopupMenuItem(value: _Action.reset, child: Text('Mark as awaiting reply')),
                if (!e.isConverted && e.decision != EstimateDecision.declined)
                  const PopupMenuItem(value: _Action.declined, child: Text('Mark as declined')),
                if (!e.isConverted)
                  const PopupMenuItem(value: _Action.delete, child: Text('Delete')),
              ],
            ),
          ],
        ),
        bottomNavigationBar: canConvert
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => convertEstimateToInvoice(context, e),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Convert to invoice'),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
        body: CenteredListView(
          maxWidth: 820,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Row(
                children: [
                  StatusChip.estimate(status),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(statusText,
                        style: text.bodyMedium?.copyWith(
                            color: status == EstimateStatus.expired ? l.warning : l.muted)),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, PageRoutes.invoiceTemplate),
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    label: const Text('Design'),
                  ),
                ],
              ),
            ),
            if (awaiting)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Did the customer reply?', style: text.titleSmall),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Record their answer so you know which quotes to chase.',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: Space.md),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.sm,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _onAction(_Action.accepted, e),
                            icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                            label: const Text('Accepted'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _onAction(_Action.declined, e),
                            icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                            label: const Text('Declined'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (awaiting) const SizedBox(height: Space.md),
            InvoiceDocument(
              invoice: e.asDocument(),
              customer: customer,
              profile: settingState.profile,
              template: settingState.template,
              kind: DocumentKind.estimate,
            ),
            if (invoice != null) ...[
              const SectionHeader('Invoice'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: InvoiceTile(
                  invoice: invoice,
                  onTap: () => openInvoiceDetail(context, invoice.id),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
