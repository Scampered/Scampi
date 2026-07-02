import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_typography.dart';
import 'update_provider.dart';
import 'update_service.dart';

enum _Status { checking, upToDate, updateAvailable, error, downloading, downloadError }

/// "Scampi Update Available" screen: checks version.json on open, then
/// shows either "you're up to date" or the current/latest version +
/// release notes with Update Now / Later. Also reachable manually from
/// Profile → Updates → Check for Updates.
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  _Status _status = _Status.checking;
  UpdateCheckResult? _result;
  String? _errorMessage;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _status = _Status.checking);
    try {
      final result = await ref.read(updateServiceProvider).checkForUpdate();
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = result.updateAvailable ? _Status.updateAvailable : _Status.upToDate;
      });
    } on UpdateCheckException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _status = _Status.error;
      });
    }
  }

  Future<void> _updateNow() async {
    final result = _result;
    if (result == null) return;
    setState(() {
      _status = _Status.downloading;
      _downloadProgress = 0;
    });
    try {
      await ref.read(updateServiceProvider).downloadAndInstall(
            result.remote,
            onProgress: (p) {
              if (!mounted) return;
              setState(() => _downloadProgress = p);
            },
          );
      // OpenFilex has handed off to the system installer at this point —
      // nothing more for this screen to do.
    } on UpdateDownloadException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _status = _Status.downloadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check for Updates')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ScampiSpacing.lg),
          child: switch (_status) {
            _Status.checking => const _CenteredMessage(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: ScampiSpacing.md),
                    Text('Checking for updates…'),
                  ],
                ),
              ),
            _Status.upToDate => _UpToDateView(
                currentVersion: _result?.currentVersion ?? '',
                onRecheck: _check,
              ),
            _Status.error => _ErrorView(message: _errorMessage ?? 'Something went wrong.', onRetry: _check),
            _Status.updateAvailable => _UpdateAvailableView(
                result: _result!,
                onUpdateNow: _updateNow,
                onLater: () => Navigator.of(context).pop(),
              ),
            _Status.downloading => _DownloadingView(progress: _downloadProgress),
            _Status.downloadError => _ErrorView(
                message: _errorMessage ?? 'Download failed.',
                onRetry: _updateNow,
              ),
          },
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}

class _UpToDateView extends StatelessWidget {
  const _UpToDateView({required this.currentVersion, required this.onRecheck});

  final String currentVersion;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 56),
          const SizedBox(height: ScampiSpacing.md),
          Text('You are using the latest version.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: ScampiSpacing.xs),
          Text('Version $currentVersion', style: theme.textTheme.bodySmall),
          const SizedBox(height: ScampiSpacing.lg),
          OutlinedButton(onPressed: onRecheck, child: const Text('Check Again')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 56),
          const SizedBox(height: ScampiSpacing.md),
          Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: ScampiSpacing.lg),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indeterminate = progress < 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: indeterminate ? null : progress.clamp(0.0, 1.0),
              strokeWidth: 5,
            ),
          ),
          const SizedBox(height: ScampiSpacing.md),
          Text(
            indeterminate ? 'Downloading update…' : 'Downloading update… ${(progress * 100).round()}%',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _UpdateAvailableView extends StatelessWidget {
  const _UpdateAvailableView({
    required this.result,
    required this.onUpdateNow,
    required this.onLater,
  });

  final UpdateCheckResult result;
  final VoidCallback onUpdateNow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_rounded, color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: ScampiSpacing.sm),
              Expanded(
                child: Text('Scampi Update Available', style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: ScampiSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ScampiSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: ScampiRadius.mdBorder,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _VersionStat(label: 'Current Version', value: result.currentVersion),
                Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.outline),
                _VersionStat(label: 'Latest Version', value: result.remote.latestVersion),
              ],
            ),
          ),
          const SizedBox(height: ScampiSpacing.lg),
          Text("What's New", style: theme.textTheme.labelLarge),
          const SizedBox(height: ScampiSpacing.xs),
          if (result.remote.releaseNotes.isEmpty)
            Text('No release notes provided.', style: theme.textTheme.bodySmall)
          else
            for (final note in result.remote.releaseNotes)
              Padding(
                padding: const EdgeInsets.only(bottom: ScampiSpacing.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: theme.textTheme.bodyMedium),
                    Expanded(child: Text(note, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          const SizedBox(height: ScampiSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onLater, child: const Text('Later')),
              ),
              const SizedBox(width: ScampiSpacing.sm),
              Expanded(
                child: FilledButton(onPressed: onUpdateNow, child: const Text('Update Now')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionStat extends StatelessWidget {
  const _VersionStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}
