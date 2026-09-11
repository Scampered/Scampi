import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../theme/app_typography.dart';
import 'health_service.dart';

/// Human-readable label for a [HealthDataType], used only on this
/// screen — the type names themselves (ACTIVE_ENERGY_BURNED, etc.) are
/// accurate but not friendly to show directly to the user.
String _labelFor(HealthDataType type) {
  switch (type) {
    case HealthDataType.STEPS:
      return 'Steps';
    case HealthDataType.ACTIVE_ENERGY_BURNED:
      return 'Active calories';
    case HealthDataType.DISTANCE_DELTA:
      return 'Distance';
    case HealthDataType.WORKOUT:
      return 'Exercise sessions';
    case HealthDataType.SLEEP_SESSION:
      return 'Sleep (session)';
    case HealthDataType.SLEEP_ASLEEP:
      return 'Sleep (stages)';
    default:
      return type.name;
  }
}

class _TypeDiagnostic {
  const _TypeDiagnostic({required this.type, required this.granted, required this.hasData});
  final HealthDataType type;
  final bool granted;
  final bool hasData;
}

class _Diagnostics {
  const _Diagnostics({
    required this.installed,
    required this.types,
  });
  final bool installed;
  final List<_TypeDiagnostic> types;
}

/// A one-screen "why isn't my data showing up" checklist — whether
/// Health Connect is installed, whether Scampi holds each permission,
/// and whether Health Connect actually has any recent data of that type
/// at all. The last check is the one that matters most in practice: a
/// permission can be perfectly granted and still show nothing if the
/// watch's own health app (Samsung Health, etc.) hasn't been told to
/// forward that data type into Health Connect yet.
class HealthSetupScreen extends StatefulWidget {
  const HealthSetupScreen({super.key});

  @override
  State<HealthSetupScreen> createState() => _HealthSetupScreenState();
}

class _HealthSetupScreenState extends State<HealthSetupScreen> {
  Future<_Diagnostics>? _future;

  static const _relevantTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WORKOUT,
    HealthDataType.SLEEP_SESSION,
  ];

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  Future<_Diagnostics> _run() async {
    final installed = await HealthService.instance.isHealthConnectInstalled();
    final permissions = await HealthService.instance.permissionStatusByType();
    final types = <_TypeDiagnostic>[];
    for (final type in _relevantTypes) {
      final granted = permissions[type] ?? false;
      final hasData = granted ? await HealthService.instance.hasRecentData(type) : false;
      types.add(_TypeDiagnostic(type: type, granted: granted, hasData: hasData));
    }
    return _Diagnostics(installed: installed, types: types);
  }

  void _refresh() => setState(() => _future = _run());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connect Setup'),
        actions: [
          IconButton(
            tooltip: 'Re-check',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<_Diagnostics>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final diag = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(ScampiSpacing.md),
            children: [
              _StatusTile(
                ok: diag.installed,
                title: 'Health Connect installed',
                detail: diag.installed
                    ? 'Found on this device.'
                    : "Not found — install it from the Play Store, or from the "
                        "prompt Android shows when Scampi first asks for access.",
              ),
              const SizedBox(height: ScampiSpacing.md),
              Text('Per-type status', style: theme.textTheme.titleMedium),
              const SizedBox(height: ScampiSpacing.xs),
              for (final t in diag.types) ...[
                _StatusTile(
                  ok: t.granted && t.hasData,
                  title: _labelFor(t.type),
                  detail: !t.granted
                      ? "Scampi doesn't have permission to read this yet — toggle "
                          "the Health App Connector off and back on in Profile to "
                          "re-request it."
                      : t.hasData
                          ? 'Permission granted, and Health Connect has recent data.'
                          : t.type == HealthDataType.ACTIVE_ENERGY_BURNED ||
                                  t.type == HealthDataType.DISTANCE_DELTA
                              ? "Permission granted, but Health Connect has no "
                                  "standalone data for this in the last 30 days. "
                                  "Scampi also checks Exercise sessions as a "
                                  "fallback (some sources, Samsung Health "
                                  "included, only forward this as part of a "
                                  "recorded workout, not continuously through the "
                                  "day) — see Exercise sessions below."
                              : "Permission granted, but Health Connect has nothing "
                                  "for this in the last 30 days — the source app "
                                  "(Samsung Health, etc.) likely isn't forwarding "
                                  "it yet.",
                ),
                const SizedBox(height: ScampiSpacing.xs),
              ],
              const SizedBox(height: ScampiSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(ScampiSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Getting Samsung Health into Health Connect',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: ScampiSpacing.xs),
                      const Text(
                        '1. Open Samsung Health → Settings → Health Connect.\n'
                        '2. Turn on Steps, Active calories, Distance, Exercise, '
                        'and Sleep.\n'
                        "3. Give it a minute — a watch's data reaches Samsung "
                        "Health first, then Health Connect, so it isn't instant.\n"
                        "4. Health Connect doesn't back-fill: only data from after "
                        "you turn a type on will show up here, not older history.\n"
                        "5. If Active calories/Distance still show nothing, check "
                        "Exercise sessions below instead — some phones only send "
                        "those two as part of a recorded workout, not "
                        "continuously through an ordinary day.\n"
                        "6. Come back and tap the refresh icon above.",
                        style: TextStyle(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.ok, required this.title, required this.detail});

  final bool ok;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ScampiSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
            ),
            const SizedBox(width: ScampiSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
