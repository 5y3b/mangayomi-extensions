import '../../../../../model/source.dart';

Source get rewayatclubSource => _rewayatclubSource;
const _rewayatclubVersion = "0.0.1";
const _rewayatclubSourceCodeUrl =
    "https://raw.githubusercontent.com/m2k3a/mangayomi-extensions/$branchName/dart/novel/src/ar/rewayatclub/rewayatclub.dart";
const _rewayatclubIconUrl =
    "https://raw.githubusercontent.com/m2k3a/mangayomi-extensions/$branchName/dart/novel/src/ar/rewayatclub/icon.png";
Source _rewayatclubSource = Source(
  name: "rewayatclub",
  baseUrl: "https://rewayat.club",
  apiUrl: "https://rewayat.club",
  lang: "ar",
  typeSource: "single",
  iconUrl: _rewayatclubIconUrl,
  sourceCodeUrl: _rewayatclubSourceCodeUrl,
  itemType: ItemType.novel,
  version: _rewayatclubVersion,
  dateFormat: "MMM dd yyyy",
  dateFormatLocale: "en",
);
