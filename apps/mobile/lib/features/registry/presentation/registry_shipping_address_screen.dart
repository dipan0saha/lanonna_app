import 'package:flutter/material.dart';
import '../../../core/api/api_error_message.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/iso_countries.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
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
import '../domain/registry_shipping_input.dart';
import '../../../core/theme/app_button_styles.dart';
import '../../../l10n/app_localizations.dart';

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
            AppLocalizations.of(context)!.registryOnlyOwnersCanEditThe,
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
        AppSnackBar.showAlert(context, AppLocalizations.of(context)!.registryCouldNotLoadShippingAddress(apiErrorMessage(AppLocalizations.of(context)!, e)));
        context.pop();
      }
    }
  }

  void _applyAddress(RegistryShippingAddress address) {
    _line1.text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      address.line1 ?? '',
    );
    _line2.text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      address.line2 ?? '',
    );
    _city.text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      address.city ?? '',
    );
    _region.text = formatRegistryShippingRegion(address.region ?? '');
    _postal.text = (address.postalCode ?? '').trim();
    _countryCode = address.countryCode;
  }

  Future<void> _save() async {
    final baby = _baby;
    if (baby == null) return;
    setState(() => _validateOnInteraction = true);
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    final patch = RegistryShippingAddress(
      line1: AppTextInputPolicy.normalizeForSubmit(
        AppTextInputKind.personName,
        _line1.text,
      ),
      line2: AppTextInputPolicy.normalizeForSubmit(
        AppTextInputKind.personName,
        _line2.text,
      ),
      city: AppTextInputPolicy.normalizeForSubmit(
        AppTextInputKind.personName,
        _city.text,
      ),
      region: formatRegistryShippingRegion(_region.text),
      postalCode: _postal.text.trim(),
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.shippingRemoveTitle,
      message: l10n.messageFollowersLonger,
      confirmLabel: l10n.actionRemove,
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
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PrototypeSubpageScaffold(
      title: l10n.shippingAddressTitle,
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: AppMetrics.subpageFormScrollPadding,
          children: [
            Text(
              l10n.hintShouldSendRegistryGifts,
              style: context.textStyles.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppMetrics.formFieldSpacing),
            AppLabeledTextFormField(
              semanticsId: 'registry_shipping_line1',
              label: l10n.fieldStreetAddress,
              hint: l10n.label123MainSt,
              kind: AppTextInputKind.personName,
              controller: _line1,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              validator: (v) => validateRegistryShippingLine1(AppLocalizations.of(context)!, v),
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextFormField(
              label: l10n.fieldAptSuiteEtcOptional,
              hint: l10n.fieldApt4b,
              kind: AppTextInputKind.personName,
              controller: _line2,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextFormField(
              label: l10n.fieldCity,
              hint: l10n.labelSpringfield,
              kind: AppTextInputKind.personName,
              controller: _city,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              validator: (v) => validateRegistryShippingCity(AppLocalizations.of(context)!, v),
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextFormField(
              label: l10n.fieldStateProvinceOptional,
              hint: l10n.labelIl,
              kind: AppTextInputKind.personName,
              controller: _region,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextFormField(
              label: l10n.fieldZipPostalCode,
              hint: '62704',
              kind: AppTextInputKind.none,
              controller: _postal,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              validator: (v) => validateRegistryShippingPostalCode(AppLocalizations.of(context)!, v),
              autovalidateMode: _autovalidateMode,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.fieldLabelGap),
              child: Text(AppLocalizations.of(context)!.shippingCountryLabel, style: context.fieldLabelStyle),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppMetrics.formFieldSpacing,
              ),
              child: AppCountryDropdownField(
                countries: _countries,
                value: _countryCode,
                enabled: !_saving,
                validator: (v) => validateCountryCode(AppLocalizations.of(context)!, v),
                autovalidateMode: _autovalidateMode,
                onChanged: (code) => setState(() => _countryCode = code),
              ),
            ),
            AppSemantics.button(
              'registry_shipping_save',
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(AppLocalizations.of(context)!.shippingSave),
              ),
              label: l10n.shippingSave,
            ),
            if (_hadAddress) ...[
              const SizedBox(height: AppMetrics.formFieldSpacing - 4),
              OutlinedButton(
                onPressed: _saving ? null : _clear,
                style: AppButtonStyles.outlinedDestructive,
                child: Text(AppLocalizations.of(context)!.shippingRemove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
