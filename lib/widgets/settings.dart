import 'dart:async';

import 'package:biometric_storage/biometric_storage.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/config/environment_config.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/app_settings_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import '../config/platform.dart';
import '../generated/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../logging/logger.dart';
import 'coloured_safe_area_widget.dart';
import 'dialog_utils.dart';

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({
    Key? key,
  }) : super(key: key);

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> with TraceableClientMixin {
  @override
  String get traceTitle => widget.toStringShort();

  bool _isDeviceQuickUnlockEnabled = false;
  @override
  void initState() {
    super.initState();
    unawaited(_initBiometricStorageStatus());
  }

  Future<void> _initBiometricStorageStatus() async {
    final enabled = (await BiometricStorage().canAuthenticate()) == CanAuthenticateResponse.success;
    if (mounted) {
      setState(() {
        _isDeviceQuickUnlockEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);

    return BlocBuilder<AccountCubit, AccountState>(builder: (context, accountState) {
      final accessChildren = [];
      if (accountState is AccountChosen) {
        final userEmail = accountState.user.email;
        if (userEmail != null) {
          accessChildren.add(SettingsContainer(
            children: [
              Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Column(children: [
                    Text(str.useWebAppForOtherSettings),
                    TextButton.icon(
                      icon: Text(str.openWebApp),
                      label: Icon(Icons.open_in_new),
                      onPressed: () async {
                        await DialogUtils.openUrl(EnvironmentConfig.webUrl + '/#pfEmail=$userEmail,dest=signin');
                      },
                    ),
                  ]),
                ),
                Divider(
                  height: 0.0,
                ),
              ])
            ],
          ));

          accessChildren.add(SettingsContainer(
            children: [
              Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Column(
                    children: [
                      Text(str.manageAccountSettingsDetail),
                      TextButton.icon(
                        icon: Text(str.manageAccount),
                        label: Icon(Icons.open_in_new),
                        onPressed: () async {
                          await DialogUtils.openUrl(
                              EnvironmentConfig.webUrl + '/#pfEmail=$userEmail,dest=manageAccount');
                        },
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 0.0,
                ),
              ])
            ],
          ));
        }
      } else {
        accessChildren.add(
          SimpleSettingsTile(
            title: str.changePassword,
            subtitle: str.changePasswordDetail,
            onTap: () async => await AppConfig.router.navigateTo(
              context,
              Routes.changePassword,
              transition: TransitionType.inFromRight,
            ),
          ),
        );
      }
      return BlocBuilder<AutofillCubit, AutofillState>(builder: (context, autofillState) {
        return ColouredSafeArea(
          child: SettingsScreen(
            title: str.settings,
            children: [
              SettingsGroup(
                title: str.setGenTheme,
                children: [
                  RadioSettingsTile<String>(
                    title: str.setGenTheme,
                    showTitles: false,
                    settingKey: 'theme',
                    values: <String, String>{
                      'sys': str.setGenTitlebarStyleDefault,
                      'lt': str.setGenThemeLt,
                      'dk': str.setGenThemeDk,
                    },
                    selected: 'sys',
                    onChange: (String value) {
                      BlocProvider.of<AppSettingsCubit>(context).changeTheme(value);
                    },
                  ),
                ],
              ),
              SettingsGroup(title: str.deviceAutoFill, children: [
                Visibility(
                  visible: autofillState is AutofillAvailable,
                  child: autofillState is AutofillAvailable
                      ? SettingsContainer(
                          children: [
                            AutofillStatusWidget(
                                isEnabled: autofillState.enabled,
                                isDeviceQuickUnlockEnabled: _isDeviceQuickUnlockEnabled),
                          ],
                        )
                      : Container(),
                ),
              ]),
              SettingsGroup(title: str.quickSignIn, children: [
                BiometricSettingWidget(isEnabledOnDevice: _isDeviceQuickUnlockEnabled),
              ]),
              SettingsGroup(
                title: str.menuSetGeneral,
                children: [
                  SimpleSettingsTile(
                    title: str.genPsTitle,
                    subtitle: str.managePasswordPresets,
                    onTap: () async => await AppConfig.router.navigateTo(
                      context,
                      Routes.passwordPresetManager,
                      transition: TransitionType.inFromRight,
                    ),
                  ),
                  SwitchSettingsTile(
                    settingKey: 'expandGroups',
                    title: str.setGenShowSubgroups,
                    defaultValue: true,
                  ),
                  //TODO:f: Need to store group in DB so this should really be a DB-specific setting.
                  // SwitchSettingsTile(
                  //   settingKey: 'rememberFilterGroup',
                  //   title: str.rememberFilterGroup,
                  //   defaultValue: false,
                  // ),
                  ...accessChildren,
                ],
              ),
            ],
          ),
        );
      });
    });
  }
}

class BiometricSettingWidget extends StatefulWidget {
  final bool isEnabledOnDevice;
  const BiometricSettingWidget({Key? key, required this.isEnabledOnDevice}) : super(key: key);

  @override
  State<BiometricSettingWidget> createState() => _BiometricSettingWidgetState();
}

