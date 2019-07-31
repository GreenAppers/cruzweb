// Copyright 2019 cruzweb developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:flutter_web/material.dart';
import 'package:flutter_web_ui/ui.dart' as ui;

import 'package:clippy/browser.dart' as clippy;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';

import 'package:cruzweb/cruzawl-ui/address.dart';
import 'package:cruzweb/cruzawl-ui/block.dart';
import 'package:cruzweb/cruzawl-ui/cruzbase.dart';
import 'package:cruzweb/cruzawl-ui/localization.dart';
import 'package:cruzweb/cruzawl-ui/model.dart';
import 'package:cruzweb/cruzawl-ui/network.dart';
import 'package:cruzweb/cruzawl-ui/settings.dart';
import 'package:cruzweb/cruzawl-ui/transaction.dart';
import 'package:cruzweb/cruzawl-ui/ui.dart';

class CruzWebLoading extends StatelessWidget {
  final Currency currency;
  CruzWebLoading(this.currency);

  @override
  Widget build(BuildContext context) {
    final Cruzawl appState =
        ScopedModel.of<Cruzawl>(context, rebuildOnChange: true);
    final ThemeData theme = Theme.of(context);

    if (currency.network.peerState != PeerState.disconnected) {
      return SimpleScaffold(Center(child: CircularProgressIndicator()),
          title: "Loading...");
    } else {
      String url = 'https' + currency.network.peerAddress.substring(3);
      return SimpleScaffold(
          Container(
            padding: EdgeInsets.all(32),
            child: Column(
              children: <Widget>[
                Text('If this is a new browser session, visit:',
                    style: appState.theme.labelStyle),
                GestureDetector(
                  child: Text(url, style: appState.theme.linkStyle),
                  onTap: () => window.open(url, url),
                ),
                Text('Accept the certificate and refresh the page.',
                    style: appState.theme.labelStyle),
              ],
            ),
          ),
          title: 'Error');
    }
  }
}

class CruzWebApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Cruzawl appState =
        ScopedModel.of<Cruzawl>(context, rebuildOnChange: true);
    final double maxWidth = 700;
    final AppTheme theme = themes[appState.preferences.theme] ?? themes['teal'];

    return ScopedModel<SimpleScaffoldActions>(
      model: SimpleScaffoldActions(<Widget>[
        (PopupMenuBuilder()
              ..addItem(
                icon: Icon(Icons.settings),
                text: 'Settings',
                onSelected: () => window.location.hash = '/settings',
              )
              ..addItem(
                icon: Icon(Icons.vpn_lock),
                text: 'Network',
                onSelected: () => window.location.hash = '/network',
              ))
            .build(
          icon: Icon(Icons.more_vert),
        ),
      ]),
      child: MaterialApp(
        theme: theme.data,
        debugShowCheckedModeBanner: false,
        locale: appState.localeOverride,
        localizationsDelegates: [
          LocalizationDelegate(),
          //GlobalMaterialLocalizations.delegate,
          //GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: Localization.supportedLocales,
        onGenerateTitle: (BuildContext context) =>
            Localization.of(context).title,
        onGenerateRoute: (settings) {
          final PagePath page = parsePagePath(settings.name);
          final Widget loading = CruzWebLoading(appState.currency);

          switch (page.page) {
            case 'address':
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => ScopedModelDescendant<Cruzawl>(
                    builder: (context, child, model) => page.arg == 'cruzbase'
                        ? CruzbaseWidget(
                            appState.currency, appState.currency.network.tip)
                        : ExternalAddressWidget(appState.currency, page.arg,
                            loadingWidget: loading, maxWidth: maxWidth)),
              );

            case 'block':
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => ScopedModelDescendant<Cruzawl>(
                  builder: (context, child, model) => BlockWidget(
                      appState.currency,
                      maxWidth: maxWidth,
                      loadingWidget: loading,
                      blockId: page.arg),
                ),
              );

            case 'height':
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => ScopedModelDescendant<Cruzawl>(
                  builder: (context, child, model) => BlockWidget(
                      appState.currency,
                      maxWidth: maxWidth,
                      loadingWidget: loading,
                      blockHeight: int.tryParse(page.arg) ??
                          appState.currency.network.tipHeight),
                ),
              );

            case 'transaction':
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => ScopedModelDescendant<Cruzawl>(
                  builder: (context, child, model) => TransactionWidget(
                      appState.currency, TransactionInfo(),
                      maxWidth: maxWidth,
                      loadingWidget: loading,
                      transactionIdText: page.arg,
                      onHeightTap: (tx) => Navigator.of(context)
                          .pushNamed('/height/' + tx.height.toString())),
                ),
              );

            case 'settings':
              return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) => SimpleScaffold(
                    CruzallSettings(),
                    title: Localization.of(context).settings),
              );

            case 'support':
              return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) => SimpleScaffold(
                    CruzallSupport(),
                    title: Localization.of(context).support),
              );

            case 'network':
              return MaterialPageRoute(
                  settings: settings,
                  builder: (BuildContext context) => SimpleScaffold(
                      CruzawlNetworkSettings(),
                      title: appState.currency.ticker + ' Network'));

            case 'addPeer':
              return MaterialPageRoute(
                  settings: settings,
                  builder: (BuildContext context) =>
                      SimpleScaffold(AddPeerWidget(), title: 'New Peer'));

            case 'tip':
              return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) =>
                    ScopedModelDescendant<Cruzawl>(
                  builder: (context, child, model) => BlockWidget(
                      appState.currency,
                      loadingWidget: loading,
                      maxWidth: maxWidth),
                ),
              );

            default:
              return MaterialPageRoute(
                builder: (BuildContext context) =>
                    ScopedModelDescendant<Cruzawl>(
                  builder: (context, child, model) => CruzbaseWidget(
                      appState.currency, appState.currency.network.tip),
                ),
              );
          }
        },
      ),
    );
  }
}

String assetPath(String asset) => asset;

void setClipboardText(BuildContext context, String text) async =>
    await clippy.write(text);

void launchUrl(BuildContext context, String url) =>
  window.open(url, url);

void main() async {
  await ui.webOnlyInitializePlatform();
  initializeDateFormatting();
  debugPrint('Main ' + Uri.base.toString());

  Cruzawl appState = Cruzawl(
      assetPath,
      launchUrl,
      setClipboardText,
      databaseFactoryMemoryFs,
      CruzawlPreferences(
          await databaseFactoryMemoryFs.openDatabase('settings.db')),
      null,
      packageInfo: PackageInfo('Cruzall', 'com.greenappers.cruzall', '1.0.14', '14'));
  appState.currency = Currency.fromJson('CRUZ');
  appState.currency.network.autoReconnectSeconds = null;
  appState
      .addPeer(PeerPreference(
          'Satoshi Locomoco', 'wallet.cruzbit.xyz', 'CRUZ', '',
          debugPrint: debugPrint))
      .connect();

  runApp(
    ScopedModel<Cruzawl>(model: appState, child: CruzWebApp()),
  );
}
