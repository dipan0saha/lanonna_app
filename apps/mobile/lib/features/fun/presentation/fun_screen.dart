import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_semantics.dart';
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

class _FunScreenState extends State<FunScreen> with BabyContextReload {
  var _segment = 0;
  BabySummary? _baby;
  var _loading = true;

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
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final baby = await homeRepo.resolveSelectedBaby(store);
    setState(() {
      _baby = baby;
      _loading = false;
    });
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
              child: Text('Family Fun', style: context.textStyles.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _baby == null
                      ? const Center(child: Text('No baby profile yet.'))
                      : _segment == 0
                          ? NamesTab(baby: _baby!)
                          : PredictionsTab(baby: _baby!),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
