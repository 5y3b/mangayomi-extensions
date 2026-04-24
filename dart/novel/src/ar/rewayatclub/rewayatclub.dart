import 'package:mangayomi/bridge_lib.dart';
import 'dart:convert';

class Utils {
  static String getName(Map<String, dynamic> manga, [bool isAr = true]) {
    if (isAr) {
      return manga["arabic"] ?? manga["english"] ?? "لا عنوان";
    } else {
      return manga["english"] ?? manga["arabic"] ?? "No Title";
    }
  }
}

class RewayatClubSource extends MProvider {
  RewayatClubSource({required this.source});

  MSource source;

  final Client client = Client();

  @override
  bool get supportsLatest => true;

  @override
  Map<String, String> get headers => {
    "user-agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36",
    "referer": "$baseUrl",
  };

  @override
  String? get baseUrl => "https://rewayat.club";

  String addOption(String url, String key, String value) {
    if (value.isEmpty) return "";
    if (url.endsWith("?"))
      return "$key=$value";
    else
      return "&$key=$value";
  }

  Future<MPages> _getFilter(
    int page, [
    List<dynamic>? filters,
    String? query,
  ]) async {
    String url = "$baseUrl/api/novels/?";
    url += addOption(url, "page", "$page");
    if (query != null && query.isNotEmpty) {
      url += addOption(url, "search", query);
    }
    for (final filter in filters ?? []) {
      // if (filter.type == "TitleFilter" && filter.state.isNotEmpty)
      //   url += addOption(url, "title", filter.state);
      // filter as SelectFilter;
      // filter as GroupFilter;
      if (filter.type == "GenreFilter" && filter.state.isNotEmpty) {
        for (final s in filter.state) {
          // s as CheckBoxFilter;
          if (s.state) url += addOption(url, "genre", s.value);
        }
      } else if (filter.type == "TypeFilter") {
        url += addOption(url, "type", filter.values[filter.state].value);
      } else if (filter.type == "OrderByFilter") {
        url += addOption(url, "ordering", filter.values[filter.state].value);
      }
    }
    final response = await client.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
        "FAILED TO LOAD URL: $url IN _getFilter, report to discord with this error message",
      );
    }
    Map<String, dynamic> json = jsonDecode(response.body);
    List<Map<String, dynamic>> mangas = json["results"] ?? [];
    List<MManga> mangaList = [];
    for (final manga in mangas) {
      String title = Utils.getName(manga);
      String imgUrl = "${this.baseUrl}/${manga["poster_url"] ?? ""}";
      String mangaUrl = "${this.baseUrl}/novel/${manga["slug"] ?? ""}";
      String about = manga["about"] ?? "";
      String chapters = "${manga["num_chapters"] ?? 0} جابتر";
      List<String> genres = [];
      if (manga["genres"] != null) {
        for (final genre in manga["genres"]) {
          genres.add(genre["arabic"] ?? "");
          genres.add(genre["english"] ?? "");
        }
      }
      String status = manga["complete"] ?? false ? "COMPLETED" : "ONGOING";
      mangaList.add(
        MManga(
          name: title,
          imageUrl: imgUrl,
          link: mangaUrl,
          description: "$chapters\n\n\n$about",
          genre: genres,
          status: parseStatus(status, [
            {"ONGOING": 0, "COMPLETED": 1},
          ]),
        ),
      );
    }
    return MPages(mangaList, json["next"] != null);
  }

  @override
  Future<MPages> getPopular(int page) async {
    return _getFilter(page); // there is no pop or latest :)
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    return _getFilter(page);
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    return _getFilter(page, filterList.filters, query);
  }

  @override
  Future<MManga> getDetail(String url) async {
    final response = await client.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
        "FAILED TO LOAD URL: $url IN GETDETAIL, report to discord with this error message",
      );
    }
    List<MElement> rows =
        parseHtml(response.body).select("table > tbody> tr") ?? [];
    List<MChapter> chapters = [];
    for (MElement row in rows) {
      String chapterTitle = "";
      String chapterUrl = "";
      String date = "";
      List<MElement> cells = row.select("td") ?? [];
      chapterTitle = (cells.length > 0)
          ? cells.first.text?.trim() ?? ""
          : "No Title";
      chapterUrl =
          "$baseUrl${(cells.length > 0) ? cells.first.selectFirst("a")?.attr("href") ?? "" : ""}";
      date = (cells.length > 0)
          ? cells.last.selectFirst("time")?.attr("unixtime") ?? ""
          : "";
      if (date.isNotEmpty) date += "000";
      chapters.insert(
        0,
        MChapter(name: chapterTitle, url: chapterUrl, dateUpload: date),
      );
    }
    return MManga(chapters: chapters);
  }

  // For novel html content
  @override
  Future<String> getHtmlContent(String name, String url) async {
    final response = await client.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
        "FAILED TO LOAD URL: $url IN getHtmlContent, report to discord with this error message",
      );
    }
    MDocument doc = parseHtml(response.body);
    MElement? elm = doc.selectFirst("div.chapter-inner");
    if (elm == null)
      throw Exception(
        "FAILED TO PARSE HTML CONTENT FROM URL: $url IN getHtmlContent, report to discord with this error message",
      );
    return cleanHtmlContent(elm.outerHtml ?? "");
  }

  // Clean html up for reader
  @override
  Future<String> cleanHtmlContent(String html) async {
    // tables arent supported so this is neat way to render them ig :3
    html = html.replaceAll(RegExp(r"<table.*?>"), "<hr><table>");
    html = html.replaceAll(RegExp(r"<tr.*?>"), "<pre><tr>");
    html = html.replaceAll(RegExp(r"</tr>"), "</tr></pre>");
    html = html.replaceAll(
      RegExp(r"<table.*?>|</table>|<tr.*?>|</tr>|<td.*?>|</td>"),
      "",
    );
    return " " + html; // idk for some reason the reader cuts first char
  }

  @override
  List<dynamic> getFilterList() {
    return [
      TextFilter("SearchFilter", "البحث"),
      SeparatorFilter(),
      GroupFilter("GenreFilter", "التصنيف", [
        CheckBoxFilter("كوميديا", "1"),
        CheckBoxFilter("أكشن", "2"),
        CheckBoxFilter("دراما", "3"),
        CheckBoxFilter("فانتازيا", "4"),
        CheckBoxFilter("مهارات القتال", "5"),
        CheckBoxFilter("مغامرة", "6"),
        CheckBoxFilter("رومانسي", "7"),
        CheckBoxFilter("خيال علمي", "8"),
        CheckBoxFilter("الحياة المدرسية", "9"),
        CheckBoxFilter("قوى خارقة", "10"),
        CheckBoxFilter("سحر", "11"),
        CheckBoxFilter("رياضة", "12"),
        CheckBoxFilter("رعب", "13"),
        CheckBoxFilter("حريم", "14"),
      ]),
      SeparatorFilter(),
      SelectFilter("TypeFilter", "النوع", 0, [
        SelectFilterOption("جميع الروايات", "0"),
        SelectFilterOption("مترجمة", "1"),
        SelectFilterOption("مؤلفة", "2"),
        SelectFilterOption("مكتملة", "3"),
      ]),
      SeparatorFilter(),
      SelectFilter("OrderByFilter", "الترتيب حسب", 1, [
        SelectFilterOption("عدد الفصول - من أقل ﻷعلى", "num_chapters"),
        SelectFilterOption("عدد الفصول - من أعلى ﻷقل", "-num_chapters"),
        SelectFilterOption("الاسم - من أقل ﻷعلى", "english"),
        SelectFilterOption("الاسم - من أعلى ﻷقل", "-english"),
      ]),
    ];
  }

  @override
  List<dynamic> getSourcePreferences() {
    return [];
  }
}

RewayatClubSource main(MSource source) {
  return RewayatClubSource(source: source);
}
