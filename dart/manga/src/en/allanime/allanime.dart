// AllAnime / MKissa manga source.
//
// The GraphQL API of the site (https://api.mkissa.net/api) protects some
// queries: they have to carry a signed "aaReq" and their answer is encrypted.
// The scheme was reverse engineered from the site bundle:
//
//   mask   = fragments XOR buildIdSeed XOR salt
//   seed[i]= buildId.charCodeAt(i % len) ^ ((i*saltMul + saltAdd) & 255)
//   key    = bootstrap.partB XOR mask
//   blob   = [0x01][iv:12][ciphertext][gcm tag:16]      (AES-256-GCM)
//
//   request : {"v":1,"ts","epoch","buildId","qh","k"} encrypted with the key,
//             iv = SHA-256("epoch:buildId:qh:ts:lane")[0..12]
//   bootstrap: x-aa-boot = HMAC-SHA256(HMAC-SHA256(mask, bootPrefix+buildId),
//             "epoch|lane|group|host|buildId")
//
// Lanes: k9 = chapterPages (manga), k7 = episode (anime), k2 = music.
//
// Only dart:convert, dart:typed_data and the extension SDK are used. The
// request signature has to be encrypted, so AES-256-GCM and SHA-256 are
// implemented below (the runtime helper "decryptAESGCM" could replace the
// decryption, it is only kept here because it cannot be called from a plain
// dart program).
//
// The crypto constants are read from the site bundle, they change with every
// redeploy: run "dart run tool/mkissa_constants.dart" to get the current
// values.

import 'package:mangayomi/bridge_lib.dart';
import 'dart:convert';
import 'dart:typed_data';

// ============================================================================
// GraphQL documents
// ============================================================================

class Queries {
  static const String popularMangaQuery = """
    query (
        \$type: VaildPopularTypeEnumType!
        \$size: Int!
        \$page: Int
        \$dateRange: Int
        \$allowAdult: Boolean
        \$allowUnknown: Boolean
    ) {
        queryPopular(
            type: \$type
            size: \$size
            dateRange: \$dateRange
            page: \$page
            allowAdult: \$allowAdult
            allowUnknown: \$allowUnknown
        ) {
            recommendations {
                anyCard {
                    _id
                    name
                    thumbnail
                    englishName
                }
            }
        }
    }
  """;
  static const String searchQuery = """
    query (
        \$search: SearchInput
        \$size: Int
        \$page: Int
        \$translationType: VaildTranslationTypeMangaEnumType
        \$countryOrigin: VaildCountryOriginEnumType
    ) {
        mangas(
            search: \$search
            limit: \$size
            page: \$page
            translationType: \$translationType
            countryOrigin: \$countryOrigin
        ) {
            edges {
                _id
                name
                thumbnail
                englishName
            }
        }
    }
  """;
  static const String pageQuery = """
    query (
        \$id: String!
        \$translationType: VaildTranslationTypeMangaEnumType!
        \$chapterNum: String!
    ) {
        chapterPages(
            mangaId: \$id
            translationType: \$translationType
            chapterString: \$chapterNum
        ) {
            edges {
                streamerId
                sourceName
                chapterString
                pictureUrls
                pictureUrlHead
            }
            manga {
                countryOfOrigin
            }
        }
    }
  """;
  static const String detailsQuery = """
    query (\$id: String!) {
        manga(_id: \$id) {
            _id
            name
            thumbnail
            description
            authors
            genres
            tags
            status
            altNames
            englishName
        }
    }
  """;
  static const String chaptersQuery = """
    query (\$id: String!, \$chapterNumStart: Float!, \$chapterNumEnd: Float!) {
        episodeInfos(
            showId: \$id
            episodeNumStart: \$chapterNumStart
            episodeNumEnd: \$chapterNumEnd
        ) {
            episodeIdNum
            notes
            uploadDates
        }
    }
""";

  static Map<String, dynamic> buildPopularMangaQuery({
    required int page,
    int size = 20, // number of items per page
    String type = "manga",
    int dateRange = 0,
    bool allowAdult = false,
    bool allowUnknown = false,
  }) {
    return {
      "query": popularMangaQuery,
      "variables": {
        "type": type,
        "size": size,
        "page": page,
        "dateRange": dateRange,
        "allowAdult": allowAdult,
        "allowUnknown": allowUnknown,
      },
    };
  }

  static Map<String, dynamic> buildSearchQuery({
    required int page,
    int size = 20,
    String? query, // search string
    String? sortedBy, // "Name_ASC", "Name_DESC" or null (recently added)
    List<String>? genres,
    List<String>? excludeGenres,
    bool isManga = true,
    bool allowAdult = false,
    bool allowUnknown = false,
    String? translationType, // "sub", "dub"
    String? countryOrigin, // "JP", "KR", "CN", "ALL"
  }) {
    return {
      "query": searchQuery,
      "variables": {
        "search": {
          if (query != null) "query": query,
          if (sortedBy != null) "sortedBy": sortedBy,
          if (genres != null) "genres": genres,
          if (excludeGenres != null) "excludeGenres": excludeGenres,
          "isManga": isManga,
          "allowAdult": allowAdult,
          "allowUnknown": allowUnknown,
        },
        "size": size,
        "page": page,
        "translationType": translationType ?? "sub",
        "countryOrigin": countryOrigin ?? "ALL",
      },
    };
  }

