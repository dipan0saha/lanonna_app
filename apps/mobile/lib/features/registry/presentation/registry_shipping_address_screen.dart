import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/iso_countries.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/widgets/app_country_dropdown_field.dart';
import '../../../core/widgets/app_labeled_text_form_field.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/models/registry_models.dart';
import '../data/registry_repository.dart';

class RegistryShippingAddressScreen extends StatefulWidget {
  const RegistryShippingAddressScreen({super.key});

  @override
  State<RegistryShippingAddressScreen> createState() =>
      _RegistryShippingAddressScreenState();
}

class _RegistryShippingAddressScreenState
    extends State<RegistryShippingAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _postal = TextEditingController();

  BabySummary? _baby;
  List<IsoCountry> _countries = const [];
  String? _countryCode;
  var _loading = true;
  var _saving = false;
  var _hadAddress = false;
  var _validateOnInteraction = false;

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _region.dispose();
    _postal.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  AutovalidateMode get _autovalidateMode => _validateOnInteraction
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final store = context.read<SelectedBabyStore>();
      final homeRepo = context.read<HomeRepository>();
      final regRepo = context.read<RegistryRepository>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        if (mounted) context.pop();
        return;
      }
      if (baby.role != 'owner') {
        if (mounted) {
          AppSnackBar.showAlert(
            context,
            'Only owners can edit the shipping address.',
          );
          context.pop();
        }
        return;
      }
      final countries = await IsoCountries.load();
      final address = await regRepo.getShippingAddress(baby.id);
      if (!mounted) return;
      _applyAddress(address);
      setState(() {
        _baby = baby;
        _countries = countries;
        _hadAddress = !address.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, 'Could not load shipping address: $e');
        context.pop();
      }
    }
  }

  void _applyAddress(RegistryShippingAddress address) {
    _line1.text = address.line1 ?? '';
    _line2.text = address.line2 ?? '';
    _city.text = address.city ?? '';
    _region.text = address.region ?? '';
    _postal.text = address.postalCode ?? '';
    _countryCode = address.countryCode;
  }

  Future<void> _save() async {
    final baby = _baby;
    if (baby == null) return;
    setState(() => _validateOnInteraction = true);
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    final patch = RegistryShippingAddress(
      line1: _line1.text,
      line2: _line2.text,
      city: _city.text,
      region: _region.text,
      postalCode: _postal.text,
      countryCode: _countryCode,
    ).toPatchJson();
    final ok = await runMutation(
      context,
      () => context.read<RegistryRepository>().updateShippingAddress(
        baby.id,
        patch,
      ),
    );
    if (mounted) setState(() => _saving = false);
    if (ok && mounted) context.pop(true);
  }

  Future<void> _clear() async {
    final baby = _baby;
    if (baby == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove shipping address?'),
        content: const Text(
          'Followers will no longer see where to send gifts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final ok = await runMutation(
      context,
      () => context.read<RegistryRepository>().updateShippingAddress(
        baby.id,
        RegistryShippingAddress.clearPatchJson(),
      ),
    );
    if (mounted) setState(() => _saving = false);
    if (ok && mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PrototypeSubpageScaffold(
      title: 'Shipping address',
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.horizontalPadding,
            0,
            AppMetrics.horizontalPadding,
            96,
          ),
          children: [
            Text(
              'Where should family send registry gifts?',
              style: context.textStyles.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppMetrics.formFieldSpacing),
            AppLabeledTextFormField(
              semanticsId: 'registry_shipping_line1',
              label: 'Street address',
              hint: '123 Main St',
              kind: AppTextInputKind.none,
              controller: _line1,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              validator: validateRegistryShippingLine1,
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextFormField(
              label: 'Apt, suite, etc. (optional)',
              hint: 'Apt 4B',
              kind: AppTextInputKind.none,
              controller: _line2,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextFormField(
              label: 'City',
              hint: 'Springfield',
              kind: AppTextInputKind.none,
              controller: _city,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              validator: validateRegistryShippingCity,
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextFormField(
              label: 'State / Province (optional)',
              hint: 'IL',
              kind: AppTextInputKind.none,
              controller: _region,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextFormField(
              label: 'Zip / Postal code',
              hint: '62704',
              kind: AppTextInputKind.none,
              controller: _postal,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              validator: validateRegistryShippingPostalCode,
              autovalidateMode: _autovalidateMode,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.fieldLabelGap),
              child: Text('Country', style: context.fieldLabelStyle),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.formFieldSpacing),
              child: AppCountryDropdownField(
                countries: _countries,
                value: _countryCode,
                enabled: !_saving,
                validator: validateCountryCode,
                autovalidateMode: _autovalidateMode,
                onChanged: (code) => setState(() => _countryCode = code),
              ),
            ),
            AppSemantics.button(
              'registry_shipping_save',
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save address'),
              ),
              label: 'Save address',
            ),
            if (_hadAddress) ...[
              const SizedBox(height: AppMetrics.formFieldSpacing - 4),
              OutlinedButton(
                onPressed: _saving ? null : _clear,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Remove address'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
