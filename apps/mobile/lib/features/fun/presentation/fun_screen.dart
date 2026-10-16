import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/presentation/tab_load_kind.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/baby_context_reload.dart';
import '../../shell/presentation/shell_tab_layout.dart';
import '../../../core/domain/baby_summary.dart';
import '../../onboarding/presentation/widgets/onboarding_fields.dart';
import 'names_tab.dart';
import 'predictions_tab.dart';

class FunScreen extends StatefulWidget {
  const FunScreen({super.key});

  @override
  State<FunScreen> createState() => _FunScreenState();
}

class _FunScreenState extends State<FunScreen>
    with BabyContextReload, TabLoadGenerationCache {
  var _segment = 0;
  BabySummary? _baby;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBaby();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registerBabyContextListeners();
  }

  @override
  void dispose() {
    disposeBabyContextListeners();
    super.dispose();
  }

  @override
  void onBabyContextReload() => _loadBaby();

  Future<void> _loadBaby() async {
    final store = context.read<SelectedBabyStore>();
    if (shouldShowTabLoadSpinner(store, hasDisplayedPayload: _baby != null)) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final homeRepo = context.read<HomeRepository>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _loading = false;
        _error = null;
      });
      rememberTabLoadGeneration(store, baby);
    } catch (e) {
      if (!mounted) return;
      final hadBaby = _baby != null;
      reportTabLoadFailure(
        context,
        e,
        hasPayload: hadBaby,
        onBlockingError: (message) {
          setState(() {
            _loading = false;
            _error = message;
          });
        },
      );
      if (hadBaby && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _funBody() {
    final kind = resolveTabLoadKind(
      loading: _loading,
      hasError: _error != null,
      hasPayload: _baby != null,
    );
    switch (kind) {
      case TabLoadKind.loading:
        return const Center(child: CircularProgressIndicator());
      case TabLoadKind.error:
        return AsyncTabBody(
          loading: false,
          error: _error,
          onRetry: _loadBaby,
          child: const SizedBox.shrink(),
        );
      case TabLoadKind.empty:
        return const Center(child: Text('No baby profile yet.'));
      case TabLoadKind.content:
        // After birth both tabs stay visible but read-only; the API also
        // rejects prediction writes with predictions_closed.
        final baby = _baby!;
        return _segment == 0
            ? NamesTab(baby: baby, readOnly: baby.lifecycleStatus == 'born')
            : PredictionsTab(baby: baby);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSemantics.container(
      'fun_hub',
      Scaffold(
        key: const Key('gamification_screen'),
        backgroundColor: AppColors.background,
        body: ShellTabLayout(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppMetrics.horizontalPadding,
                  0,
                  AppMetrics.horizontalPadding,
                  8,
                ),
                child: Text(
                  'Family Fun',
                  style: context.textStyles.headlineSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: OnboardingSegmentedControl(
                  style: OnboardingSegmentedControlStyle.mini,
                  leftLabel: 'Names',
                  rightLabel: 'Predictions',
                  isLeftSelected: _segment == 0,
                  onLeftTap: () => setState(() => _segment = 0),
                  onRightTap: () => setState(() => _segment = 1),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _funBody()),
            ],
          ),
        ),
      ),
    );
  }
}