  static Map<String, dynamic> buildPageQuery({
    required String id,
    required String chapterNum,
    String translationType = "sub", // "sub" or "dub"
  }) {
    return {
      "query": pageQuery,
      "variables": {
        "id": id,
        "translationType": translationType,
        "chapterNum": chapterNum,
      },
    };
  }

  static Map<String, dynamic> buildDetailsQuery(String id) {
    return {
      "query": detailsQuery,
      "variables": {"id": id},
    };
  }

  /// [chapterNumStart], [chapterNumEnd] are inclusive\
  /// [id] is manga id without "manga@" prefix
  static Map<String, dynamic> buildChaptersQuery({
    required String id,
    double chapterNumStart = 0.0,
    double chapterNumEnd = 9999.0,
  }) {
    return {
      "query": chaptersQuery,
      "variables": {
        "id": "manga@$id",
        "chapterNumStart": chapterNumStart,
        "chapterNumEnd": chapterNumEnd,
      },
    };
  }
}

// ============================================================================
// mkissa.to crypto (pure Dart, no state, no packages)
// ============================================================================

// SHA-256 (FIPS 180-4).
Uint8List _sha256(List<int> message) {
  const k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  final h = Uint32List.fromList([
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ]);
  final msg = Uint8List.fromList(message);
  final padded = Uint8List((msg.length + 9 + 63) ~/ 64 * 64);
  padded.setRange(0, msg.length, msg);
  padded[msg.length] = 0x80;
  final lenBytes = ByteData(8)..setUint64(0, msg.length * 8, Endian.big);
  padded.setRange(
    padded.length - 8,
    padded.length,
    lenBytes.buffer.asUint8List(),
  );

  final w = Uint32List(64);
  for (var off = 0; off < padded.length; off += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = ByteData.sublistView(padded, off + i * 4, off + i * 4 + 4)
          .getUint32(0, Endian.big);
    }
    for (var i = 16; i < 64; i++) {
      w[i] = w[i - 16] +
          (_rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)) +
          w[i - 7] +
          (_rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10));
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], x = h[7];
    for (var i = 0; i < 64; i++) {
      final t1 = (x +
              (_rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25)) +
              ((e & f) ^ (~e & g)) +
              k[i] +
              w[i]) &
          0xffffffff;
      final t2 = (_rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22)) +
          ((a & b) ^ (a & c) ^ (b & c));
      x = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    h[0] = (h[0] + a) & 0xffffffff;
    h[1] = (h[1] + b) & 0xffffffff;
    h[2] = (h[2] + c) & 0xffffffff;
    h[3] = (h[3] + d) & 0xffffffff;
    h[4] = (h[4] + e) & 0xffffffff;
    h[5] = (h[5] + f) & 0xffffffff;
    h[6] = (h[6] + g) & 0xffffffff;
    h[7] = (h[7] + x) & 0xffffffff;
  }
  final out = Uint8List(32);
  ByteData.sublistView(out).setUint32(0, h[0], Endian.big);
  for (var i = 1; i < 8; i++) {
    ByteData.sublistView(out).setUint32(i * 4, h[i], Endian.big);
  }
  return out;
}

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;

/// HMAC-SHA256 (RFC 2104).
Uint8List _hmacSha256(List<int> key, List<int> message) {
  var k = Uint8List.fromList(key);
  if (k.length > 64) k = _sha256(k);
  final block = Uint8List(64)..setRange(0, k.length, k);
  final inner = Uint8List(64);
  final outer = Uint8List(64);
  for (var i = 0; i < 64; i++) {
    inner[i] = block[i] ^ 0x36;
    outer[i] = block[i] ^ 0x5c;
  }
  return _sha256([...outer, ..._sha256([...inner, ...message])]);
}

String _hex(List<int> bytes) =>
    bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

/// AES-256-GCM, encrypt direction only.
///
/// Decryption is done by the runtime helper `decryptAESGCM`, so only the
/// forward cipher is needed here.
class _AesGcm {
  static const _sbox = <int>[
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, //
    0xfe, 0xd7, 0xab, 0x76, 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0,
    0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0, 0xb7, 0xfd, 0x93, 0x26,
    0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2,
    0xeb, 0x27, 0xb2, 0x75, 0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0,
    0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84, 0x53, 0xd1, 0x00, 0xed,
    0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f,
    0x50, 0x3c, 0x9f, 0xa8, 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5,
    0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2, 0xcd, 0x0c, 0x13, 0xec,
    0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14,
    0xde, 0x5e, 0x0b, 0xdb, 0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c,
    0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, 0xe7, 0xc8, 0x37, 0x6d,
    0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f,
    0x4b, 0xbd, 0x8b, 0x8a, 0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e,
    0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e, 0xe1, 0xf8, 0x98, 0x11,
    0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f,
    0xb0, 0x54, 0xbb, 0x16,
  ];

  /// Encrypts [plaintext] and returns `ciphertext || gcm tag`.
  static Uint8List seal(
    Uint8List key,
    Uint8List iv,
    List<int> plaintext,
  ) {
    final roundKeys = _expandKey(key);
    final h = Uint8List(16);
    _encryptBlock(roundKeys, Uint8List(16), h);
    final j0 = Uint8List(16)..setRange(0, 12, iv);
    j0[15] = 1;
    final ct = _gctr(roundKeys, j0, Uint8List.fromList(plaintext));
    final tag = _gctr(roundKeys, j0, _ghash(h, ct), fromJ0: true);
    return Uint8List.fromList([...ct, ...tag]);
  }

