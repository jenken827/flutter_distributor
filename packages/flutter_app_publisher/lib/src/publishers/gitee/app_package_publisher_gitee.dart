import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/src/api/app_package_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/gitee/publish_gitee_config.dart';

class AppPackagePublisherGitee extends AppPackagePublisher {
  final Dio _dio = Dio();

  @override
  String get name => 'gitee';

  @override
  List<String> get supportedPlatforms => [
        'android',
        'ios',
        'linux',
        'macos',
        'windows',
        'web',
      ];

  @override
  Future<PublishResult> publish(
    FileSystemEntity fileSystemEntity, {
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
    PublishProgressCallback? onPublishProgress,
  }) async {
    File file = fileSystemEntity as File;
    PublishGiteeConfig publishConfig = PublishGiteeConfig.parse(
      environment,
      publishArguments,
    );
    // Set auth
    _dio.options = BaseOptions(
      headers: {
        'Authorization': 'token ${publishConfig.token}',
      },
    );
    String? rid;
    if (publishConfig.releaseId != null) {
      rid = publishConfig.releaseId!;
    } else if (!(publishConfig.releaseSyncGithub ?? false)) {
      rid = await _getLatestReleaseId(publishConfig);
    } else {
      final gr = await _getGithubLatestReleaseInfo(publishConfig);
      rid = await _checkExists(publishConfig, gr?['tag_name']);
      rid ??= await _createRelease(publishConfig, gr);

      if (rid == null) {
        throw PublishError('Failed to create release');
      }
    }
    final browserDownloadUrl = await _uploadReleaseAsset(
      file,
      rid!,
      publishConfig,
      onPublishProgress,
    );

    return PublishResult(
      url: browserDownloadUrl,
    );
  }

  Future<Map<String, dynamic>?> _getGithubLatestReleaseInfo(
    PublishGiteeConfig pconfig,
  ) async {
    Response resp = await Dio().get(
      'https://api.github.com/repos/${pconfig.repoOwner}/${pconfig.repoName}/releases/latest',
    );
    print(resp.data);
    return resp.data;
  }

  Future<String?> _checkExists(
    PublishGiteeConfig pconfig,
    String tagname,
  ) async {
    Response resp = await _dio.get(
      'https://gitee.com/api/v5/repos/${pconfig.repoOwner}/${pconfig.repoName}/releases/tags/$tagname',
    );
    return resp.data?['id'];
  }

  /// Create release
  Future<String?> _createRelease(
    PublishGiteeConfig publishConfig,
    dynamic githubReleaseInfo,
  ) async {
    final formData = FormData.fromMap({
      'tag_name': githubReleaseInfo['tag_name'],
      'name': githubReleaseInfo['name'],
      'body': githubReleaseInfo['body'],
      'target_commitish': githubReleaseInfo['target_commitish'],
    });
    _dio.options.contentType = 'multipart/form-data';
    Response resp = await _dio.post(
      'https://gitee.com/api/v5/repos/${publishConfig.repoOwner}/${publishConfig.repoName}/releases',
      data: formData,
    );
    return resp.data?['id'].toString();
  }

  /// Get latest release id
  Future<String?> _getLatestReleaseId(
    PublishGiteeConfig publishConfig,
  ) async {
    Response resp = await _dio.get(
      'https://gitee.com/api/v5/repos/${publishConfig.repoOwner}/${publishConfig.repoName}/releases/latest',
      data: <String, String>{
        'owner': publishConfig.repoOwner,
        'repo': publishConfig.repoName,
      },
    );
    return resp.data?['id'].toString();
  }

  /// Upload Release Asset
  Future<String> _uploadReleaseAsset(
    File file,
    String releaseId,
    PublishGiteeConfig pconfig,
    PublishProgressCallback? onPublishProgress,
  ) async {
    final url =
        'https://gitee.com/api/v5/repos/${pconfig.repoOwner}/${pconfig.repoName}/releases/$releaseId/attach_files';

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
        ),
      });
      _dio.options.contentType = 'multipart/form-data';
      final response = await _dio.post(
        url,
        data: formData,
        onSendProgress: (sent, total) {
          if (onPublishProgress != null) {
            onPublishProgress(sent, total);
          }
        },
      );

      final browserDownloadUrl = response.data?['browser_download_url'];
      if (browserDownloadUrl == null || browserDownloadUrl.isEmpty) {
        throw PublishError('Failed to get download URL from response');
      }

      return browserDownloadUrl;
    } catch (e) {
      throw PublishError('Failed to upload release asset: ${e.toString()}');
    }
  }
}
