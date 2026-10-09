import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/estimate/estimate_bloc.dart';
import '../../../components/empty_state.dart';
import '../../../components/estimate_tile.dart';
import '../../../components/search_field.dart';
import '../../../config/layout.dart';
import '../../../models/estimate_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import 'estimate_detail_page.dart';
import 'estimate_flows.dart';

/// Estimates with search and status filters. Same shape as the invoice list:
/// list only on narrow screens, list + detail side by side on wide ones.
class EstimateListPage extends StatefulWidget {
  const EstimateListPage({super.key});

  @override
  State<EstimateListPage> createState() => _EstimateListPageState();
}

class _EstimateListPageState extends State<EstimateListPage> {
  EstimateStatus? _filter; // null = all
  String _query = '';
  int _searchEpoch = 0;
  String? _selectedId;

  static const _filters = [
    EstimateStatus.pending,
    EstimateStatus.accepted,
    EstimateStatus.expired,
    EstimateStatus.converted,
    EstimateStatus.declined,
  ];

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final all = context.watch<EstimateBloc>().state.estimates;
    final customers = context.watch<CustomerBloc>().state;
    final l = context.ledger;
    final q = _query.trim().toLowerCase();

    final shown = all.where((e) {
      if (_filter != null && e.statusOn(today) != _filter) return false;
      if (q.isEmpty) return true;
      final name = customers.byId(e.customerId)?.name.toLowerCase() ?? '';
      return e.number.toLowerCase().contains(q) ||
          name.contains(q) ||
          e.total.toStringAsFixed(2).contains(q);
    }).toList();

    int count(EstimateStatus s) => all.where((e) => e.statusOn(today) == s).length;

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= Breakpoints.twoPane;
      final selectionValid = _selectedId != null && shown.any((e) => e.id == _selectedId);
      final String? selected = (!wide || selectionValid)
          ? _selectedId
          : (shown.isEmpty ? null : shown.first.id);

      final controls = Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, 0),
        child: Column(
          children: [
            SearchField(
              key: ValueKey(_searchEpoch),
              hint: 'Search by customer, number or amount',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: Text('All  ${all.length}'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final s in _filters) ...[
                    const SizedBox(width: Space.sm),
                    ChoiceChip(
                      label: Text('${s.label}  ${count(s)}'),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
          ],
        ),
      );

      final Widget list;
      if (all.isEmpty) {
        list = EmptyState(
          icon: Icons.request_quote_outlined,
          title: 'No estimates yet',
          message: 'Send a quote first. When the customer agrees, turn it into an '
              'invoice in one tap.',
          actionLabel: 'New estimate',
          onAction: () => openEstimateForm(context),
        );
      } else if (shown.isEmpty) {
        list = EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matching estimates',
          message: q.isNotEmpty
              ? 'Nothing matches "$_query".'
              : 'No estimates are "${_filter?.label.toLowerCase()}" right now.',
          actionLabel: 'Show all estimates',
          onAction: () => setState(() {
            _filter = null;
            _query = '';
            _searchEpoch++;
          }),
          compact: true,
        );
      } else {
        list = ListView.separated(
          padding: EdgeInsets.only(bottom: wide ? Space.lg : 88),
          itemCount: shown.length,
          separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: l.hairline),
          itemBuilder: (context, i) {
            final e = shown[i];
            return EstimateTile(
              estimate: e,
              selected: wide && e.id == selected,
              onTap: () {
                if (wide) {
                  setState(() => _selectedId = e.id);
                } else {
                  openEstimateDetail(context, e.id);
                }
              },
            );
          },
        );
      }

      if (!wide) {
        final pad = sidePadding(c.maxWidth, maxWidth: 760, min: 0);
        return Scaffold(
          appBar: AppBar(title: const Text('Estimates')),
          floatingActionButton: FloatingActionButton(
            tooltip: 'New estimate',
            onPressed: () => openEstimateForm(context),
            child: const Icon(Icons.add),
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Column(children: [controls, Expanded(child: list)]),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Estimates'),
          actions: [
            Center(
              child: FilledButton.icon(
                onPressed: () => openEstimateForm(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New estimate'),
              ),
            ),
            const SizedBox(width: Space.lg),
          ],
        ),
        body: Row(
          children: [
            Container(
              width: c.maxWidth >= 1300 ? 440 : 380,
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                  children: [controls, Divider(color: l.hairline), Expanded(child: list)]),
            ),
            VerticalDivider(width: 1, color: l.hairline),
            Expanded(
              child: selected == null
                  ? const EmptyState(
                      icon: Icons.request_quote_outlined,
                      title: 'Select an estimate',
                      message: 'It will show here, ready to send or invoice.',
                    )
                  : EstimateDetailPage(
                      key: ValueKey(selected), estimateId: selected, embedded: true),
            ),
          ],
        ),
      );
    });
  }
}