  /// Decrypts `ciphertext || gcm tag`.
  ///
  /// The runtime helper `decryptAESGCM` does the same, this is only used
  /// because it cannot be called from a plain dart program.
  static Uint8List open(
    Uint8List key,
    Uint8List iv,
    List<int> sealed,
  ) {
    final roundKeys = _expandKey(key);
    final h = Uint8List(16);
    _encryptBlock(roundKeys, Uint8List(16), h);
    final j0 = Uint8List(16)..setRange(0, 12, iv);
    j0[15] = 1;
    final ct = sealed.sublist(0, sealed.length - 16);
    final tag = sealed.sublist(sealed.length - 16);
    final expected = _gctr(roundKeys, j0, _ghash(h, Uint8List.fromList(ct)), fromJ0: true);
    for (var i = 0; i < 16; i++) {
      if (expected[i] != tag[i]) {
        throw StateError('AES-GCM authentication failed');
      }
    }
    return _gctr(roundKeys, j0, Uint8List.fromList(ct));
  }

  static Uint8List _expandKey(Uint8List key) {
    final nk = 8, nr = 14, total = 4 * (nr + 1);
    final w = Uint8List(total * 4)..setRange(0, 32, key);
    final temp = Uint8List(4);
    for (var i = nk; i < total; i++) {
      temp.setRange(0, 4, w, (i - 1) * 4);
      if (i % nk == 0) {
        final t = temp[0];
        temp[0] = _sbox[temp[1]] ^ _rcon[i ~/ nk - 1];
        temp[1] = _sbox[temp[2]];
        temp[2] = _sbox[temp[3]];
        temp[3] = _sbox[t];
      } else if (i % nk == 4) {
        for (var j = 0; j < 4; j++) {
          temp[j] = _sbox[temp[j]];
        }
      }
      for (var j = 0; j < 4; j++) {
        w[i * 4 + j] = w[(i - nk) * 4 + j] ^ temp[j];
      }
    }
    return w;
  }

  static const _rcon = <int>[
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, //
    0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d,
  ];

  static void _encryptBlock(
    Uint8List roundKeys,
    Uint8List input,
    Uint8List output,
  ) {
    final s = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      s[i] = input[i] ^ roundKeys[i];
    }
    for (var round = 1; round <= 14; round++) {
      for (var i = 0; i < 16; i++) {
        s[i] = _sbox[s[i]];
      }
      final t = Uint8List(16);
      for (var c = 0; c < 4; c++) {
        for (var r = 0; r < 4; r++) {
          t[c * 4 + r] = s[((c + r) % 4) * 4 + r];
        }
      }
      s.setRange(0, 16, t);
      if (round != 14) {
        for (var c = 0; c < 4; c++) {
          final i0 = c * 4;
          final a0 = s[i0], a1 = s[i0 + 1], a2 = s[i0 + 2], a3 = s[i0 + 3];
          s[i0] = _xtime(a0) ^ (_xtime(a1) ^ a1) ^ a2 ^ a3;
          s[i0 + 1] = a0 ^ _xtime(a1) ^ (_xtime(a2) ^ a2) ^ a3;
          s[i0 + 2] = a0 ^ a1 ^ _xtime(a2) ^ (_xtime(a3) ^ a3);
          s[i0 + 3] = (_xtime(a0) ^ a0) ^ a1 ^ a2 ^ _xtime(a3);
        }
      }
      for (var i = 0; i < 16; i++) {
        s[i] ^= roundKeys[round * 16 + i];
      }
    }
    output.setRange(0, 16, s);
  }

  static int _xtime(int b) => ((b << 1) ^ ((b & 0x80) != 0 ? 0x1b : 0)) & 0xff;

  static Uint8List _gctr(
    Uint8List roundKeys,
    Uint8List j0,
    Uint8List data, {
    bool fromJ0 = false,
  }) {
    final out = Uint8List(data.length);
    final counter = Uint8List(16)..setRange(0, 16, j0);
    // the keystream for the data starts at J0 + 1, the tag uses E(K, J0)
    if (!fromJ0) _inc32(counter);
    var offset = 0;
    while (offset < data.length) {
      final ks = Uint8List(16);
      _encryptBlock(roundKeys, counter, ks);
      final n = data.length - offset < 16 ? data.length - offset : 16;
      for (var i = 0; i < n; i++) {
        out[offset + i] = data[offset + i] ^ ks[i];
      }
      offset += n;
      _inc32(counter);
    }
    return out;
  }

  static void _inc32(Uint8List counter) {
    for (var i = 15; i >= 12; i--) {
      counter[i] = (counter[i] + 1) & 0xff;
      if (counter[i] != 0) break;
    }
  }

  static Uint8List _ghash(Uint8List h, Uint8List ct) {
    final y = Uint8List(16);
    void absorb(List<int> data) {
      for (var i = 0; i < data.length; i += 16) {
        final chunk = Uint8List(16);
        final n = data.length - i < 16 ? data.length - i : 16;
        chunk.setRange(0, n, data, i);
        for (var j = 0; j < 16; j++) {
          y[j] ^= chunk[j];
        }
        _gmul(y, h);
      }
    }

    absorb(ct);
    final len = Uint8List(16);
    ByteData.sublistView(len).setUint64(8, ct.length * 8, Endian.big);
    for (var j = 0; j < 16; j++) {
      y[j] ^= len[j];
    }
    _gmul(y, h);
    return y;
  }

  /// Multiplication in GF(2^128) (GCM bit order).
  static void _gmul(Uint8List x, Uint8List y) {
    final z = Uint8List(16);
    final v = Uint8List(16)..setRange(0, 16, y);
    for (var i = 0; i < 128; i++) {
      if ((x[i >> 3] >> (7 - (i & 7))) & 1 == 1) {
        for (var j = 0; j < 16; j++) {
          z[j] ^= v[j];
        }
      }
      final lsb = v[15] & 1;
      for (var j = 15; j > 0; j--) {
        v[j] = ((v[j] >> 1) | ((v[j - 1] & 1) << 7)) & 0xff;
      }
      v[0] = (v[0] >> 1) & 0xff;
      if (lsb == 1) v[0] ^= 0xe1;
    }
    x.setRange(0, 16, z);
  }
}

