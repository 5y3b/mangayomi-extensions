import 'package:mangayomi/bridge_lib.dart';
import 'dart:convert';

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
                pictureUrls
                pictureUrlHead
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
  static const String BASE_URL = 'https://allmanga.to';
  static const String API_URL = 'https://api.allanime.day/api';

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
  @override
  bool get supportsLatest => true;

  @override
  Map<String, String> get headers => {
    "Accept": "*/*",
    "referer": "${URLS.BASE_URL}/",
    "user-agent": preferenceUserAgent(),
  };

  Map<String, String> get postHeaders => {
    "Accept": "*/*",
    "referer": "${URLS.BASE_URL}/",
    "user-agent": preferenceUserAgent(),
    "content-type": "application/json",
  };

  @override
  Future<MPages> getPopular(int page) async {
    List<MManga> mangaList = [];
    final res = await client.post(
      Uri.parse(URLS.API_URL),
      headers: this.postHeaders,
      body: jsonEncode(Queries.buildPopularMangaQuery(page: page)),
    );
    final items = jsonDecode(
      res.body,
    )?["data"]?["queryPopular"]?["recommendations"];
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
    final res = await client.post(
      Uri.parse(URLS.API_URL),
      headers: this.postHeaders,
      body: jsonEncode(Queries.buildSearchQuery(page: page)),
    );
    final items = jsonDecode(res.body)?["data"]?["mangas"]?["edges"];
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
    final res = await client.post(
      Uri.parse(URLS.API_URL),
      headers: this.postHeaders,
      body: jsonEncode(
        Queries.buildSearchQuery(
          page: page,
          query: query.trim().isEmpty ? null : query.trim(),
          genres: includeGenres,
          excludeGenres: excludeGenres,
          countryOrigin: FilterGet.getSelectedCountry(filterList),
          sortedBy: FilterGet.getSelectedSort(filterList),
        ),
      ),
    );
    final items = jsonDecode(res.body)?["data"]?["mangas"]?["edges"];
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
    final resDetail = await client.post(
      Uri.parse(URLS.API_URL),
      headers: this.postHeaders,
      body: jsonEncode(Queries.buildDetailsQuery(mangaId)),
    );
    final detailsData = jsonDecode(resDetail.body)?["data"]?["manga"];
    if (detailsData == null) throw Exception("Manga details not found");
    // Chapters
    final resChapters = await client.post(
      Uri.parse(URLS.API_URL),
      headers: this.postHeaders,
      body: jsonEncode(Queries.buildChaptersQuery(id: mangaId)),
    );
    final chaptersData = jsonDecode(resChapters.body)?["data"]?["episodeInfos"];
    if (chaptersData == null || chaptersData is! List)
      throw Exception("Chapters not found");
    chaptersData.sort((b, a) => a["episodeIdNum"].compareTo(b["episodeIdNum"]));
    List<MChapter> chapters = [];
    for (var cur in chaptersData) {
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
      author: MangaUtils.getAuthor(detailsData),
      artist: MangaUtils.getAuthor(detailsData),
      genre: MangaUtils.combineGenres(
        detailsData["genres"] ?? [],
        detailsData["tags"] ?? [],
      ),
      imageUrl: URLS.buildMangaCoverUrl(detailsData["thumbnail"] ?? ""),
      link: URLS.buildMangaURL(mangaId),
      name: MangaUtils.getMangaName(detailsData),
      status: MangaUtils.getStatus(detailsData['status']),
      description: MangaUtils.buildDescription(
        detailsData["description"] ?? "",
        detailsData["altNames"] ?? "",
      ),
      chapters: chapters,
    );
  }

  // For manga chapter pages
  @override
  Future<List<dynamic>> getPageList(String url) async {
    final split = url.split("/");
    if (split.length < 3) return [];
    final String mangaId = split[split.length - 2];
    final chapter = split.last.split("-");
    final chapterNum = chapter[1];
    final chapterType = chapter.last;
    final res = await client.post(
      Uri.parse(URLS.API_URL),
      headers: this.postHeaders,
      body: jsonEncode(
        Queries.buildPageQuery(
          id: mangaId,
          chapterNum: chapterNum,
          translationType: chapterType == "sub" ? "sub" : "dub",
        ),
      ),
    );
    final json = jsonDecode(res.body);
    final pagesData = json["data"]["chapterPages"]["edges"]?.first;
    String pictureUrlHead = pagesData["pictureUrlHead"].toString();
    List<dynamic> pageUrls = [];
    for (var page in pagesData["pictureUrls"]) {
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
    // TODO
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
