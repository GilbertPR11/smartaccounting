import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/receipt/receipt_bloc.dart';
import '../../../bloc/vendor/vendor_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/empty_state.dart';
import '../../../components/money_text.dart';
import '../../../components/receipt_thumb.dart';
import '../../../components/section_header.dart';
import '../../../models/receipt_model.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../purchase_flows.dart';

/// Receipt inbox: "To review" on top, finished ones below.
class ReceiptListPage extends StatelessWidget {
  const ReceiptListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiptBloc>().state;
    final toReview = state.toReview;
    final done = state.receipts.where((r) => r.isDone).toList();
    final l = context.ledger;

    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => captureReceipt(context),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Add receipt'),
      ),
      body: state.receipts.isEmpty
          ? EmptyState(
              icon: Icons.document_scanner_outlined,
              title: 'No receipts yet',
              message: 'Snap a photo when you pay for something. Fill in the details now '
                  'or later; it waits here until you do.',
              actionLabel: 'Add receipt',
              onAction: () => captureReceipt(context),
            )
          : CenteredListView(
              maxWidth: 760,
              bottom: 96,
              children: [
                SectionHeader(
                  'To review',
                  subtitle: toReview.isEmpty
                      ? 'You\'re all caught up'
                      : 'Add the amount and category, then record them',
                ),
                if (toReview.isNotEmpty)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: divided(
                          [for (final r in toReview) _ReceiptRow(receipt: r)], l.hairline,
                          indent: 80),
                    ),
                  ),
                if (done.isNotEmpty) ...[
                  const SectionHeader('Done'),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: divided(
                          [for (final r in done) _ReceiptRow(receipt: r)], l.hairline,
                          indent: 80),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final vendorName = context.select<VendorBloc, String?>((b) => b.state.byId(r.vendorId)?.name);
    final title = vendorName ?? (r.merchant.isNotEmpty ? r.merchant : 'Receipt');
    final when = r.date ?? r.addedOn;

    return ListTile(
      leading: ReceiptThumb(r.imageBytes),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        r.isDone
            ? '${fmtDateShort(when)}   ${r.status.label}'
            : 'Added ${fmtDateShort(r.addedOn)}',
        style: r.isDone ? null : TextStyle(color: l.warning),
      ),
      trailing: r.amount == null
          ? Text('No amount', style: text.bodySmall)
          : MoneyText(r.amount!),
      onTap: () => Navigator.pushNamed(context, PageRoutes.receipt, arguments: r.id),
    );
  }
}