// ============================================================================
// mkissa.to client: signs protected queries and decrypts their response
// ============================================================================

/// Key material of the current site build.
///
/// The site ships these values inside its (obfuscated) JavaScript bundle and
/// changes them on every redeploy. Run `dart run tool/mkissa_constants.dart`
/// to read the current values from the live bundle and paste them here.
class MkissaClient {
  MkissaClient(this.client, {String? userAgent})
      : _userAgent =
            userAgent ??
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36';

  final Client client;
  final String _userAgent;

  static const String _origin = 'https://mkissa.to';
  static const String _apiOrigin = 'https://api.mkissa.net';
  static const String _group = 'mkissa';
  static const String _buildId = '189';
  static const int _saltMul = 175,
      _saltAdd = 202,
      _fragMul = 129,
      _fragAdd = 61;
  static const List<String> _frags = [
    'pF98Ab2CCc0=',
    'gEhpQrtSn+M=',
    'oPeHj9dBNTU=',
    '7XcuzKoXhgs=',
  ];
  static const String _bootPrefix = 'iGmNgPGdi:';
  static const int _epochMs = 604800000, _graceMs = 86402000;

  /// per lane key material, filled on demand
  final Map<String, _LaneKey> _lanes = {};

  Map<String, String> get _headers => {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.7',
    'content-type': 'application/json',
    'origin': _origin,
    'referer': '$_origin/',
    'user-agent': _userAgent,
    'x-build-id': _buildId,
  };

  /// Runs a GraphQL query.
  ///
  /// Queries of a protected lane (`chapterPages`, `episode`, `music`) are
  /// signed with `aaReq` and their response is decrypted, everything else is
  /// sent as is.
  Future<Map<String, dynamic>> query(
    String query, {
    Map<String, dynamic> variables = const {},
  }) async {
    final lane = _laneOf(query);
    final body = <String, dynamic>{'query': query, 'variables': variables};
    Uint8List? key;

    if (lane != null) {
      final laneKey = await _laneKey(lane);
      key = laneKey.key;
      final hash = _hex(_sha256(utf8.encode(query)));
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 300000 * 300000;
      final iv = _sha256(
        utf8.encode('${laneKey.epoch}:$_buildId:$hash:$ts:$lane'),
      ).sublist(0, 12);
      final sealed = _AesGcm.seal(
        key,
        Uint8List.fromList(iv),
        utf8.encode(
          jsonEncode({
            'v': 1,
            'ts': ts,
            'epoch': laneKey.epoch,
            'buildId': _buildId,
            'qh': hash,
            'k': lane,
          }),
        ),
      );
      body['extensions'] = {
        'persistedQuery': {'version': 1, 'sha256Hash': hash},
        'k': lane,
        'aaReq': base64Encode([1, ...iv, ...sealed]),
      };
    }

    final res = await client.post(
      Uri.parse('$_apiOrigin/api'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'];
    if (key != null && data is Map<String, dynamic> && data['tobeparsed'] is String) {
      json['data'] = _decrypt(data['tobeparsed'] as String, key);
    }
    return json;
  }

  /// Decrypts `data.tobeparsed`.
  Map<String, dynamic> _decrypt(String tobeparsed, Uint8List key) {
    final raw = base64Decode(tobeparsed);
    final plain = _AesGcm.open(
      key,
      Uint8List.fromList(raw.sublist(1, 13)),
      raw.sublist(13), // ciphertext || tag
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }

  /// Fetches the key material of a lane (cached).
  Future<_LaneKey> _laneKey(String lane) async {
    final cached = _lanes[lane];
    if (cached != null) return cached;

    final epoch = _epoch();
    final p = _hmacSha256(_mask(), utf8.encode('$_bootPrefix$_buildId'));
    final token = _hex(
      _hmacSha256(
        p,
        utf8.encode('$epoch|$lane|$_group|${Uri.parse(_origin).host}|$_buildId'),
      ),
    );
    final res = await client.get(
      Uri.parse('$_apiOrigin/client-crypto/v1/bootstrap?buildId=$_buildId&k=$lane'),
      headers: {..._headers, 'x-aa-boot': token},
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final partB = base64Decode(json['partB'] as String);
    final mask = _mask();
    final key = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      key[i] = partB[i] ^ mask[i];
    }
    final laneKey = _LaneKey(json['epoch'] as int? ?? epoch, key);
    _lanes[lane] = laneKey;
    return laneKey;
  }

  /// The 32 byte client mask: fragments XOR build id seed XOR salt.
  Uint8List _mask() {
    final seed = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      seed[i] =
          _buildId.codeUnitAt(i % _buildId.length) ^ ((i * _saltMul + _saltAdd) & 255);
    }
    final mask = Uint8List(32);
    for (var u = 0; u < _frags.length; u++) {
      final frag = base64Decode(_frags[u]);
      for (var g = 0; g < 8; g++) {
        mask[u * 8 + g] =
            frag[g] ^
            seed[u * 8 + g] ^
            ((u * _fragMul + g * _fragAdd) & 255);
      }
    }
    return mask;
  }

  /// The epoch the site itself would use right now.
  int _epoch() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = now ~/ _epochMs;
    return now - t * _epochMs < _graceMs && t > 0 ? t - 1 : t;
  }

  /// The lane of a query, `null` for queries that are not protected.
  String? _laneOf(String query) {
    if (RegExp(r'\bchapterPages\s*\(', caseSensitive: false).hasMatch(query)) {
      return 'k9';
    }
    if (RegExp(r'\bepisode\s*\(', caseSensitive: false).hasMatch(query)) {
      return 'k7';
    }
    if (RegExp(r'\bmusic\s*\(', caseSensitive: false).hasMatch(query)) {
      return 'k2';
    }
    return null;
  }
}

class _LaneKey {
  _LaneKey(this.epoch, this.key);

