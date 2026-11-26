import 'dart:convert';

import 'package:mangayomi/bridge_lib.dart';

/// Comix (https://comix.to) — v1 API bridge.
///
/// Requests to /api/v1 carry a signed `_` query token, and chapter responses
/// are encrypted. Both use the site's embedded key, reproduced below.
const String _comixKeyCsv =
    "127,140,6,85,9,254,151,181,154,190,31,173,228,86,101,102,75,122,201,82,243,230,151,251,200,145,232,161,89,49,140,132,60,177,16,115,229,225,173,158,138,189,39,63,184,234,51,17,229,120,64,77,114,205,126,111,56,141,65,26,100,226,7,218,153,75,135,54,159,233,62,206,127,19,223,79,82,232,169,40,19,23,72,143,200,254,30,103,188,227,85,78,241,70,75,165,128,48,95,68,56,2,180,159,251,250,20,7,193,212,224,149,183,65,127,129,150,200,82,224,212,40,171,116,205,206,76,67,83,170,21,5,92,172,121,156,133,44,159,167,21,47,110,66,83,97,191,63,54,227,17,172,250,207,106,128,222,102,36,156,110,241,254,251,45,84,91,161,21,158,83,81,103,9,131,236,182,13,53,210,90,224,86,137,187,218,57,4,94,162,44,184,241,242,40,61,63,71,105,186,244,6,255,177,94,86,199,33,109,169,81,218,2,165,175,158,153,109,182,69,140,232,82,119,147,9,62,127,197,115,114,65,182,100,189,76,153,233,34,73,165,255,41,127,244,58,166,149,11,164,5,87,198,152,142,83,85,167,94,92,130,5,100,225,224,16,74,16,123,107,142,9,22,228,160,96,84,73,157,66,91,126,176,113,197,48,202,179,189,205,123,200,31,106,99,41,127,49,254,232,189,115,57,142,255,135,27,135,213,195,37,119,137,62,200,38,3,49,187,32,247,65,218,26,208,1,219,222,184,131,88,68,177,245,228,198,95,145,123,12,12,137,46,201,40,68,108,232,142,112,20,52,204,169,22,86,205,75,245,36,231,132,206,120,239,14,236,235,124,46,125,16,233,162,252,136,191,114,185,114,186,101,231,108,36,11,41,118,180,233,121,19,160,122,163,41,209,244,145,220,161,132,108,93,86,117,38,38,157,17,109,35,15,231,82,249,58,201,73,37,75,71,173,129,163,152,156,46,108,164,23,205,174,219,213,204,249,9,148,50,115,122,116,53,167,25,216,195,142,86,209,193,180,199,107,211,167,8,30,151,228,164,235,186,154,206,209,166,47,132,233,119,203,230,142,243,147,168,212,255,31,13,241,218,187,215,128,19,142,157,32,95,77,133,104,137,196,139,123,201,64,169,192,246,195,59,147,202,51,112,248,160,185,237,94,98,11,28,168,76,72,223,203,39,253,223,165,110,229,139,143,195,99,155,192,126,10,169,84,176,37,156,231,113,84,172,186,124,40,0,255,100,240,209,214,17,99,225,60,14,190,134,21,71,251,186,62,224,184,48,34,30,126,86,6,134,171,70,7,126,152,64,122,212,208,232,187,103,84,206,219,137,187,219,1,246,252,223,24,131,233,33,121,46,92,217,167,240,158,94,215,155,78,45,171,64,160,91,51,175,220,145,16,241,75,2,223,10,101,95,96,22,162,230,116,212,206,13,81,101,151,209,12,51,252,91,18,243,114,44,30,25,33,228,75,18,70,152,103,44,85,65,113,235,205,163,152,197,58,200,154,25,251,116,78,147,30,249,47,72,5,202,115,163,156,238,135,159,89,12,142,132,100,114,231,197,31,216,84,9,86,247,36,111,128,19,176,231,37,43,55,93,178,27,149,66,70,100,177,69,191,233,85,47,35,184,165,48,46,232,120,20,91,112,57,89,227,3,95,163,109,30,231,84,180,61,7,139,20,127,217,95,192,214,5,142,101,176,72,65,245,148,28,253,39,75,33,75,125,191,117,205,226,58,95,244,67,57,232,156,150,118,61,12,253,83,78,248,137,60,5,134,246,86,240,42,225,200,243,191,103,86,189,41,191,49,51,182,232,64,221,105,168,68,9,228,100,1,222,196,139,191,212,225,122,230,178,52,86,194,70,45,85,36,37,130,24,105,251,243,193,153,156,72,23,159,237,20,61,216,184,156,85,217,244,75,253,236,80,182,157,216,224,38,29,133,88,5,201,141,31,45,15,229,242,191,55,28,17,113,187,52,181,230,235,169,204,208,153,94,119,151,20,178,90,119,24,85,14,80,206,210,3,107,76,110,26,16,245,32,210,206,216,216,205,69,243,161,151,20,243,195,110,88,134,90,58,173,210,152,122,161,169,107,109,60,151,21,134,99,108,193,175,185,26,119,211,56,187,197,63,134,192,151,33,109,96,81,93,250,146,125,213,239,28,111,147,48,175,49,37,188,155,125,50,83,197,100,186,105,115,8,48,151,86,156,241,117,211,131,224,149,8,204,253,154,234,243,131,175,193,90,156,177,138,227,179,206,75,227,94,201,144,253,200,183,181,25,164,248,3,219,63,140,195,164,13,155,219,231,189,136,249,137,184,179,189,29,222,69,166,18,183,190,10,217,232,143,85,180,4,59,231,253,210,64,118,215,124,146,238,67,147,185,178,36,97,190,72,102,53,217,105,2,108,181,21,223,225,234,93,173,202,96,24,107,47,220";

