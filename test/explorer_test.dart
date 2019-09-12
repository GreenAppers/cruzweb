// Copyright 2019 cruzall developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';

import '../cruzawl-ui/test/explorer_test.dart' as explorerTest;

void main() async {
  await explorerTest.runExplorerGroups((String asset) => 'web/assets/' + asset);
}