  final int epoch;
  final Uint8List key;
}

// ============================================================================
// Extension helpers and the MangaYomi source implementation
// ============================================================================

class MangaUtils {
  static String getMangaName(Map<String, String> mangaData) {
    String? englishName = mangaData["englishName"];
    String? name = mangaData["name"];
    String? nativeName = mangaData["nativeName"];
    if (englishName != null) return englishName;
    if (name != null) return name;
    if (nativeName != null) return nativeName;
    return "No Title";
  }

  // Parse status from string to enum index
  static dynamic getStatus(String? status) {
    final statusList = [
      {
        "ongoing": 0,
        "complete": 1,
        "hiatus": 2,
        "canceled": 3,
        "publishingFinished": 4,
      },
    ];
    if (status == null) return parseStatus("unknown", statusList);
    status = status.toLowerCase();
    if (status.contains("finished") || status.contains("complete"))
      status = "complete";
    else if (status.contains("releasing") ||
        status.contains("ongoing") ||
        status.contains("publishing"))
      status = "ongoing";
    else
      status = "unknown";
    return parseStatus(status, statusList);
  }

  static String getAuthor(Map<String, dynamic> data) {
    if (data.containsKey("authors") && data["authors"] is List) {
      return (data["authors"] as List).first.toString();
    }
    return "None";
  }

  static String buildDescription(String desc, List<String> altNames) {
    desc = parseHtml(desc).body?.text ?? desc;
    desc += altNames.isNotEmpty
        ? "\n\nAlternative Names: \n${altNames.join('\n')}"
        : "";
    return desc.trim();
  }

  static List<String> combineGenres(List<String> genres, List<String> tags) {
    final List<String> genreSet = [];
    for (var genre in genres) {
      if (!genreSet.contains(genre.toString())) genreSet.add(genre.toString());
    }
    for (var tag in tags) {
      if (!genreSet.contains(tag.toString())) genreSet.add(tag.toString());
    }
    return genreSet.toList();
  }
}

class URLS {
  static const String MANGA_COVER_URL_HEAD =
      'https://wp.youtube-anime.com/aln.youtube-anime.com';
  static const String MANGA_PAGE_URL_HEAD = 'https://wp.youtube-anime.com';
  static const String MANGA_PAGE_URL_HEAD_DEPRECATED =
      'https://aln.youtube-anime.com'; // old url it redirects to new one
  static const String MANGA_PAGE_URL_HEAD_REDIRECT =
      'https://ytimgf.youtube-anime.com'; // the other base urls redirect to this one,
  static const String BASE_URL = 'https://mkissa.to';
  static const String API_URL = 'https://api.mkissa.net/api';

  /// Returns absolute manga cover URL
  static String buildMangaCoverUrl(String url) {
    if (url.startsWith('http')) {
      return url;
    } else {
      return '$MANGA_COVER_URL_HEAD/$url';
    }
  }

  static String stripHttp(String url) {
    url = url.endsWith("/") ? url.substring(0, url.length - 1) : url;
    return url.startsWith(RegExp(r"https?://")) ? url.split("://").last : url;
  }

  static String addHttp(String url) {
    url = url.endsWith("/") ? url.substring(0, url.length - 1) : url;
    return url.startsWith(RegExp(r"https?://")) ? url : "https://$url";
  }

  /// [mangaPageUrl] must be without stripped of http(s)
  static String buildMangaPageUrl(
    String pictureUrlHead,
    String urlPath,
    String imageQuality,
  ) {
    // ::
    // for any quality that isnt 480
    // the url redirects to new base_url
    // which makes the Client change the referer to current full url
    // which causes the request to fail with 403,
    // so we have to redirect to the new base url ourselves for non 480 quality
    // ::
    if (imageQuality == "800")
      return addHttp("${URLS.MANGA_PAGE_URL_HEAD_REDIRECT}/$urlPath?w=800");
    if (imageQuality == "480")
      return addHttp(
        "${URLS.MANGA_PAGE_URL_HEAD}/${URLS.stripHttp(pictureUrlHead)}/$urlPath?w=480",
      );
    return addHttp("${URLS.MANGA_PAGE_URL_HEAD_REDIRECT}/$urlPath");
  }

