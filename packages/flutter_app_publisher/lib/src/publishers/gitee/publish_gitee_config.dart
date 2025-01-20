import 'dart:io';

import 'package:flutter_app_publisher/src/api/app_package_publisher.dart';

const kEnvGiteeToken = 'GITEE_TOKEN';
const kEnvGiteeRepositoryOwner = 'GITEE_REPOSITORY_OWNER';
const kEnvGiteeRepository = 'GITEE_REPOSITORY';

class PublishGiteeConfig extends PublishConfig {
  PublishGiteeConfig({
    required this.token,
    required this.repoOwner,
    required this.repoName,
    this.releaseId,
    this.releaseSyncGithub,
  });

  factory PublishGiteeConfig.parse(
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
  ) {
    String? token = (environment ?? Platform.environment)[kEnvGiteeToken];
    String? giteeRepository =
        (environment ?? Platform.environment)[kEnvGiteeRepository];
    String? giteeRepositoryOwner =
        (environment ?? Platform.environment)[kEnvGiteeRepositoryOwner];
    if ((token ?? '').isEmpty) {
      throw PublishError('Missing `$kEnvGiteeToken` environment variable.');
    }
    String? owner = publishArguments?['repo-owner'];
    if ((owner ?? '').isEmpty && giteeRepositoryOwner?.isNotEmpty == true) {
      print(
        'Using provided $giteeRepositoryOwner from ENV '
        '$kEnvGiteeRepositoryOwner as repo-owner',
      );
      owner = giteeRepositoryOwner;
    }

    String? name = publishArguments?['repo-name'];
    if ((owner ?? '').isEmpty &&
        giteeRepository?.isNotEmpty == true &&
        giteeRepository!.contains('/')) {
      print(
        'Extracting repo name from provided $giteeRepository from ENV '
        '$kEnvGiteeRepository as repo-name',
      );
      var parts = giteeRepository.split('/');
      if ((owner ?? '').isEmpty) {
        owner = parts[0];
      } else if (owner != parts[0]) {
        throw PublishError(
          '<repo-name> is mismatch error between $giteeRepository from ENV '
          '$kEnvGiteeRepository and $giteeRepositoryOwner from ENV '
          '$kEnvGiteeRepositoryOwner',
        );
      }
      name = parts[1];
    }
    if ((owner ?? '').isEmpty) {
      throw PublishError('<repo-owner> is null');
    }
    if ((name ?? '').isEmpty) {
      throw PublishError('<repo-name> is null');
    }

    PublishGiteeConfig publishConfig = PublishGiteeConfig(
      token: token!,
      repoOwner: owner!,
      repoName: name!,
      releaseId: publishArguments?['release-id'],
      releaseSyncGithub: publishArguments?['release-sync-github'],
    );

    return publishConfig;
  }

  // Personal access tokens
  final String token;
  // Repository Owner
  String repoOwner;
  // Repository Name
  String repoName;
  // Release title
  final String? releaseId;
  final bool? releaseSyncGithub;
}
