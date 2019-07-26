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
import 'package:cruzweb/cruzawl-ui/localizations.dart';
import 'package:cruzweb/cruzawl-ui/model.dart';
import 'package:cruzweb/cruzawl-ui/network.dart';
import 'package:cruzweb/cruzawl-ui/transaction.dart';
import 'package:cruzweb/cruzawl-ui/ui.dart';

class CruzWebLoading extends StatelessWidget {
  final Currency currency;
  CruzWebLoading(this.currency);

  @override
  Widget build(BuildContext context) {
    ScopedModel.of<Cruzawl>(context, rebuildOnChange: true);
    final ThemeData theme = Theme.of(context);
    final TextStyle linkStyle = TextStyle(
      color: theme.accentColor,
      decoration: TextDecoration.underline,
    );
    final TextStyle labelTextStyle = TextStyle(
      fontFamily: 'MartelSans',
      color: Colors.grey,
    );

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
                    style: labelTextStyle),
                GestureDetector(
                  child: Text(url, style: linkStyle),
                  onTap: () => window.open(url, url),
                ),
                Text('Accept the certificate and refresh the page.',
                    style: labelTextStyle),
              ],
            ),
          ),
          title: 'Error');
    }
  }
}

class CruzWebApp extends StatefulWidget {
  final Cruzawl appState;
  CruzWebApp(this.appState);

  @override
  CruzWebAppState createState() => CruzWebAppState();
}

class CruzWebAppState extends State<CruzWebApp> {
  @override
  Widget build(BuildContext context) {
    final double maxWidth = 700;
    final Cruzawl appState = widget.appState;
    final AppTheme theme =
        themes[appState.preferences.theme] ?? themes['teal'];

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
        localizationsDelegates: [
          AppLocalizationsDelegate(),
          //GlobalMaterialLocalizations.delegate,
          //GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: [Locale("en"), Locale("zh")],
        onGenerateTitle: (BuildContext context) =>
            AppLocalizations.of(context).title,
        onGenerateRoute: (settings) {
          final String name = settings.name;
          const String address = '/address/',
              addPeerUrl = '/addPeer',
              block = '/block/',
              height = '/height/',
              networkUrl = '/network',
              settingsUrl = '/settings',
              tipUrl = '/tip',
              transaction = '/transaction/';
          final Widget loading = CruzWebLoading(appState.currency);
          if (name.startsWith(address)) {
            String addressText = name.substring(address.length);
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModelDescendant<Cruzawl>(
                  builder: (context, child, model) => addressText == 'cruzbase'
                      ? CruzbaseWidget(
                          appState.currency, appState.currency.network.tip)
                      : ExternalAddressWidget(appState.currency, addressText,
                          loadingWidget: loading, maxWidth: maxWidth)),
            );
          } else if (name.startsWith(block))
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModelDescendant<Cruzawl>(
                builder: (context, child, model) => BlockWidget(
                    appState.currency,
                    maxWidth: maxWidth,
                    loadingWidget: loading,
                    blockId: name.substring(block.length)),
              ),
            );
          else if (name.startsWith(height))
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModelDescendant<Cruzawl>(
                builder: (context, child, model) => BlockWidget(
                    appState.currency,
                    maxWidth: maxWidth,
                    loadingWidget: loading,
                    blockHeight: int.tryParse(name.substring(height.length)) ??
                        appState.currency.network.tipHeight),
              ),
            );
          else if (name.startsWith(transaction))
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModelDescendant<Cruzawl>(
                builder: (context, child, model) => TransactionWidget(
                    appState.currency, TransactionInfo(),
                    maxWidth: maxWidth,
                    loadingWidget: loading,
                    transactionIdText: name.substring(transaction.length),
                    onHeightTap: (tx) => Navigator.of(context)
                        .pushNamed('/height/' + tx.height.toString())),
              ),
            );
          else if (name.startsWith(settingsUrl))
            return MaterialPageRoute(
              settings: settings,
              builder: (BuildContext context) =>
                  CruzWebSettings(appState, () => setState(() {})),
            );
          else if (name.startsWith(networkUrl))
            return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) => SimpleScaffold(
                    CruzawlNetworkSettings(),
                    title: appState.currency.ticker + ' Network'));
          else if (name.startsWith(addPeerUrl))
            return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) => SimpleScaffold(AddPeerWidget(), title: 'New Peer'));
          else if (name.startsWith(tipUrl))
            return MaterialPageRoute(
              settings: settings,
              builder: (BuildContext context) => ScopedModelDescendant<Cruzawl>(
                builder: (context, child, model) => BlockWidget(
                    appState.currency,
                    loadingWidget: loading,
                    maxWidth: maxWidth),
              ),
            );

          return MaterialPageRoute(
            builder: (BuildContext context) => ScopedModelDescendant<Cruzawl>(
              builder: (context, child, model) => CruzbaseWidget(
                  appState.currency, appState.currency.network.tip),
            ),
          );
        },
      ),
    );
  }
}

class CruzWebSettings extends StatefulWidget {
  final Cruzawl appState;
  final VoidCallback updateTheme;
  CruzWebSettings(this.appState, [this.updateTheme]);

  @override
  _CruzWebSettingsState createState() => _CruzWebSettingsState();
}

class _CruzWebSettingsState extends State<CruzWebSettings> {
  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
        ListView(
          padding: EdgeInsets.only(top: 20),
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.color_lens),
              title: Text('Theme'),
              trailing: DropdownButton<String>(
                value: widget.appState.preferences.theme,
                onChanged: (String val) {
                  widget.appState.preferences.theme = val;
                  if (widget.updateTheme != null) (widget.updateTheme)();
                },
                items: buildDropdownMenuItem(themes.keys.toList()),
              ),
            ),
          ],
        ),
        title: 'Settings');
  }
}

void setClipboardText(BuildContext context, String text) async =>
  await clippy.write(text);

void main() async {
  await ui.webOnlyInitializePlatform();
  initializeDateFormatting();
  debugPrint('Main ' + Uri.base.toString());

  Cruzawl appState = Cruzawl(setClipboardText, databaseFactoryMemoryFs,
      CruzawlPreferences(
          await databaseFactoryMemoryFs.openDatabase('settings.db')),
      null);
  appState.currency = Currency.fromJson('CRUZ');
  appState.currency.network.autoReconnectSeconds = null;
  appState
      .addPeer(PeerPreference(
          'Satoshi Locomoco', 'wallet.cruzbit.xyz', 'CRUZ', '',
          debugPrint: debugPrint))
      .connect();

  runApp(
    ScopedModel<Cruzawl>(model: appState, child: CruzWebApp(appState)),
  );
}