  /// Returns absolute manga URL link
  static String buildMangaURL(String mangaId) {
    return '$BASE_URL/manga/$mangaId';
  }
}

class FilterGet {
  static (List<String>?, List<String>?) getIncludeExcludeGenres(
    FilterList filterList,
  ) {
    List<dynamic> filters = filterList.filters;
    List<String> includeGenres = [];
    List<String> excludeGenres = [];
    for (var filter in filters) {
      // filter as GroupFilter;
      if (filter.type == "GenreFilter" && filter.state.isNotEmpty) {
        for (var tsFilter in filter.state) {
          // tsFilter as TriStateFilter;
          if (tsFilter.state == 0) continue;
          if (tsFilter.state == 1)
            includeGenres.add(tsFilter.value);
          else
            excludeGenres.add(tsFilter.value);
        }
      }
    }
    return (
      includeGenres.isEmpty ? null : includeGenres,
      excludeGenres.isEmpty ? null : excludeGenres,
    );
  }

  static String? getSelectedCountry(FilterList filterList) {
    List<dynamic> filters = filterList.filters;
    for (var filter in filters) {
      // filter as SelectFilter;
      if (filter.type == "CountryFilter") {
        String option = filter.values[filter.state].value;
        if (option != "ALL") return option;
      }
    }
    return null;
  }

  static String? getSelectedSort(FilterList filterList) {
    List<dynamic> filters = filterList.filters;
    for (var filter in filters) {
      // filter as SelectFilter;
      if (filter.type == "SortFilter") {
        String option = filter.values[filter.state].value;
        if (option.isNotEmpty) return option;
      }
    }
    return null;
  }
}

class AllManga extends MProvider {
  AllManga({required this.source});
  MSource source;
  final Client client = Client();

  /// Signed client for the mkissa.to / allanime GraphQL API.
  ///
  /// Protected queries (`chapterPages`, `episode`, `music`) have to carry an
  /// `aaReq` signature and their response is encrypted, see the header of this
  /// file for the scheme.
  late final MkissaClient api = MkissaClient(
    client,
    userAgent: preferenceUserAgent(),
  );

  @override
  bool get supportsLatest => true;

  @override
  Map<String, String> get headers => {
    "Accept": "*/*",
    "referer": "${URLS.BASE_URL}/",
    "user-agent": preferenceUserAgent(),
  };

  /// Runs a GraphQL query against the API and returns the (decrypted) data.
  Future<Map<String, dynamic>> apiQuery(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final res = await api.query(query, variables: variables);
    final errors = res["errors"];
    if (errors is List && errors.isNotEmpty) {
      throw Exception(errors.first["message"] ?? "API error");
    }
    final data = res["data"];
    if (data is! Map<String, dynamic>) throw Exception("No data returned");
    return data;
  }

  @override
  Future<MPages> getPopular(int page) async {
    List<MManga> mangaList = [];
    final query = Queries.buildPopularMangaQuery(page: page);
    final data = await apiQuery(
      query["query"] as String,
      query["variables"] as Map<String, dynamic>,
    );
    final items = data["queryPopular"]?["recommendations"];
    if (items == null || items is! List) return MPages([], false);
    for (var item in items) {
      final mangaData = item["anyCard"];
      final thumbnail = mangaData?["thumbnail"];
      final id = mangaData?["_id"];
      if (thumbnail == null || id == null) continue;
      mangaList.add(
        MManga(
          name: MangaUtils.getMangaName(mangaData),
          imageUrl: URLS.buildMangaCoverUrl(thumbnail.toString()),
          link: URLS.buildMangaURL(id.toString()),
        ),
      );
    }
    return MPages(mangaList, true);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    List<MManga> mangaList = [];
    final query = Queries.buildSearchQuery(page: page);
    final data = await apiQuery(
      query["query"] as String,
      query["variables"] as Map<String, dynamic>,
    );
    final items = data["mangas"]?["edges"];
    if (items == null || items is! List) return MPages([], false);
    for (var mangaData in items) {
      final thumbnail = mangaData["thumbnail"];
      final id = mangaData["_id"];
      if (thumbnail == null || id == null) continue;
      mangaList.add(
        MManga(
          name: MangaUtils.getMangaName(mangaData),
          imageUrl: URLS.buildMangaCoverUrl(thumbnail.toString()),
          link: URLS.buildMangaURL(id.toString()),
        ),
      );
    }
    return MPages(mangaList, true);
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    List<MManga> mangaList = [];
    var (includeGenres, excludeGenres) = FilterGet.getIncludeExcludeGenres(
      filterList,
    );
    final build = Queries.buildSearchQuery(
      page: page,
      query: query.trim().isEmpty ? null : query.trim(),
      genres: includeGenres,
      excludeGenres: excludeGenres,
      countryOrigin: FilterGet.getSelectedCountry(filterList),
      sortedBy: FilterGet.getSelectedSort(filterList),
    );
    final data = await apiQuery(
      build["query"] as String,
      build["variables"] as Map<String, dynamic>,
    );
    final items = data["mangas"]?["edges"];
    if (items == null || items is! List) return MPages([], false);
    for (var mangaData in items) {
      final thumbnail = mangaData?["thumbnail"];
      final id = mangaData?["_id"];
      if (thumbnail == null || id == null) continue;
      mangaList.add(
        MManga(
          name: MangaUtils.getMangaName(mangaData),
          imageUrl: URLS.buildMangaCoverUrl(thumbnail.toString()),
          link: URLS.buildMangaURL(id.toString()),
        ),
      );
    }
    return MPages(mangaList, true);
  }

