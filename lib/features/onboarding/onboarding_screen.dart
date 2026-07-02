import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/calorie_calculator.dart';

/// First-run profile setup, and also reused for editing an existing
/// profile (pass [existingProfile] to pre-fill and skip the splash).
///
/// Presented as a one-question-at-a-time wizard — each step is its own
/// screen with a progress bar, Back/Next controls, and inline validation
/// before advancing. Steps are computed dynamically (see [_steps]) since
/// whether the target-date step appears depends on earlier answers.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.existingProfile,
  });

  final VoidCallback onComplete;
  final UserProfile? existingProfile;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step {
  splash,
  name,
  units,
  sex,
  age,
  height,
  weight,
  goalWeight,
  targetDate,
  activity,
  goalMode,
  review,
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _stepIndex = 0;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalWeightController = TextEditingController();

  BiologicalSex _sex = BiologicalSex.male;
  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  GoalMode _goalMode = GoalMode.maintain;
  UnitsSystem _unitsSystem = UnitsSystem.metric;
  bool _goalWeightSkipped = false;

  /// Which preset duration chip (if any) was last tapped on the target-
  /// date step, so the chip row can show which one is active — comparing
  /// dates directly doesn't work since `DateTime.now()` drifts between
  /// the tap and the next rebuild. Cleared when a custom date is picked
  /// or the date is removed, since neither corresponds to a preset.
  int? _selectedPresetDays;
  DateTime? _targetDate;

  String? _stepError;
  bool _saving = false;

  bool get _isEditing => widget.existingProfile != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProfile;
    if (existing != null) {
      _nameController.text = existing.name;
      _sex = existing.sex;
      _activityLevel = existing.activityLevel;
      _goalMode = existing.goalMode;
      _unitsSystem = existing.unitsSystem;
      _targetDate = existing.targetDate;

      _ageController.text = existing.age.toString();
      final goalKg = existing.goalWeightKg;
      _goalWeightSkipped = goalKg == null;

      if (_unitsSystem == UnitsSystem.imperial) {
        _heightController.text = (existing.heightCm / 2.54).toStringAsFixed(1);
        _weightController.text = (existing.weightKg / 0.453592).toStringAsFixed(1);
        if (goalKg != null) {
          _goalWeightController.text = (goalKg / 0.453592).toStringAsFixed(1);
        }
      } else {
        _heightController.text = existing.heightCm.toStringAsFixed(1);
        _weightController.text = existing.weightKg.toStringAsFixed(1);
        if (goalKg != null) {
          _goalWeightController.text = goalKg.toStringAsFixed(1);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalWeightController.dispose();
    super.dispose();
  }

  double? get _weightKgValue {
    final raw = double.tryParse(_weightController.text.trim());
    if (raw == null) return null;
    return _unitsSystem == UnitsSystem.imperial ? raw * 0.453592 : raw;
  }

  double? get _goalWeightKgValue {
    if (_goalWeightSkipped) return null;
    final raw = double.tryParse(_goalWeightController.text.trim());
    if (raw == null) return null;
    return _unitsSystem == UnitsSystem.imperial ? raw * 0.453592 : raw;
  }

  double? get _heightCmValue {
    final raw = double.tryParse(_heightController.text.trim());
    if (raw == null) return null;
    return _unitsSystem == UnitsSystem.imperial ? raw * 2.54 : raw;
  }

  int? get _ageValue => int.tryParse(_ageController.text.trim());

  /// The resulting absolute daily calorie target for a given offset from
  /// maintenance, computed the same way `CalorieCalculator.calculate()`
  /// (and therefore Home) does — BMR × activity multiplier + offset.
  /// Shown alongside the "±X kcal/day" pace text on the goal-mode step so
  /// the number there matches what the user will actually see on Home,
  /// instead of just the offset which doesn't visibly reflect activity
  /// level on its own.
  double? _dailyCaloriesForOffset(int offsetKcal) {
    final weightKg = _weightKgValue;
    final heightCm = _heightCmValue;
    final age = _ageValue;
    if (weightKg == null || heightCm == null || age == null) return null;
    final bmr = CalorieCalculator.calculateBmr(
      sex: _sex,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
    );
    final tdee = CalorieCalculator.calculateTdee(bmr: bmr, activityLevel: _activityLevel);
    return tdee + offsetKcal;
  }

  bool get _hasWeightGoalDirection {
    final weightKg = _weightKgValue;
    final goalKg = _goalWeightKgValue;
    if (weightKg == null || goalKg == null) return false;
    return (goalKg - weightKg).abs() > 0.5;
  }

  /// Steps are computed fresh each time rather than stored, since
  /// whether the target-date step is included depends on the goal
  /// weight the user entered — which can change if they navigate back.
  List<_Step> get _steps {
    return [
      if (!_isEditing) _Step.splash,
      _Step.name,
      _Step.units,
      _Step.sex,
      _Step.age,
      _Step.height,
      _Step.weight,
      _Step.goalWeight,
      if (_hasWeightGoalDirection) _Step.targetDate,
      _Step.activity,
      _Step.goalMode,
      _Step.review,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final step = steps[_stepIndex];
    final isSplash = step == _Step.splash;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!isSplash)
              _ProgressHeader(
                progress: _stepIndex / (steps.length - 2),
                onBack: _stepIndex > (_isEditing ? 0 : 1) ? _goBack : null,
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: Padding(
                  key: ValueKey(step),
                  padding: const EdgeInsets.all(ScampiSpacing.lg),
                  child: _buildStep(step),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(_Step step) {
    switch (step) {
      case _Step.splash:
        return _SplashStep(onGetStarted: _goNext);
      case _Step.name:
        return _StepScaffold(
          title: "What's your name?",
          subtitle: "We'll use this to personalize your Home screen.",
          error: _stepError,
          onNext: _goNext,
          onSkip: () {
            _nameController.clear();
            _goNext();
          },
          child: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (_) => _goNext(),
          ),
        );
      case _Step.units:
        return _StepScaffold(
          title: 'Which units do you use?',
          error: _stepError,
          onNext: _goNext,
          child: _SegmentedField<UnitsSystem>(
            value: _unitsSystem,
            options: const {
              UnitsSystem.metric: 'Metric (kg, cm)',
              UnitsSystem.imperial: 'Imperial (lb, in)',
            },
            onChanged: (v) => setState(() => _unitsSystem = v),
          ),
        );
      case _Step.sex:
        return _StepScaffold(
          title: 'Biological sex',
          subtitle:
              'This is only used for the BMR calorie calculation, which '
              'uses different formulas for each.',
          error: _stepError,
          onNext: _goNext,
          child: _SegmentedField<BiologicalSex>(
            value: _sex,
            options: const {
              BiologicalSex.male: 'Male',
              BiologicalSex.female: 'Female',
            },
            onChanged: (v) => setState(() => _sex = v),
          ),
        );
      case _Step.age:
        return _StepScaffold(
          title: 'How old are you?',
          error: _stepError,
          onNext: _goNext,
          child: TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Age'),
            onSubmitted: (_) => _goNext(),
          ),
        );
      case _Step.height:
        return _StepScaffold(
          title: 'How tall are you?',
          error: _stepError,
          onNext: _goNext,
          child: TextField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: _unitsSystem == UnitsSystem.metric
                  ? 'Height (cm)'
                  : 'Height (inches)',
            ),
            onSubmitted: (_) => _goNext(),
          ),
        );
      case _Step.weight:
        return _StepScaffold(
          title: "What's your current weight?",
          error: _stepError,
          onNext: _goNext,
          child: TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: _unitsSystem == UnitsSystem.metric
                  ? 'Weight (kg)'
                  : 'Weight (lb)',
            ),
            onSubmitted: (_) => _goNext(),
          ),
        );
      case _Step.goalWeight:
        return _StepScaffold(
          title: 'Do you have a goal weight?',
          subtitle: "Totally optional — you can skip this and we'll just "
              'help you maintain.',
          error: _stepError,
          onNext: _goNext,
          onSkip: () {
            setState(() {
              _goalWeightSkipped = true;
              _targetDate = null;
              _stepError = null;
            });
            _goNext();
          },
          child: TextField(
            controller: _goalWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: _unitsSystem == UnitsSystem.metric
                  ? 'Goal Weight (kg)'
                  : 'Goal Weight (lb)',
            ),
            onChanged: (_) => setState(() => _goalWeightSkipped = false),
            onSubmitted: (_) => _goNext(),
          ),
        );
      case _Step.targetDate:
        return _buildTargetDateStep(context);
      case _Step.activity:
        return _StepScaffold(
          title: 'How active are you?',
          error: _stepError,
          onNext: _goNext,
          scrollable: true,
          child: Column(
            children: ActivityLevel.values.map((level) {
              return _SelectableCard(
                title: level.label,
                subtitle: level.description,
                selected: _activityLevel == level,
                onTap: () => setState(() => _activityLevel = level),
              );
            }).toList(),
          ),
        );
      case _Step.goalMode:
        return _buildGoalModeStep(context);
      case _Step.review:
        return _ReviewStep(
          isEditing: _isEditing,
          saving: _saving,
          name: _nameController.text.trim(),
          age: _ageController.text.trim(),
          unitsSystem: _unitsSystem,
          heightText: _heightController.text.trim(),
          weightText: _weightController.text.trim(),
          goalWeightText:
              _goalWeightSkipped ? null : _goalWeightController.text.trim(),
          targetDate: _targetDate,
          activityLevel: _activityLevel,
          goalMode: _goalMode,
          onConfirm: _save,
        );
    }
  }

  Widget _buildTargetDateStep(BuildContext context) {
    final theme = Theme.of(context);
    final weightKg = _weightKgValue;
    final goalKg = _goalWeightKgValue;
    String? paceSummary;
    bool paceTooSoon = false;

    if (_targetDate != null && weightKg != null && goalKg != null) {
      final offset = CalorieCalculator.requiredDailyOffsetForTarget(
        weightKg: weightKg,
        goalWeightKg: goalKg,
        targetDate: _targetDate!,
      );
      if (offset == null) {
        paceTooSoon = true;
      } else {
        paceSummary = _paceDescription(offset);
      }
    }

    return _StepScaffold(
      title: 'Do you have a target date?',
      subtitle: "Optional — tell us when you'd like to hit your goal "
          "weight and we'll pace your calories to match.",
      error: _stepError,
      onNext: _goNext,
      onSkip: () {
        setState(() {
          _targetDate = null;
          _stepError = null;
        });
        _goNext();
      },
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DurationChip(
                label: '4 weeks',
                selected: _selectedPresetDays == 28,
                onTap: () => setState(() {
                  _targetDate = DateTime.now().add(const Duration(days: 28));
                  _selectedPresetDays = 28;
                }),
              ),
              _DurationChip(
                label: '8 weeks',
                selected: _selectedPresetDays == 56,
                onTap: () => setState(() {
                  _targetDate = DateTime.now().add(const Duration(days: 56));
                  _selectedPresetDays = 56;
                }),
              ),
              _DurationChip(
                label: '12 weeks',
                selected: _selectedPresetDays == 84,
                onTap: () => setState(() {
                  _targetDate = DateTime.now().add(const Duration(days: 84));
                  _selectedPresetDays = 84;
                }),
              ),
              _DurationChip(
                label: '6 months',
                selected: _selectedPresetDays == 182,
                onTap: () => setState(() {
                  _targetDate = DateTime.now().add(const Duration(days: 182));
                  _selectedPresetDays = 182;
                }),
              ),
            ],
          ),
          const SizedBox(height: ScampiSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: const Text('Choose a specific date'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 60)),
                firstDate: DateTime.now().add(const Duration(days: 3)),
                lastDate: DateTime.now().add(const Duration(days: 1095)),
              );
              if (picked != null) {
                setState(() {
                  _targetDate = picked;
                  _selectedPresetDays = null;
                });
              }
            },
          ),
          if (_targetDate != null) ...[
            const SizedBox(height: ScampiSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ScampiSpacing.md),
              decoration: BoxDecoration(
                color: scampiSelectionColor(context).withValues(alpha: 0.10),
                borderRadius: ScampiRadius.mdBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Target: ${_formatDate(_targetDate!)}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove target date',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() {
                          _targetDate = null;
                          _selectedPresetDays = null;
                        }),
                      ),
                    ],
                  ),
                  if (paceSummary != null) ...[
                    const SizedBox(height: 6),
                    Text(paceSummary, style: theme.textTheme.bodySmall),
                  ],
                  if (paceTooSoon) ...[
                    const SizedBox(height: 6),
                    Text(
                      "That date's very close — pick a later one for a "
                      'realistic, healthy pace.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalModeStep(BuildContext context) {
    final weightKg = _weightKgValue ?? 70;
    final goalKg = _goalWeightKgValue;
    final allowed = allowedGoalModes(weightKg: weightKg, goalWeightKg: goalKg);

    int? dateOffset;
    if (_targetDate != null && goalKg != null) {
      dateOffset = CalorieCalculator.requiredDailyOffsetForTarget(
        weightKg: weightKg,
        goalWeightKg: goalKg,
        targetDate: _targetDate!,
      );
    }

    final validSelections = <GoalMode>{
      ...allowed,
      if (dateOffset != null) GoalMode.custom,
    };
    if (!validSelections.contains(_goalMode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _goalMode = allowed.first);
      });
    }

    return _StepScaffold(
      title: "What's your goal?",
      subtitle: goalKg != null
          ? "Based on your current and goal weight, here's what makes "
              'sense:'
          : "You skipped a goal weight, so here's the full range of "
              'options:',
      error: _stepError,
      onNext: _goNext,
      scrollable: true,
      child: Column(
        children: [
          if (dateOffset != null)
            _SelectableCard(
              title: 'Custom pace — hit your goal by ${_formatDate(_targetDate!)}',
              subtitle: _paceDescription(dateOffset),
              selected: _goalMode == GoalMode.custom,
              onTap: () => setState(() => _goalMode = GoalMode.custom),
            ),
          ...allowed.map((mode) {
            final rateText = mode == GoalMode.maintain
                ? null
                : _formatRate(
                    CalorieCalculator.weeklyRateKgForDailyOffset(mode.defaultDailyOffset),
                    isGain: mode.defaultDailyOffset > 0,
                  );
            final calories = _dailyCaloriesForOffset(mode.defaultDailyOffset);
            final subtitle = [
              if (rateText != null) rateText,
              if (calories != null) '≈${calories.round()} kcal/day',
            ].join(' · ');
            return _SelectableCard(
              title: mode.label,
              subtitle: subtitle.isEmpty ? null : subtitle,
              selected: _goalMode == mode,
              onTap: () => setState(() => _goalMode = mode),
            );
          }),
        ],
      ),
    );
  }

  String _paceDescription(int dailyOffsetKcal) {
    final rate = CalorieCalculator.weeklyRateKgForDailyOffset(dailyOffsetKcal);
    final isGain = dailyOffsetKcal > 0;
    final rateText = _formatRate(rate, isGain: isGain);
    final calories = _dailyCaloriesForOffset(dailyOffsetKcal);
    final caloriesText = calories != null ? ' · ≈${calories.round()} kcal/day' : '';
    return '$rateText (≈${dailyOffsetKcal.abs()} kcal/day ${isGain ? 'surplus' : 'deficit'})$caloriesText';
  }

  String _formatRate(double kgPerWeek, {required bool isGain}) {
    final verb = isGain ? 'gain' : 'lose';
    if (_unitsSystem == UnitsSystem.imperial) {
      final lbPerWeek = kgPerWeek * 2.20462;
      return '≈${lbPerWeek.toStringAsFixed(1)} lb/week $verb '
          '(≈${(lbPerWeek * 4.345).toStringAsFixed(1)} lb/month)';
    }
    return '≈${kgPerWeek.toStringAsFixed(2)} kg/week $verb '
        '(≈${(kgPerWeek * 4.345).toStringAsFixed(1)} kg/month)';
  }

  String _formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  void _goNext() {
    final steps = _steps;
    final step = steps[_stepIndex];
    final error = _validateStep(step);
    if (error != null) {
      setState(() => _stepError = error);
      return;
    }
    setState(() {
      _stepError = null;
      if (_stepIndex < steps.length - 1) _stepIndex++;
    });
  }

  void _goBack() {
    setState(() {
      _stepError = null;
      if (_stepIndex > 0) _stepIndex--;
    });
  }

  String? _validateStep(_Step step) {
    switch (step) {
      case _Step.splash:
      case _Step.name:
      case _Step.units:
      case _Step.sex:
      case _Step.targetDate:
      case _Step.activity:
      case _Step.goalMode:
      case _Step.review:
        return null;
      case _Step.age:
        final n = int.tryParse(_ageController.text.trim());
        if (n == null) return 'Enter your age';
        if (n < 13 || n > 100) return 'Enter an age between 13 and 100';
        return null;
      case _Step.height:
        final n = double.tryParse(_heightController.text.trim());
        if (n == null) return 'Enter your height';
        final min = _unitsSystem == UnitsSystem.metric ? 50 : 20;
        final max = _unitsSystem == UnitsSystem.metric ? 280 : 110;
        if (n < min || n > max) return 'Enter a value between $min and $max';
        return null;
      case _Step.weight:
        final n = double.tryParse(_weightController.text.trim());
        if (n == null) return 'Enter your weight';
        final min = _unitsSystem == UnitsSystem.metric ? 20 : 44;
        final max = _unitsSystem == UnitsSystem.metric ? 400 : 880;
        if (n < min || n > max) return 'Enter a value between $min and $max';
        return null;
      case _Step.goalWeight:
        if (_goalWeightSkipped) return null;
        final text = _goalWeightController.text.trim();
        if (text.isEmpty) return null; // treat empty as skipped, not invalid
        final n = double.tryParse(text);
        if (n == null) return 'Enter a number, or tap Skip';
        final min = _unitsSystem == UnitsSystem.metric ? 20 : 44;
        final max = _unitsSystem == UnitsSystem.metric ? 400 : 880;
        if (n < min || n > max) return 'Enter a value between $min and $max';
        return null;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final age = int.parse(_ageController.text.trim());
    var heightCm = double.parse(_heightController.text.trim());
    var weightKg = double.parse(_weightController.text.trim());
    double? goalWeightKg = _goalWeightKgValue;

    if (_unitsSystem == UnitsSystem.imperial) {
      heightCm = heightCm * 2.54;
      weightKg = weightKg * 0.453592;
      // goalWeightKg already converted by the _goalWeightKgValue getter.
    }

    var customOffset = 0;
    if (_goalMode == GoalMode.custom &&
        goalWeightKg != null &&
        _targetDate != null) {
      customOffset = CalorieCalculator.requiredDailyOffsetForTarget(
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            targetDate: _targetDate!,
          ) ??
          0;
    }

    final profile = UserProfile(
      name: _nameController.text.trim(),
      age: age,
      sex: _sex,
      heightCm: heightCm,
      weightKg: weightKg,
      goalWeightKg: goalWeightKg,
      targetDate: _targetDate,
      activityLevel: _activityLevel,
      goalMode: _goalMode,
      customDailyOffset: customOffset,
      unitsSystem: _unitsSystem,
    );

    final repo = ref.read(userProfileRepositoryProvider);
    await repo.saveProfile(profile);
    ref.read(dataRefreshSignalProvider.notifier).bump();

    if (mounted) {
      widget.onComplete();
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.progress, required this.onBack});

  final double progress;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: onBack != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: onBack,
                  )
                : null,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress.clamp(0, 1)),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(scampiSelectionColor(context)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashStep extends StatelessWidget {
  const _SplashStep({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Image.asset(
          'assets/images/scampi_logo.png',
          width: 200,
          height: 200,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.set_meal_rounded,
            size: 120,
            color: ScampiColors.mint,
          ),
        ),
        const SizedBox(height: ScampiSpacing.md),
        Text(
          'Scampi',
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 72,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ScampiSpacing.sm),
        Text(
          'Offline calorie, nutrition, and fitness tracking —\n'
          'no accounts, no cloud, just you.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onGetStarted,
            child: const Text('Get Started'),
          ),
        ),
        const SizedBox(height: ScampiSpacing.md),
      ],
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    this.subtitle,
    required this.child,
    required this.onNext,
    this.onSkip,
    this.error,
    this.scrollable = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final String? error;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: ScampiSpacing.xs),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: ScampiSpacing.lg),
        child,
        if (error != null) ...[
          const SizedBox(height: ScampiSpacing.sm),
          Text(
            error!,
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );

    return Column(
      children: [
        Expanded(
          child: scrollable
              ? SingleChildScrollView(child: content)
              : Align(alignment: Alignment.topLeft, child: content),
        ),
        Row(
          children: [
            if (onSkip != null)
              TextButton(onPressed: onSkip, child: const Text('Skip')),
            const Spacer(),
            FilledButton(onPressed: onNext, child: const Text('Next')),
          ],
        ),
      ],
    );
  }
}

