import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'package:uri/uri.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../log.dart';
import '../scatter.dart';
import '../util.dart';
import 'host_adapter.dart';

class GitHubAdapter implements HostAdapter {
  static const String _urlPattern = "https://{}github.com";
  static final GitHubAdapter instance = GitHubAdapter._();

  GitHubAdapter._();

  @override
  FutureOr<List<String>> listVersions() {
    throw UnsupportedError("GitHub is not a minecraft host, stop being funny like that");
  }

  @override
  FutureOr<bool> isProject(String id) async {
    var response = await client.get(Uri.parse("${_url("api")}/repos/$id"), headers: createHeaders());
    return response.statusCode == 200;
  }

  @override
  FutureOr<bool> upload(ModInfo mod, UploadSpec spec) async {
    var createUrl = Uri.parse("${_url("api")}/repos/${mod.platform_ids["github"]}/releases");
    var data = {"tag_name": spec.version, "name": spec.version, "body": spec.changelog};

    var target = await prompt("Git tag target (empty for HEAD)");
    if (target.isNotEmpty) data["target_commitish"] = target;

    debug("Creating release");

    var createResponse = jsonDecode((await client.post(createUrl, headers: createHeaders(), body: jsonEncode(data))).body);
    debug(createResponse);

    var uploadUrl = UriTemplate(createResponse["upload_url"]).expand({"name": basename(spec.file.path)});
    var uploadRequest = MultipartRequest("POST", Uri.parse(uploadUrl));

    uploadRequest
      ..headers["Authorization"] = "token ${ConfigManager.getToken(getId())}"
      ..files.add(await MultipartFile.fromPath("file", spec.file.path, contentType: MediaType("application", "java-archive")));

    debug("Uploading artifact");

    var result = await client.send(uploadRequest);
    var success = result.statusCode == 201;

    debug("Status Code: ${result.statusCode}");

    var uploadResponse = jsonDecode(await utf8.decodeStream(result.stream));
    debug(uploadResponse);

    if (success) {
      info("GitHub release created: ${createResponse["html_url"]}");
    } else {
      error(uploadResponse);
    }

    return success;
  }

  static String _url([String sub = ""]) => _urlPattern.replaceFirst("{}", sub.isEmpty ? "" : "$sub.");

  Map<String, String> createHeaders() {
    return {"Authorization": "token ${ConfigManager.getToken(getId())}", "Accept": "application/vnd.github.v3+json"};
  }

  @override
  String getId() => "github";
}
