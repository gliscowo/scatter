import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:uri/uri.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../log.dart';
import '../scatter.dart';
import '../util.dart';
import 'host_adapter.dart';

class GitHubAdapter extends HostAdapter {
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

    debug("Creating release at '$createUrl'");

    var response = (await client.post(createUrl, headers: createHeaders(), body: jsonEncode(data)));
    while (response.statusCode == 307) {
      response = (await client.post(Uri.parse(response.headers["location"]!),
          headers: createHeaders(), body: jsonEncode(data)));
    }

    var responseData = jsonDecode(response.body) as Map<String, dynamic>;

    debug(responseData);
    debug(response.statusCode);

    if (response.statusCode != 201) {
      final errors =
          (responseData["errors"] as List<dynamic>).map((e) => "${e["resource"]}[${e["field"]}]: ${e["code"]}");
      error("Could not create GitHub release: ${responseData["message"]} / $errors");
      return false;
    }

    var uploadUrl = UriTemplate(responseData["upload_url"]).expand({"name": basename(spec.file.path)});
    var uploadRequest = Request("POST", Uri.parse(uploadUrl));

    debug("Creating upload request");

    uploadRequest
      ..headers["Authorization"] = "token ${ConfigManager.getToken(id)}"
      ..headers["Content-Type"] = "application/java-archive"
      ..headers["Content-Length"] = spec.file.lengthSync().toString();

    debug("Reading artifact bytes");

    uploadRequest.bodyBytes = spec.file.readAsBytesSync();

    debug("Uploading artifact");

    var result = await client.send(uploadRequest);
    var success = result.statusCode == 201;

    debug("Status Code: ${result.statusCode}");

    var uploadResponse = jsonDecode(await utf8.decodeStream(result.stream));
    debug(uploadResponse);

    if (success) {
      info("GitHub release created: ${responseData["html_url"]}");
    } else {
      error(uploadResponse);
    }

    return success;
  }

  static String _url([String sub = ""]) => _urlPattern.replaceFirst("{}", sub.isEmpty ? "" : "$sub.");

  Map<String, String> createHeaders() {
    return {"Authorization": "token ${ConfigManager.getToken(id)}", "Accept": "application/vnd.github.v3+json"};
  }

  @override
  String get id => "github";
}
