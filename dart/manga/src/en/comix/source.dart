import '../../../../../model/source.dart';

Source get comixSource => _comixSource;
const _comixVersion = "0.1.0";
const _comixSourceCodeUrl =
    "https://raw.githubusercontent.com/m2k3a/mangayomi-extensions/$branchName/dart/manga/src/en/comix/comix.dart";
Source _comixSource = Source(
  id: 5738565392,
  name: "Comix",
  baseUrl: "https://comix.to",
  apiUrl: "https://comix.to/api/v1/",
  lang: "en",
  typeSource: "single",
  iconUrl:
      "https://raw.githubusercontent.com/m2k3a/mangayomi-extensions/$branchName/dart/manga/src/en/comix/icon.png",
  sourceCodeUrl: _comixSourceCodeUrl,
  itemType: ItemType.manga,
  version: _comixVersion,
  dateFormat: "",
  dateFormatLocale: "",
  isNsfw: false,
  hasCloudflare: false,
);