class _SegmentedField<T> extends StatelessWidget {
  const _SegmentedField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectionColor = scampiSelectionColor(context);
    return SegmentedButton<T>(
      segments: options.entries
          .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
          .toList(),
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: selectionColor.withValues(alpha: 0.16),
        selectedForegroundColor: selectionColor,
        side: BorderSide(color: selectionColor.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectionColor = scampiSelectionColor(context);
    return ActionChip(
      avatar: selected ? Icon(Icons.check_rounded, size: 16, color: selectionColor) : null,
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selectionColor.withValues(alpha: selected ? 0.22 : 0.10),
      side: BorderSide(color: selectionColor.withValues(alpha: selected ? 1 : 0.3), width: selected ? 1.5 : 1),
      labelStyle: TextStyle(
        color: selectionColor,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionColor = scampiSelectionColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: ScampiSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ScampiColors.mint.withValues(alpha: 0.16),
                    selectionColor.withValues(alpha: 0.16),
                  ],
                )
              : null,
          color: selected
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: ScampiRadius.mdBorder,
          border: Border.all(
            color: selected ? selectionColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: ScampiRadius.mdBorder,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ScampiSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: selectionColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.isEditing,
    required this.saving,
    required this.name,
    required this.age,
    required this.unitsSystem,
    required this.heightText,
    required this.weightText,
    required this.goalWeightText,
    required this.targetDate,
    required this.activityLevel,
    required this.goalMode,
    required this.onConfirm,
  });

  final bool isEditing;
  final bool saving;
  final String name;
  final String age;
  final UnitsSystem unitsSystem;
  final String heightText;
  final String weightText;
  final String? goalWeightText;
  final DateTime? targetDate;
  final ActivityLevel activityLevel;
  final GoalMode goalMode;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heightUnit = unitsSystem == UnitsSystem.metric ? 'cm' : 'in';
    final weightUnit = unitsSystem == UnitsSystem.metric ? 'kg' : 'lb';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(value, style: theme.textTheme.titleSmall),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Looks good?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: ScampiSpacing.sm),
        Text(
          "We'll calculate your calorie and macro targets from this — "
          'you can change any of it later from your Profile.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: ScampiSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(ScampiSpacing.md),
                child: Column(
                  children: [
                    if (name.isNotEmpty) row('Name', name),
                    row('Age', age),
                    row('Height', '$heightText $heightUnit'),
                    row('Weight', '$weightText $weightUnit'),
                    row(
                      'Goal Weight',
                      goalWeightText != null
                          ? '$goalWeightText $weightUnit'
                          : 'Not set',
                    ),
                    if (targetDate != null)
                      row('Target Date', DateFormat('MMM d, yyyy').format(targetDate!)),
                    row('Activity Level', activityLevel.label),
                    row('Goal', goalMode.label),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: saving ? null : onConfirm,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? 'Save Changes' : 'Save and Continue'),
          ),
        ),
      ],
    );
  }
}
