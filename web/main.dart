// Copyright 2019 cruzweb developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:typed_data';

import 'package:flutter_web/material.dart';
import 'package:flutter_web_ui/ui.dart' as ui;

import 'package:scoped_model/scoped_model.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/network.dart';

import 'package:cruzweb/cruzawl-ui/address.dart';
import 'package:cruzweb/cruzawl-ui/block.dart';
import 'package:cruzweb/cruzawl-ui/cruzbase.dart';
import 'package:cruzweb/cruzawl-ui/transaction.dart';
import 'package:cruzweb/cruzawl-ui/preferences.dart';
import 'package:cruzweb/cruzawl-ui/ui.dart';

class CruzWeb extends Model {
  final CruzallPreferences preferences;
  final Currency currency = Currency.fromJson('CRUZ');

  CruzWeb(this.preferences) {
    currency.network.autoReconnectSeconds = null;
    currency.network.tipChanged = tipChanged;
    currency.network.peerChanged = peerChanged;
    currency.network
        .addPeerWithSpec(
            PeerPreference('SatoshiLocomoco', 'wallet.cruzbit.xyz', 'CRUZ', '',
                debugPrint: debugPrint),
            currency.genesisBlockId())
        .connect();
  }

  void peerChanged() async {
    if (currency.network.hasPeer)
      (await currency.network.getPeer())
          .filterAdd(CruzPublicKey(Uint8List(32)), (v) {});
    notifyListeners();
  }

  void tipChanged() {
    debugPrint('updated ${currency.network.tipHeight}');
    notifyListeners();
  }
}

class CruzWebLoading extends StatelessWidget {
  final Currency currency;
  CruzWebLoading(this.currency);

  @override
  Widget build(BuildContext context) {
    ScopedModel.of<CruzWeb>(context, rebuildOnChange: true);
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
      return SimpleScaffold(Container(
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
        ), title: 'Error');
    }
  }
}

class CruzWebApp extends StatefulWidget {
  final CruzWeb appState;
  CruzWebApp(this.appState);

  @override
  CruzWebAppState createState() => CruzWebAppState();
}

class CruzWebAppState extends State<CruzWebApp> {
  @override
  Widget build(BuildContext context) {
    final double maxWidth = 700;
    final CruzWeb appState = widget.appState;
    final ThemeData theme =
      themes[appState.preferences.theme] ?? themes['deepOrange'];

    return ScopedModel<SimpleScaffoldActions>(
      model: SimpleScaffoldActions(<Widget>[
        (PopupMenuBuilder()
              ..addItem(
                icon: Icon(Icons.settings),
                text: 'Settings',
                onSelected: () => window.location.hash = '/settings',
              ))
            .build(
          icon: Icon(Icons.more_vert),
        ),
      ]),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        onGenerateRoute: (settings) {
          final String name = settings.name;
          const String address = '/address/',
              block = '/block/',
              height = '/height/',
              settingsUrl = '/settings',
              tipUrl = '/tip',
              transaction = '/transaction/';
          final Widget loading = CruzWebLoading(appState.currency);
          if (name.startsWith(address)) {
            String addressText = name.substring(address.length);
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModelDescendant<CruzWeb>(
                  builder: (context, child, model) => addressText == 'cruzbase'
                      ? CruzbaseWidget(
                          appState.currency, appState.currency.network.tip)
                      : ExternalAddressWidget(appState.currency, addressText,
                          loadingWidget: loading, maxWidth: maxWidth)),
            );
          } else if (name.startsWith(block))
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ScopedModelDescendant<CruzWeb>(
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
              builder: (context) => ScopedModelDescendant<CruzWeb>(
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
              builder: (context) => ScopedModelDescendant<CruzWeb>(
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
              builder: (BuildContext context) => CruzWebSettings(appState, () => setState((){})),
            );
          else if (name.startsWith(tipUrl))
            return MaterialPageRoute(
              settings: settings,
              builder: (BuildContext context) => ScopedModelDescendant<CruzWeb>(
                builder: (context, child, model) => BlockWidget(appState.currency,
                    loadingWidget: loading, maxWidth: maxWidth),
              ),
            );

          return MaterialPageRoute(
            builder: (BuildContext context) => ScopedModelDescendant<CruzWeb>(
              builder: (context, child, model) =>
                  CruzbaseWidget(appState.currency, appState.currency.network.tip),
            ),
          );
        },
      ),
    );
  }
}

class CruzWebSettings extends StatefulWidget {
  final CruzWeb appState;
  final VoidCallback updateTheme;
  CruzWebSettings(this.appState, [this.updateTheme]);

  @override
  _CruzWebSettingsState createState() => _CruzWebSettingsState();
}

class _CruzWebSettingsState extends State<CruzWebSettings> {
  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(ListView(
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
    ), title: 'Settings');
  }
}

void main() async {
  await ui.webOnlyInitializePlatform();
  debugPrint('Main ' + Uri.base.toString());
  CruzWeb appState =
    CruzWeb(CruzallPreferences(await databaseFactoryMemoryFs.openDatabase('settings.db')));
  runApp(
    ScopedModel<CruzWeb>(model: appState, child: CruzWebApp(appState)),
  );
}