  @override
  Future<MManga> getDetail(String url) async {
    final String mangaId = url.split("/").last;
    // Details
    final detailsQuery = Queries.buildDetailsQuery(mangaId);
    final detailsData = await apiQuery(
      detailsQuery["query"] as String,
      detailsQuery["variables"] as Map<String, dynamic>,
    );
    final manga = detailsData["manga"];
    if (manga == null) throw Exception("Manga details not found");
    // Chapters
    final chaptersQuery = Queries.buildChaptersQuery(id: mangaId);
    final chaptersData = await apiQuery(
      chaptersQuery["query"] as String,
      chaptersQuery["variables"] as Map<String, dynamic>,
    );
    final episodes = chaptersData["episodeInfos"];
    if (episodes == null || episodes is! List)
      throw Exception("Chapters not found");
    episodes.sort((b, a) => a["episodeIdNum"].compareTo(b["episodeIdNum"]));
    List<MChapter> chapters = [];
    for (var cur in episodes) {
      if (cur == null) continue;
      String? stime = cur["uploadDates"]?["sub"]?.toString().trim();
      String episodeNumber = cur["episodeIdNum"]?.toString() ?? "Unknown";
      List<dynamic> dates = [];
      if (stime != null)
        dates = parseDates([stime], "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", "en_US");
      chapters.add(
        MChapter(
          name: "Chapter $episodeNumber",
          dateUpload: dates.isNotEmpty ? dates.first : null,
          description: cur["notes"],
          url: URLS.buildMangaURL("$mangaId/chapter-$episodeNumber-sub"),
        ),
      );
    }
    return MManga(
      author: MangaUtils.getAuthor(manga),
      artist: MangaUtils.getAuthor(manga),
      genre: MangaUtils.combineGenres(
        manga["genres"] ?? [],
        manga["tags"] ?? [],
      ),
      imageUrl: URLS.buildMangaCoverUrl(manga["thumbnail"] ?? ""),
      link: URLS.buildMangaURL(mangaId),
      name: MangaUtils.getMangaName(manga),
      status: MangaUtils.getStatus(manga['status']),
      description: MangaUtils.buildDescription(
        manga["description"] ?? "",
        manga["altNames"] ?? "",
      ),
      chapters: chapters,
    );
  }

  // For manga chapter pages
  // old ->
  // https://allmanga.to/manga/SFrub9DDGMrmdZWyh/chapter-202-sub
  // new ->
  // https://mkissa.to/manga/SFrub9DDGMrmdZWyh/chapter-202-sub
  @override
  Future<List<dynamic>> getPageList(String url) async {
    List<String> split = url.split("/");
    if (split.length < 3) return [];
    final String mangaId = split[split.length - 2];
    List<String> chapter = split.last.split("-");
    if (chapter.length < 2) return [];
    String chapterNum = chapter[1];
    String chapterType = chapter.last;
    final build = Queries.buildPageQuery(
      id: mangaId,
      chapterNum: chapterNum,
      translationType: chapterType == "sub" ? "sub" : "dub",
    );
    // `chapterPages` is a protected lane (k9): the request is signed and the
    // response is encrypted, `apiQuery` takes care of both.
    final data = await apiQuery(
      build["query"] as String,
      build["variables"] as Map<String, dynamic>,
    );
    final pagesData = data["chapterPages"];
    if (pagesData == null) throw Exception("Page data not found");
    final edges = pagesData["edges"];
    if (edges == null || edges is! List || edges.isEmpty)
      throw Exception("Pages not found");
    final edge = edges.first;
    String? pictureUrlHead = edge["pictureUrlHead"]?.toString();
    final pictureUrls = edge["pictureUrls"];
    if (pictureUrlHead == null || pictureUrls == null || pictureUrls is! List)
      throw Exception("Pages not found");
    List<dynamic> pageUrls = [];
    for (var page in pictureUrls) {
      final String pagePath = page["url"].toString();
      final String pageImageUrl = URLS.buildMangaPageUrl(
        pictureUrlHead,
        pagePath,
        preferenceImageQuality(),
      );
      pageUrls.add({
        "url": URLS.addHttp(pageImageUrl),
        "headers": this.headers,
      });
    }
    return pageUrls;
  }

