// Copyright 2019 cruzweb developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:typed_data';

import 'package:flutter_web/material.dart';
import 'package:flutter_web_ui/ui.dart' as ui;

import 'package:scoped_model/scoped_model.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/network.dart';

import 'package:cruzweb/cruzawl-ui/address.dart';
import 'package:cruzweb/cruzawl-ui/block.dart';
import 'package:cruzweb/cruzawl-ui/cruzbase.dart';
import 'package:cruzweb/cruzawl-ui/transaction.dart';
import 'package:cruzweb/cruzawl-ui/ui.dart';

class CruzWeb extends Model {
  Currency currency = Currency.fromJson('CRUZ');
  CruzWeb() {
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
      return SimpleScaffold(
          "Loading...", Center(child: CircularProgressIndicator()));
    } else {
      String url = 'https' + currency.network.peerAddress.substring(3);
      return SimpleScaffold(
          "Error",
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
          ));
    }
  }
}

void main() async {
  await ui.webOnlyInitializePlatform();
  debugPrint('Main ' + Uri.base.toString());
  CruzWeb appState = CruzWeb();
  final double maxWidth = 700;

  runApp(
    ScopedModel<CruzWeb>(
      model: appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            primarySwatch: Colors.deepOrange, accentColor: Colors.orangeAccent),
        onGenerateRoute: (settings) {
          final String name = settings.name;
          const String address = '/address/',
              block = '/block/',
              height = '/height/',
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
          return MaterialPageRoute(
            builder: (BuildContext context) => ScopedModelDescendant<CruzWeb>(
              builder: (context, child, model) => BlockWidget(appState.currency,
                  loadingWidget: loading, maxWidth: maxWidth),
            ),
          );
        },
      ),
    ),
  );
}