const String _b64Alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

const List<int> _shaK = [
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

List<int> _comixKey() {
  return _comixKeyCsv.split(",").map((s) => int.parse(s)).toList();
}

int _rotr(int x, int n) => (x >> n) | ((x << (32 - n)) & 0xffffffff);

/// SHA-256 with a caller supplied initial state. The site's helper adds 64 to
/// the message length before padding, which is reproduced here.
List<int> _comixSha(List<int> iv, List<int> data) {
  final h = <int>[];
  for (var i = 0; i < 8; i++) {
    h.add(iv[i]);
  }
  final length = (data.length + 64) * 8;
  final msg = <int>[];
  msg.addAll(data);
  msg.add(0x80);
  while (msg.length % 64 != 56) {
    msg.add(0);
  }
  for (var i = 7; i >= 0; i--) {
    msg.add((length >> (8 * i)) & 255);
  }
  for (var off = 0; off < msg.length; off += 64) {
    final w = <int>[];
    for (var i = 0; i < 16; i++) {
      final j = off + 4 * i;
      w.add((msg[j] << 24) | (msg[j + 1] << 16) | (msg[j + 2] << 8) | msg[j + 3]);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w.add((w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff);
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ (~e & g);
      final t1 = (hh + s1 + ch + _shaK[i] + w[i]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      hh = g;
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
    h[7] = (h[7] + hh) & 0xffffffff;
  }
  final out = <int>[];
  for (var word in h) {
    out.add((word >> 24) & 255);
    out.add((word >> 16) & 255);
    out.add((word >> 8) & 255);
    out.add(word & 255);
  }
  return out;
}

List<int> _keyWords(List<int> key, int offset) {
  final out = <int>[];
  for (var i = 0; i < 8; i++) {
    final j = offset + 4 * i;
    out.add((key[j] << 24) | (key[j + 1] << 16) | (key[j + 2] << 8) | key[j + 3]);
  }
  return out;
}

String _b64Encode(List<int> bytes) {
  final out = StringBuffer();
  for (var i = 0; i < bytes.length; i += 3) {
    final a = bytes[i];
    final b = i + 1 < bytes.length ? bytes[i + 1] : 0;
    final c = i + 2 < bytes.length ? bytes[i + 2] : 0;
    out.write(_b64Alphabet[a >> 2]);
    out.write(_b64Alphabet[((a & 3) << 4) | (b >> 4)]);
    if (i + 1 < bytes.length) {
      out.write(_b64Alphabet[((b & 15) << 2) | (c >> 6)]);
    }
    if (i + 2 < bytes.length) {
      out.write(_b64Alphabet[c & 63]);
    }
  }
  return out.toString();
}

int _b64Index(String ch) {
  // d4rt's String.indexOf does not resolve '+' or '/' reliably.
  if (ch == "+" || ch == "-") return 62;
  if (ch == "/" || ch == "_") return 63;
  return _b64Alphabet.indexOf(ch);
}

List<int> _b64Decode(String text) {
  final out = <int>[];
  var acc = 0;
  var bits = 0;
  for (var i = 0; i < text.length; i++) {
    final index = _b64Index(text[i]);
    if (index < 0) continue;
    acc = ((acc << 6) | index) & 0xffffff;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.add((acc >> bits) & 255);
    }
  }
  return out;
}

String _comixToken(String canonical) {
  final key = _comixKey();
  final inner = _comixSha(_keyWords(key, 0), utf8.encode(canonical));
  final outer = _comixSha(_keyWords(key, 32), inner);
  return "p5s." + _b64Encode(outer).substring(0, 16);
}

class Comix extends MProvider {
  Comix({required this.source}) {
    client = Client(source);
  }

  MSource source;
  late final Client client;

  static const List<String> nsfwGenreIds = [
    "87264", "87265", "87266", "87268",
  ];

  @override
  bool get supportsLatest => true;

  String get baseUrl => source.baseUrl ?? "https://comix.to";

  String get apiUrl {
    final url = source.apiUrl ?? "";
    // Only trust the source's API URL when it actually points at Comix. The
    // runtime can hand the provider an MSource from a different catalogue.
    if (!url.contains("comix.to") || !url.contains("/api/")) {
      return "https://comix.to/api/v1/";
    }
    return url.endsWith("/") ? url : "$url/";
  }

  @override
  Map<String, String> get headers => {
    "Referer": "$baseUrl/",
    "Accept": "application/json",
    "X-Requested-With": "XMLHttpRequest",
  };

  bool get hideNsfw =>
      getPrefStringValue(source.id ?? 0, "nsfw_pref", "show") == "hide";

  // ── v1 request helpers ────────────────────────────────────────────────────

  /// Canonical query string used for the signed token. Keys are sorted and
  /// list values are indexed, e.g. `genres[0]=6`.
  String _canonical(String path, Map params) {
    final keys = params.keys.toList();
    keys.sort();
    final parts = <String>[];
    for (final key in keys) {
      final value = params[key];
      if (value == null) continue;
      final values = value is List ? value : [value];
      for (var i = 0; i < values.length; i++) {
        final name = value is List ? "$key[$i]" : key;
        parts.add("$name=${values[i]}");
      }
    }
    final base = path.startsWith("/") ? path : "/$path";
    return parts.isEmpty ? base : "$base?${parts.join("&")}";
  }

  String _requestUrl(String path, [Map params = const {}]) {
    final parts = <String>[];
    params.forEach((key, value) {
      if (value == null) return;
      final values = value is List ? value : [value];
      for (final item in values) {
        if (item == null) continue;
        final name = value is List ? "$key[]" : key;
        parts.add(
          "${Uri.encodeComponent(name)}=${Uri.encodeComponent(item.toString())}",
        );
      }
    });
    final query = parts.join("&");
    final token = _comixToken(_canonical(path, params));
    final base = apiUrl.endsWith("/") ? apiUrl : "$apiUrl/";
    final cleanPath = path.startsWith("/") ? path.substring(1) : path;
    return "$base$cleanPath?$query&_=$token";
  }

  Future<Map> fetchJson(
    String path, [
    Map params = const {},
  ]) async {
    final response = await client.get(
      Uri.parse(_requestUrl(path, params)),
      headers: headers,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception("Invalid API response");
    }
    if (decoded["e"] is String) {
      return _decrypt(decoded["e"] as String);
    }
    return decoded;
  }

  Map _decrypt(String encrypted) {
    final bytes = _b64Decode(encrypted);
    if (bytes.length < 4) {
      throw Exception("Invalid encrypted response");
    }
    // The two-byte header carries the keystream seed. The site's key schedule
    // is the full embedded key rotated by (seed + 62); every byte (including
    // the header) is XORed with it, and the JSON body starts at the first '{'.
    final seed = ((bytes[0] << 8) | bytes[1]) % 1024;
    final key = _comixKey();
    // The 1024-byte keystream window is key[64..1088]; it rotates by seed-2
    // and wraps inside that window (not over the whole 1088-byte key).
    final rotation = (seed + 1022) % 1024;
    final out = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      out.add(bytes[i] ^ key[64 + ((rotation + i) % 1024)]);
    }
    var start = 0;
    while (start < out.length && out[start] != 0x7b) {
      start++;
    }
    final text = String.fromCharCodes(out.sublist(start));
    return jsonDecode(text) as Map;
  }

  MStatus statusCode(String? status) {
    switch (status) {
      case "releasing":
        return MStatus.ongoing;
      case "finished":
      case "completed":
        return MStatus.completed;
      case "on_hiatus":
        return MStatus.onHiatus;
      case "discontinued":
      case "canceled":
        return MStatus.canceled;
      default:
        return MStatus.unknown;
    }
  }

  String? posterUrl(dynamic poster) {
    if (poster == null) return null;
    if (poster is String) return poster;
    if (poster is! Map) return null;
    final url = poster["large"] ?? poster["medium"] ?? poster["small"];
    return url?.toString();
  }

  String fancyScore(dynamic ratedAvg) {
    final raw = ratedAvg is num
        ? ratedAvg.toDouble()
        : double.tryParse(ratedAvg?.toString() ?? "");
    if (raw == null || raw == 0) return "";
    var stars = (raw / 2 + 0.5).toInt();
    if (stars > 5) stars = 5;
    if (stars < 0) stars = 0;
    final filled = StringBuffer();
    final empty = StringBuffer();
    for (var i = 0; i < stars; i++) {
      filled.write("★");
    }
    for (var i = stars; i < 5; i++) {
      empty.write("☆");
    }
    return "$filled$empty $raw";
  }

  MManga mangaFromItem(Map item) {
    final manga = MManga();
    manga.name = item["title"]?.toString();
    manga.imageUrl = posterUrl(item["poster"]);
    manga.link = "/${item["hid"] ?? item["hash_id"] ?? ""}";
    return manga;
  }

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "") ?? fallback;
  }

  List<String> _checkedValues(dynamic state) {
    final values = <String>[];
    if (state is! List) return values;
    for (final filter in state) {
      if (filter is CheckBoxFilter && filter.state) {
        values.add(filter.value);
      }
    }
    return values;
  }

  // ── Popular / latest ──────────────────────────────────────────────────────

  @override
  Future<MPages> getPopular(int page) {
    return _searchWithSort("order[views_30d]", page);
  }

  @override
  Future<MPages> getLatestUpdates(int page) {
    return _searchWithSort("order[chapter_updated_at]", page);
  }

  Future<MPages> _searchWithSort(String sortParam, int page) async {
    final params = <String, dynamic>{
      sortParam: "desc",
      "limit": 50,
      "page": page,
      "content_rating": ["safe", "suggestive"],
    };
    if (hideNsfw) params["exclude_genres[]"] = nsfwGenreIds;
    return _search(params);
  }

  // ── Search ────────────────────────────────────────────────────────────────

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    final params = <String, dynamic>{
      "limit": 50,
      "page": page,
      "content_rating": ["safe", "suggestive"],
    };
    var sortParam = "order[views_30d]";
    var sortValue = "desc";

    if (hideNsfw) params["exclude_genres[]"] = nsfwGenreIds;

    for (final filter in filterList.filters) {
      switch (filter.type) {
        case "SortFilter":
          final state = filter.state as int;
          final values = filter.values;
          if (state >= 0 && state < values.length) {
            final parts = values[state].value.split("|");
            if (parts.length == 2) {
              sortParam = parts[0];
              sortValue = parts[1];
            }
          }
          break;

        case "StatusFilter":
          final statuses = _checkedValues(filter.state);
          if (statuses.isNotEmpty) params["statuses[]"] = statuses;
          break;

        case "TypeFilter":
          final types = _checkedValues(filter.state);
          if (types.isNotEmpty) params["types[]"] = types;
          break;

        case "GenresFilter":
          final included = <String>[];
          final excluded = <String>[];
          for (final f in filter.state as List) {
            if (f is! TriStateFilter) continue;
            if (f.state == 1) included.add(f.value);
            if (f.state == 2) excluded.add(f.value);
          }
          if (included.isNotEmpty) params["genres[]"] = included;
          if (excluded.isNotEmpty) params["exclude_genres[]"] = excluded;
          break;

        case "DemographicFilter":
          final included = <String>[];
          final excluded = <String>[];
          for (final f in filter.state as List) {
            if (f is! TriStateFilter) continue;
            if (f.state == 1) included.add(f.value);
            if (f.state == 2) excluded.add(f.value);
          }
          if (included.isNotEmpty) params["demographics[]"] = included;
          if (excluded.isNotEmpty) params["exclude_demographics[]"] = excluded;
          break;

        case "MinChaptersFilter":
          final state = filter.state.toString();
          if (state.isNotEmpty) params["count[from]"] = state;
          break;

        case "YearFromFilter":
          final values = filter.values;
          final state = filter.state as int;
          if (state >= 0 && state < values.length) {
            final value = values[state].value;
            if (value.isNotEmpty) params["release_year[from]"] = value;
          }
          break;

        case "YearToFilter":
          final values = filter.values;
          final state = filter.state as int;
          if (state >= 0 && state < values.length) {
            final value = values[state].value;
            if (value.isNotEmpty) params["release_year[to]"] = value;
          }
          break;
      }
    }

    if (query.trim().isNotEmpty) {
      params["keyword"] = query.trim();
      sortParam = "order[relevance]";
      sortValue = "desc";
    }
    params[sortParam] = sortValue;
    return _search(params);
  }

  Future<MPages> _search(Map params) async {
    final data = await fetchJson("manga", params);
    final result = data["result"];
    if (result is! Map) return MPages(<MManga>[], false);
    final items = <Map>[];
    final rawItems = result["items"];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) items.add(item);
      }
    }
    var hasNext = false;
    final meta = result["meta"];
    if (meta is Map) {
      if (meta["hasNext"] is bool) {
        hasNext = meta["hasNext"] as bool;
      } else {
        hasNext = _asInt(meta["page"], 1) < _asInt(meta["lastPage"], 1);
      }
    }
    final mangaList = <MManga>[];
    for (final item in items) {
      mangaList.add(mangaFromItem(item));
    }
    return MPages(mangaList, hasNext);
  }

  // ── Details ───────────────────────────────────────────────────────────────

  @override
  Future<MManga> getDetail(String url) async {
    final hashId = url.replaceAll(RegExp(r"^/+"), "").split("/")[0];
    final data = await fetchJson("manga/$hashId", {
      "includes[]": [
        "demographic", "genre", "theme", "author", "artist", "publisher",
      ],
    });
    final manga = data["result"];
    if (manga is! Map) {
      throw Exception("Manga not found");
    }

    final buffer = StringBuffer();
    final score = fancyScore(manga["ratedAvg"] ?? manga["rated_avg"]);
    if (score.isNotEmpty) buffer.write("$score\n\n");
    if (manga["synopsis"] != null) buffer.write(manga["synopsis"]);

    final genres = <String>[];
    final type = manga["type"];
    if (type == "manhwa") genres.add("Manhwa");
    if (type == "manhua") genres.add("Manhua");
    if (type == "manga") genres.add("Manga");
    if (type != null && type != "manhwa" && type != "manhua" && type != "manga") {
      genres.add("Other");
    }
    for (final key in ["genre", "theme", "demographic"]) {
      final tags = manga[key];
      if (tags is! List) continue;
      for (final tag in tags) {
        if (tag is Map && tag["title"] != null) {
          genres.add(tag["title"].toString());
        }
      }
    }
    if (manga["isNsfw"] == true || manga["is_nsfw"] == true) {
      genres.add("NSFW");
    }

    String joinTitles(String key) {
      final people = manga[key];
      final titles = <String>[];
      if (people is List) {
        for (final person in people) {
          if (person is Map && person["title"] != null) {
            titles.add(person["title"].toString());
          }
        }
      }
      return titles.join(", ");
    }

    final result = MManga()
      ..name = manga["title"]?.toString()
      ..description = buffer.toString()
      ..imageUrl = posterUrl(manga["poster"])
      ..author = joinTitles("author")
      ..artist = joinTitles("artist")
      ..genre = genres
      ..status = statusCode((manga["status"] ?? "").toString())
      ..chapters = await _fetchAllChapters(hashId);
    return result;
  }

  bool _isOfficial(Map chapter) =>
      chapter["groupId"] == 9275 ||
      chapter["scanlation_group_id"] == 9275 ||
      chapter["isOfficial"] == true ||
      chapter["is_official"] == true ||
      chapter["is_official"] == 1;

  bool _isBetterChapter(
    Map candidate,
    Map current,
  ) {
    final newOfficial = _isOfficial(candidate);
    final currentOfficial = _isOfficial(current);
    if (newOfficial && !currentOfficial) return true;
    if (!newOfficial && currentOfficial) return false;
    final newVotes = _asInt(candidate["votes"]);
    final currentVotes = _asInt(current["votes"]);
    if (newVotes != currentVotes) return newVotes > currentVotes;
    return _asInt(candidate["updatedAt"] ?? candidate["updated_at"]) >
        _asInt(current["updatedAt"] ?? current["updated_at"]);
  }

  MChapter _chapterFromItem(Map chapter, String hashId) {
    final number = (chapter["number"] ?? "").toString().replaceFirst(
      RegExp(r"\.0$"),
      "",
    );
    var name = "Chapter $number";
    final chapterName = chapter["name"]?.toString().trim() ?? "";
    if (chapterName.isNotEmpty) name += ": $chapterName";

    var scanlator = "Unknown";
    final group =
        chapter["group"] ?? chapter["scanlationGroup"] ?? chapter["scanlation_group"];
    if (group is Map && group["name"] != null) {
      scanlator = group["name"].toString();
    } else if (_isOfficial(chapter)) {
      scanlator = "Official";
    }

    final updated = _asInt(chapter["updatedAt"] ?? chapter["updated_at"]);
    return MChapter()
      ..name = name
      ..url = "title/$hashId/${chapter["id"] ?? chapter["chapter_id"]}"
      ..dateUpload = (updated * 1000).toString()
      ..scanlator = scanlator;
  }

  Future<List<MChapter>> _fetchAllChapters(String hashId) async {
    final seen = <dynamic, Map>{};
    var page = 1;
    var hasMore = true;

    while (hasMore) {
      final data = await fetchJson("manga/$hashId/chapters", {
        "order[number]": "desc",
        "limit": 100,
        "page": page,
      });
      final result = data["result"];
      if (result is! Map) break;
      final rawItems = result["items"];
      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is! Map) continue;
          final number = item["number"];
          final current = seen[number];
          if (current == null || _isBetterChapter(item, current)) {
            seen[number] = item;
          }
        }
      }
      final meta = result["meta"];
      if (meta is Map) {
        if (meta["hasNext"] is bool) {
          hasMore = meta["hasNext"] as bool;
        } else {
          hasMore = _asInt(meta["page"], 1) < _asInt(meta["lastPage"], 1);
        }
      } else {
        hasMore = false;
      }
      page++;
    }

    final chapters = <MChapter>[];
    for (final chapter in seen.values) {
      chapters.add(_chapterFromItem(chapter, hashId));
    }
    return chapters;
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<Map>> getPageList(String url) async {
    final chapterId = url.split("/").last;
    final data = await fetchJson("chapters/$chapterId");
    final result = data["result"];
    if (result is! Map) {
      throw Exception("Chapter not found");
    }
    final pagesObj = result["pages"];
    final images = pagesObj is Map
        ? pagesObj["items"]
        : result["images"];
    final pages = <Map>[];
    if (images is List) {
      for (final image in images) {
        if (image is! Map || image["url"] == null) continue;
        pages.add(<String, dynamic>{
          "url": image["url"].toString(),
          "headers": {"Referer": "$baseUrl/"},
        });
      }
    }
    if (pages.isEmpty) {
      throw Exception("No images found for chapter $chapterId");
    }
    return pages;
  }

  @override
  List<dynamic> getFilterList() {
    final currentYear = DateTime.now().year;
    final years = <SelectFilterOption>[];
    for (var year = currentYear; year >= 1990; year--) {
      years.add(SelectFilterOption("$year", "$year"));
    }
    final yearsWithOlder = <SelectFilterOption>[
      ...years,
      SelectFilterOption("Older", "older"),
    ];

    return [
      SelectFilter("SortFilter", "Sort", 0, [
        SelectFilterOption(
          "Popular (Month)",
          "order[views_30d]|desc",
        ),
        SelectFilterOption("Popular (Week)", "order[views_7d]|desc"),
        SelectFilterOption("Popular (All Time)", "order[views]|desc"),
        SelectFilterOption(
          "Latest Updated",
          "order[chapter_updated_at]|desc",
        ),
        SelectFilterOption("Newest", "order[created_at]|desc"),
        SelectFilterOption("Oldest", "order[created_at]|asc"),
        SelectFilterOption("Title A-Z", "order[title]|asc"),
        SelectFilterOption("Title Z-A", "order[title]|desc"),
        SelectFilterOption("Rating", "order[rated_avg]|desc"),
      ]),
      GroupFilter("StatusFilter", "Status", [
        CheckBoxFilter("Finished", "finished"),
        CheckBoxFilter("Releasing", "releasing"),
        CheckBoxFilter("On Hiatus", "on_hiatus"),
        CheckBoxFilter("Discontinued", "discontinued"),
        CheckBoxFilter("Not Yet Released", "not_yet_released"),
      ]),
      GroupFilter("GenresFilter", "Genres", [
        TriStateFilter("Action", "6"),
        TriStateFilter("Adult", "87264"),
        TriStateFilter("Adventure", "7"),
        TriStateFilter("Boys Love", "8"),
        TriStateFilter("Comedy", "9"),
        TriStateFilter("Crime", "10"),
        TriStateFilter("Drama", "11"),
        TriStateFilter("Ecchi", "87265"),
        TriStateFilter("Fantasy", "12"),
        TriStateFilter("Girls Love", "13"),
        TriStateFilter("Hentai", "87266"),
        TriStateFilter("Historical", "14"),
        TriStateFilter("Horror", "15"),
        TriStateFilter("Isekai", "16"),
        TriStateFilter("Magical Girls", "17"),
        TriStateFilter("Mature", "87267"),
        TriStateFilter("Mecha", "18"),
        TriStateFilter("Medical", "19"),
        TriStateFilter("Mystery", "20"),
        TriStateFilter("Philosophical", "21"),
        TriStateFilter("Psychological", "22"),
        TriStateFilter("Romance", "23"),
        TriStateFilter("Sci-Fi", "24"),
        TriStateFilter("Slice of Life", "25"),
        TriStateFilter("Smut", "87268"),
        TriStateFilter("Sports", "26"),
        TriStateFilter("Superhero", "27"),
        TriStateFilter("Thriller", "28"),
        TriStateFilter("Tragedy", "29"),
        TriStateFilter("Wuxia", "30"),
        TriStateFilter("Aliens", "31"),
        TriStateFilter("Animals", "32"),
        TriStateFilter("Cooking", "33"),
        TriStateFilter("Cross Dressing", "34"),
        TriStateFilter("Delinquents", "35"),
        TriStateFilter("Demons", "36"),
        TriStateFilter("Genderswap", "37"),
        TriStateFilter("Ghosts", "38"),
        TriStateFilter("Gyaru", "39"),
        TriStateFilter("Harem", "40"),
        TriStateFilter("Incest", "41"),
        TriStateFilter("Loli", "42"),
        TriStateFilter("Mafia", "43"),
        TriStateFilter("Magic", "44"),
        TriStateFilter("Martial Arts", "45"),
        TriStateFilter("Military", "46"),
        TriStateFilter("Monster Girls", "47"),
        TriStateFilter("Monsters", "48"),
        TriStateFilter("Music", "49"),
        TriStateFilter("Ninja", "50"),
        TriStateFilter("Office Workers", "51"),
        TriStateFilter("Police", "52"),
        TriStateFilter("Post-Apocalyptic", "53"),
        TriStateFilter("Reincarnation", "54"),
        TriStateFilter("Reverse Harem", "55"),
        TriStateFilter("Samurai", "56"),
        TriStateFilter("School Life", "57"),
        TriStateFilter("Shota", "58"),
        TriStateFilter("Supernatural", "59"),
        TriStateFilter("Survival", "60"),
        TriStateFilter("Time Travel", "61"),
        TriStateFilter("Traditional Games", "62"),
        TriStateFilter("Vampires", "63"),
        TriStateFilter("Video Games", "64"),
        TriStateFilter("Villainess", "65"),
        TriStateFilter("Virtual Reality", "66"),
        TriStateFilter("Zombies", "67"),
      ]),
      GroupFilter("TypeFilter", "Type", [
        CheckBoxFilter("Manga", "manga"),
        CheckBoxFilter("Manhwa", "manhwa"),
        CheckBoxFilter("Manhua", "manhua"),
        CheckBoxFilter("Other", "other"),
      ]),
      GroupFilter("DemographicFilter", "Demographic", [
        TriStateFilter("Shoujo", "1"),
        TriStateFilter("Shounen", "2"),
        TriStateFilter("Josei", "3"),
        TriStateFilter("Seinen", "4"),
      ]),
      TextFilter("MinChaptersFilter", "Min Chapters", state: ""),
      SelectFilter(
        "YearFromFilter",
        "Year From",
        yearsWithOlder.length - 1,
        yearsWithOlder,
      ),
      SelectFilter("YearToFilter", "Year To", 0, years),
    ];
  }

  @override
  List<dynamic> getSourcePreferences() {
    return [
      ListPreference(
        key: "nsfw_pref",
        title: "Hide NSFW content",
        summary: "Hides NSFW content from popular, latest, and search results",
        valueIndex: 0,
        entries: ["Show all", "Hide NSFW"],
        entryValues: ["show", "hide"],
      ),
    ];
  }
}

Comix main(MSource source) {
  return Comix(source: source);
}
