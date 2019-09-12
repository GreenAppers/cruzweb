// Copyright 2019 cruzweb developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:flutter/material.dart';

import 'package:clippy/browser.dart' as clippy;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/http.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/wallet.dart';
import 'package:cruzawl_ui/explorer/cruzbase.dart';
import 'package:cruzawl_ui/localization.dart';
import 'package:cruzawl_ui/model.dart';
import 'package:cruzawl_ui/routes.dart';
import 'package:cruzawl_ui/ui.dart';

class CruzWebLoading extends StatelessWidget {
  final PeerNetwork network;
  CruzWebLoading(this.network);

  @override
  Widget build(BuildContext context) {
    final Cruzawl appState =
        ScopedModel.of<Cruzawl>(context, rebuildOnChange: true);

    if (network.peerState != PeerState.disconnected) {
      return SimpleScaffold(Center(child: CircularProgressIndicator()),
          title: "Loading...");
    } else {
      String url = 'https' + network.peerAddress.substring(3);
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
  final Cruzawl appState;
  CruzWebApp(this.appState);

  @override
  Widget build(BuildContext context) {
    final double maxWidth = 700;
    final AppTheme theme = themes[appState.preferences.theme] ?? themes['teal'];

    return ScopedModel<SimpleScaffoldActions>(
      model: SimpleScaffoldActions(<Widget>[
        (PopupMenuBuilder()
              ..addItem(
                icon: Icons.settings,
                text: 'Settings',
                onSelected: () => window.location.hash = '/settings',
              )
              ..addItem(
                icon: Icons.vpn_lock,
                text: 'Network',
                onSelected: () => window.location.hash = '/network',
              )
              /*..addItem(
                icon: Icons.settings_input_svideo,
                text: 'Console',
                onSelected: () => window.location.hash = '/console',
              )*/
              ..addItem(
                icon: Icons.redeem,
                text: 'Donations',
                onSelected: () => window.location.hash =
                    '/address/RWEgB+NQs/T83EkmIFNVJG+xK64Hm90GmQgrdR2V7BI=',
              ))
            .build(
          icon: Icon(Icons.more_vert),
        ),
      ], searchBar: true),
      child: MaterialApp(
        theme: theme.data,
        debugShowCheckedModeBanner: false,
        locale: appState.localeOverride,
        localizationsDelegates: [
          LocalizationDelegate(title: 'cruzbase'),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: Localization.supportedLocales,
        onGenerateTitle: (BuildContext context) =>
            Localization.of(context).title,
        onGenerateRoute: CruzawlRoutes(
          appState,
          maxWidth: maxWidth,
          loadingWidget: CruzWebLoading(appState.network),
          defaultRoute: MaterialPageRoute(
            builder: (BuildContext context) =>
                ScopedModelDescendant<WalletModel>(
              builder: (context, child, model) => CruzbaseWidget(
                  appState.network,
                  wideStyle: useWideStyle(context, maxWidth)),
            ),
          ),
        ).onGenerateRoute,
      ),
    );
  }
}

String assetPath(String asset) => asset;

void setClipboardText(BuildContext context, String text) async =>
    await clippy.write(text);

Future<String> getClipboardText() async => 'unused';

void launchUrl(BuildContext context, String url) => window.open(url, url);

void main() async {
  debugPrint('Main ' + Uri.base.toString());

  Cruzawl appState = Cruzawl(
      assetPath,
      launchUrl,
      setClipboardText,
      getClipboardText,
      databaseFactoryMemoryFs,
      CruzawlPreferences(
          await databaseFactoryMemoryFs.openDatabase('settings.db'),
          () => NumberFormat.currency().currencyName),
      '/',
      NullFileSystem(),
      httpClient: HttpClientImpl(),
      packageInfo:
          PackageInfo('CruzWeb', 'com.greenappers.cruzweb', '1.1.1', '21'));

  Currency currency = Currency.fromJson('CRUZ');
  appState.addWallet(
      Wallet.fromPublicKeyList(
          databaseFactoryMemoryFs,
          appState.fileSystem,
          'empty.cruzall',
          'Empty wallet',
          findPeerNetworkForCurrency(appState.networks, currency),
          Seed(randBytes(64)),
          <PublicAddress>[currency.nullAddress],
          appState.preferences,
          debugPrint,
          appState.openedWallet),
      store: false);

  appState.network.autoReconnectSeconds = null;
  appState.connectPeers(currency);

  runApp(
    ScopedModel<Cruzawl>(
      model: appState,
      child: ScopedModel<WalletModel>(
        model: appState.wallet,
        child: ScopedModelDescendant<Cruzawl>(
            builder: (context, child, model) => CruzWebApp(appState)),
      ),
    ),
  );
}
