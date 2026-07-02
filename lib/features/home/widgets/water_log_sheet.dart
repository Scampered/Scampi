import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/water_weight_log.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/data_refresh_signal.dart';
import 'water_log_provider.dart';

/// A sane upper bound for a single custom water entry — catches obvious
/// typos (e.g. an extra zero) without being restrictive for anyone
/// genuinely logging a big bottle at once.
const int _maxSingleEntryMl = 5000;

/// Bottom sheet opened by tapping the Water tile on Home: a custom-amount
/// entry field with validation, plus today's logged entries with
/// swipe-to-delete — so a mistaken quick-add can actually be undone
/// instead of only being fixable by drinking less water than the app
/// thinks you did.
class WaterLogSheet extends ConsumerStatefulWidget {
  const WaterLogSheet({super.key});

  @override
  ConsumerState<WaterLogSheet> createState() => _WaterLogSheetState();
}

class _WaterLogSheetState extends ConsumerState<WaterLogSheet> {
  final _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addCustomAmount() async {
    final text = _amountController.text.trim();
    final amount = int.tryParse(text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a positive number of ml');
      return;
    }
    if (amount > _maxSingleEntryMl) {
      setState(() => _error = "That's more than ${_maxSingleEntryMl}ml in one go — check the amount");
      return;
    }
    setState(() => _error = null);

    await ref.read(waterLogRepositoryProvider).logEntry(
          WaterLogEntry(loggedAt: DateTime.now(), amountMl: amount),
        );
    ref.read(dataRefreshSignalProvider.notifier).bump();
    _amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(todayWaterLogProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ScampiRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(
          ScampiSpacing.lg,
          ScampiSpacing.sm,
          ScampiSpacing.lg,
          ScampiSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: ScampiSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: ScampiRadius.pillBorder,
                  ),
                ),
              ),
              Text('Water', style: theme.textTheme.titleLarge),
              const SizedBox(height: ScampiSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        labelText: 'Custom amount',
                        suffixText: 'ml',
                        errorText: _error,
                        border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                      ),
                    ),
                  ),
                  const SizedBox(width: ScampiSpacing.sm),
                  FilledButton(
                    onPressed: _addCustomAmount,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: ScampiSpacing.md),
              Text("Today's entries", style: theme.textTheme.labelLarge),
              const SizedBox(height: ScampiSpacing.xs),
              entriesAsync.when(
                // Keeps the previously-fetched list on screen while a
                // refetch is in flight (e.g. right after a swipe-delete
                // bumps the refresh signal) instead of collapsing the
                // sheet down to a spinner and back — that collapse/
                // reopen was the "flickers for a split second" glitch.
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: ScampiSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, __) => Text('$err', style: theme.textTheme.bodySmall),
                data: (entries) => _EntryList(entries: entries),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryList extends ConsumerStatefulWidget {
  const _EntryList({required this.entries});

  final List<WaterLogEntry> entries;

  @override
  ConsumerState<_EntryList> createState() => _EntryListState();
}

class _EntryListState extends ConsumerState<_EntryList> {
  // Same optimistic-removal pattern as the food/fitness logs — filters a
  // just-swiped entry out immediately so the Dismissible never gets
  // rebuilt after it already dismissed itself.
  final Set<int> _removedIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries.where((e) => !_removedIds.contains(e.id)).toList();

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ScampiSpacing.md),
        child: Text('Nothing logged yet today.', style: theme.textTheme.bodySmall),
      );
    }

    return Column(
      children: [
        for (final entry in entries)
          Dismissible(
            key: ValueKey(entry.id ?? entry.hashCode),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: ScampiSpacing.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.85),
                borderRadius: ScampiRadius.mdBorder,
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: ScampiSpacing.md),
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            onDismissed: (_) => _delete(entry),
            child: Card(
              margin: const EdgeInsets.only(bottom: ScampiSpacing.xs),
              child: ListTile(
                leading: const Icon(Icons.water_drop_rounded),
                title: Text('${entry.amountMl} ml'),
                subtitle: Text(DateFormat('h:mm a').format(entry.loggedAt)),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _delete(WaterLogEntry entry) async {
    if (entry.id == null) return;
    setState(() => _removedIds.add(entry.id!));
    await ref.read(waterLogRepositoryProvider).deleteEntry(entry.id!);
    ref.read(dataRefreshSignalProvider.notifier).bump();
  }
}