class _BiometricSettingWidgetState extends State<BiometricSettingWidget> {
  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final quickUnlockSettings = [
      TextInputSettingsTile(
        title: str.automaticallySignInFor,
        settingKey: 'authGracePeriod',
        initialValue: '60',
        keyboardType: TextInputType.number,
        validator: (String? gracePeriod) {
          if (gracePeriod != null) {
            final number = int.tryParse(gracePeriod);
            if (number != null && number >= 1 && number <= 3600) {
              return null;
            }
          }
          return str.enterNumberBetweenXAndY(1, 3600);
        },
        onChange: (_) async {
          final vaultCubit = BlocProvider.of<VaultCubit>(context);
          await vaultCubit.disableQuickUnlock();
          final user = BlocProvider.of<AccountCubit>(context).currentUserIfKnown;
          await vaultCubit.enableQuickUnlock(
            user,
            vaultCubit.currentVaultFile?.files.current,
          );
        },
        autovalidateMode: AutovalidateMode.always,
      ),
      TextInputSettingsTile(
        title: str.requireFullPasswordEvery,
        settingKey: 'requireFullPasswordPeriod',
        initialValue: '60',
        keyboardType: TextInputType.number,
        validator: (String? requireFullPasswordPeriod) {
          if (requireFullPasswordPeriod != null) {
            final number = int.tryParse(requireFullPasswordPeriod);
            if (number != null && number >= 1 && number <= 180) {
              return null;
            }
          }
          return str.enterNumberBetweenXAndY(1, 180);
        },
        onChange: (_) async {
          final vaultCubit = BlocProvider.of<VaultCubit>(context);
          await vaultCubit.disableQuickUnlock();
          final user = BlocProvider.of<AccountCubit>(context).currentUserIfKnown;
          await vaultCubit.enableQuickUnlock(
            user,
            vaultCubit.currentVaultFile?.files.current,
          );
        },
        autovalidateMode: AutovalidateMode.always,
      ),
    ];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Column(children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Text(str.quickSignInExplainer(KeeVaultPlatform.isIOS ? 'Passcode' : 'PIN'))),
          Visibility(
            visible: !KeeVaultPlatform.isIOS,
            replacement: Column(children: quickUnlockSettings),
            child: SwitchSettingsTile(
              settingKey: 'biometrics-enabled',
              title: str.biometricSignIn,
              onChange: (value) async {
                final vaultCubit = BlocProvider.of<VaultCubit>(context);
                try {
                  if (!value) {
                    await vaultCubit.disableQuickUnlock();
                  } else {
                    final user = BlocProvider.of<AccountCubit>(context).currentUserIfKnown;
                    await vaultCubit.enableQuickUnlock(
                      user,
                      vaultCubit.currentVaultFile?.files.current,
                    );
                  }
                } on Exception catch (e) {
                  l.e('Exception when changing biometrics setting. Details follow: $e');
                }
              },
              enabled: widget.isEnabledOnDevice,
              defaultValue: true,
              childrenIfEnabled: quickUnlockSettings,
            ),
          ),
        ]),
      ),
      Divider(
        height: 0.0,
      ),
    ]);
  }
}

class AutofillStatusWidget extends StatefulWidget {
  final bool isEnabled;
  final bool isDeviceQuickUnlockEnabled;
  const AutofillStatusWidget({
    Key? key,
    required this.isEnabled,
    required this.isDeviceQuickUnlockEnabled,
  }) : super(key: key);

  @override
  State<AutofillStatusWidget> createState() => _AutofillStatusWidgetState();
}

class _AutofillStatusWidgetState extends State<AutofillStatusWidget> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    unawaited(_initPackageInfo());
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Column(children: [
          Visibility(
            visible: widget.isEnabled,
            replacement: Text(str.enableAutofillRequired(_packageInfo.appName)),
            child: Text(
              str.autofillEnabled +
                  (!widget.isDeviceQuickUnlockEnabled && KeeVaultPlatform.isIOS ? str.autofillRequiresQU : ''),
            ),
          ),
          Visibility(
            visible: !widget.isEnabled && KeeVaultPlatform.isAndroid,
            child: ElevatedButton(
              child: Text(str.enableAutofill),
              onPressed: () async {
                await BlocProvider.of<AutofillCubit>(context).requestEnable();
              },
            ),
          ),
          Visibility(
            visible: !widget.isEnabled && KeeVaultPlatform.isIOS,
            child: ElevatedButton(
              child: Text(str.enableAutofill),
              onPressed: () async {
                await DialogUtils.showSimpleAlertDialog(
                    context, str.enableAutofill, str.enableAutofillIosInstructions(_packageInfo.appName),
                    routeAppend: 'autofill-ios-instructions');
                await BlocProvider.of<AutofillCubit>(context).refresh();
              },
            ),
          ),
          Visibility(
            visible: widget.isEnabled && KeeVaultPlatform.isAndroid,
            child: SwitchSettingsTile(
              settingKey: 'autofillServiceEnableSaving',
              title: str.offerToSave,
              defaultValue: true,
              onChange: (value) async {
                // We assume the autofill preference's SharedPreferences feature
                // is in sync to begin with and always specify what the user has
                // requested from our own preference so in the worst case, the
                // user will have to toggle the switch a couple of times to
                // resync and fix any broken behaviour.
                await BlocProvider.of<AutofillCubit>(context).setSavingPreference(value);
              },
            ),
          ),
        ]),
      ),
      Divider(
        height: 0.0,
      ),
    ]);
  }
}
