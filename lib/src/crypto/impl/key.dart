//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:tezart/src/crypto/crypto.dart' as crypto hide Prefixes;
import 'package:tezart/src/crypto/crypto.dart' show Prefixes;

String  addressFromPublicKey(String publicKey) => crypto.catchUnhandledErrors(() {
  final publicKeyBytes = crypto.decodeWithoutPrefix(publicKey);
  final hash = crypto.hashWithDigestSize(
    size: 160,
    bytes: publicKeyBytes,
  );

  return crypto.encodeWithPrefix(
    prefix: Prefixes.tz1,
    bytes: hash,
  );
});