  @override
  List<dynamic> getFilterList() {
    return [
      GroupFilter("GenreFilter", "Genre", [
        TriStateFilter("4 Koma", "4 Koma"),
        TriStateFilter("Action", "Action"),
        TriStateFilter("Adult", "Adult"),
        TriStateFilter("Adventure", "Adventure"),
        TriStateFilter("Cars", "Cars"),
        TriStateFilter("Comedy", "Comedy"),
        TriStateFilter("Cooking", "Cooking"),
        TriStateFilter("Crossdressing", "Crossdressing"),
        TriStateFilter("Dementia", "Dementia"),
        TriStateFilter("Demons", "Demons"),
        TriStateFilter("Doujinshi", "Doujinshi"),
        TriStateFilter("Drama", "Drama"),
        TriStateFilter("Ecchi", "Ecchi"),
        TriStateFilter("Fantasy", "Fantasy"),
        TriStateFilter("Game", "Game"),
        TriStateFilter("Gender Bender", "Gender Bender"),
        TriStateFilter("Gyaru", "Gyaru"),
        TriStateFilter("Harem", "Harem"),
        TriStateFilter("Historical", "Historical"),
        TriStateFilter("Horror", "Horror"),
        TriStateFilter("Isekai", "Isekai"),
        TriStateFilter("Josei", "Josei"),
        TriStateFilter("Kids", "Kids"),
        TriStateFilter("Loli", "Loli"),
        TriStateFilter("Magic", "Magic"),
        TriStateFilter("Manhua", "Manhua"),
        TriStateFilter("Manhwa", "Manhwa"),
        TriStateFilter("Martial Arts", "Martial Arts"),
        TriStateFilter("Mature", "Mature"),
        TriStateFilter("Mecha", "Mecha"),
        TriStateFilter("Medical", "Medical"),
        TriStateFilter("Military", "Military"),
        TriStateFilter("Monster Girls", "Monster Girls"),
        TriStateFilter("Music", "Music"),
        TriStateFilter("Mystery", "Mystery"),
        TriStateFilter("One Shot", "One Shot"),
        TriStateFilter("Parody", "Parody"),
        TriStateFilter("Police", "Police"),
        TriStateFilter("Post Apocalyptic", "Post Apocalyptic"),
        TriStateFilter("Psychological", "Psychological"),
        TriStateFilter("Reincarnation", "Reincarnation"),
        TriStateFilter("Reverse Harem", "Reverse Harem"),
        TriStateFilter("Romance", "Romance"),
        TriStateFilter("Samurai", "Samurai"),
        TriStateFilter("School", "School"),
        TriStateFilter("Sci-Fi", "Sci-Fi"),
        TriStateFilter("Seinen", "Seinen"),
        TriStateFilter("Shota", "Shota"),
        TriStateFilter("Shoujo", "Shoujo"),
        TriStateFilter("Shoujo Ai", "Shoujo Ai"),
        TriStateFilter("Shounen", "Shounen"),
        TriStateFilter("Shounen Ai", "Shounen Ai"),
        TriStateFilter("Slice of Life", "Slice of Life"),
        TriStateFilter("Smut", "Smut"),
        TriStateFilter("Space", "Space"),
        TriStateFilter("Sports", "Sports"),
        TriStateFilter("Super Power", "Super Power"),
        TriStateFilter("Supernatural", "Supernatural"),
        TriStateFilter("Suspense", "Suspense"),
        TriStateFilter("Thriller", "Thriller"),
        TriStateFilter("Tragedy", "Tragedy"),
        TriStateFilter("Unknown", "Unknown"),
        TriStateFilter("Vampire", "Vampire"),
        TriStateFilter("Webtoons", "Webtoons"),
        TriStateFilter("Yaoi", "Yaoi"),
        TriStateFilter("Youkai", "Youkai"),
        TriStateFilter("Yuri", "Yuri"),
        TriStateFilter("Zombies", "Zombies"),
      ]),
      SelectFilter("CountryFilter", "Country", 0, [
        SelectFilterOption("ALL", "ALL"),
        SelectFilterOption("Japan", "JP"),
        SelectFilterOption("China", "CN"),
        SelectFilterOption("Korea", "KR"),
      ]),
      SelectFilter("SortFilter", "Sort by", 0, [
        SelectFilterOption("Recently Added", ""),
        SelectFilterOption("Name A-Z", "Name_ASC"),
        SelectFilterOption("Name Z-A", "Name_DESC"),
      ]),
    ];
  }

  @override
  List<dynamic> getSourcePreferences() {
    return [
      EditTextPreference(
        key: "USERAGENT",
        title: "User Agent",
        summary: "Set a custom user agent for requests",
        value: "",
        dialogTitle: "User Agent",
        dialogMessage: """One liner user agent string,
e.g.
Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/37.0.2062.94 Chrome/37.0.2062.94 Safari/537.36

you can get user agent strings from:
  https://gist.githubusercontent.com/pzb/b4b6f57144aea7827ae4/raw/cf847b76a142955b1410c8bcef3aabe221a63db1/user-agents.txt

Enter your custom user agent string below:""",
        text: "",
      ),
      ListPreference(
        key: "IMAGEQUALITY",
        title: "Image Quality",
        summary: "Set the image quality for manga pages",
        valueIndex: 0,
        entries: ["Original", "Wp=800", "Wp=480"],
        entryValues: ["original", "800", "480"],
      ),
    ];
  }

  String preferenceUserAgent() {
    final String? userAgent = getPreferenceValue(
      source.id ?? 0,
      "USERAGENT",
    )?.trim();
    return (userAgent == null || userAgent.isEmpty)
        ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"
        : userAgent;
  }

  String preferenceImageQuality() {
    return getPreferenceValue(source.id ?? 0, "IMAGEQUALITY");
  }
}

AllManga main(MSource source) {
  return AllManga(source: source);
}

