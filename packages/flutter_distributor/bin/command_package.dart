import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_distributor/flutter_distributor.dart';
import 'package:flutter_distributor/src/extensions/extensions.dart';
import 'package:flutter_distributor/src/utils/logger.dart';

/// Package an application bundle for a specific platform and target
///
/// This command wrapper defines, parses and transforms all passed arguments,
/// so that they may be passed to `flutter_distributor`. The distributor will
/// then build an application bundle using `flutter_app_packager`.
class CommandPackage extends Command {
  CommandPackage(this.distributor) {
    argParser.addOption(
      'platform',
      valueHelp: [
        'android',
        'ios',
        'linux',
        'macos',
        'windows',
        'web',
      ].join(','),
      help: 'The platform to package the application for',
    );

    argParser.addOption(
      'targets',
      aliases: ['target'],
      valueHelp: [
        'apk',
        'aab',
        'appimage',
        'deb',
        'dmg',
        'exe',
        'ipa',
        'msix',
        'pkg',
        'rpm',
        'zip',
      ].join(','),
      help: 'Comma separated list of bundle types to build.',
    );

    argParser.addOption('channel', valueHelp: '');
    argParser.addOption('artifact-name', valueHelp: '');

    argParser.addFlag(
      'skip-clean',
      help: 'Whether or not to skip \'flutter clean\' before packaging.',
    );

    argParser.addMultiOption(
      'build-args',
      valueHelp: 'any args supported by "flutter build subcommand"',
      help: [
        'Arguments to pass directly to flutter build subcommand.',
        'You may add multiple "--build-args=\'key=value\'"pairs.',
        'example:',
        '  --build-args=\'build-number=1.0.0\'',
        '  --build-args=\'target-platform=linux-arm64\'',
      ].join('\n'),
    );
  }

  final FlutterDistributor distributor;

  @override
  String get name => 'package';

  @override
  String get description => [
        'Package the current Flutter application',
        '',
        '\'key=value\' pairs defined by --build-args are passed to \'flutter build\' as is',
        'Please consult the \'flutter build\' CLI help for more informations.',
      ].join('\n');

  @override
  Future run() async {
    final String? platform = argResults?['platform'];
    final List<String> targets = '${argResults?['targets'] ?? ''}'
        .split(',')
        .where((e) => e.isNotEmpty)
        .toList();
    final String? channel = argResults?['channel'];
    final String? artifactName = argResults?['artifact-name'];
    final bool isSkipClean = argResults?.wasParsed('skip-clean') ?? false;
    final Map<String, dynamic> buildArguments = _generateBuildArgs();

    // At least `platform` and one `targets` is required for flutter build
    if (platform == null) {
      print('\nThe \'platform\' options is mandatory!'.red(bold: true));
      exit(1);
    }

    if (targets.isEmpty) {
      print('\nAt least one \'target\' must be specified!'.red(bold: true));
      exit(1);
    }

    return distributor.package(
      platform,
      targets,
      channel: channel,
      artifactName: artifactName,
      cleanBeforeBuild: !isSkipClean,
      buildArguments: buildArguments,
    );
  }

  Map<String, dynamic> _generateBuildArgs() {
    Map<String, dynamic> buildArguments = {};
    final args = argResults?['build-args'];

    if (args == null) return buildArguments;

    final List<String> dartDefine = [];
    final List<String> dartDefineFromFile = [];
    for (var kv in args) {
      final kvl = kv.split('=');
      final value = kv.replaceFirst(RegExp('${kvl?[0]}=?'), '');
      if (kvl?[0] == 'dart-define') {
        dartDefine.add(value);
      } else if (kvl[0] == 'dart-define-from-file') {
        dartDefineFromFile.add(value);
      } else {
        buildArguments.putIfAbsent(kvl?[0], () => value);
      }
    }
    if (dartDefine.isNotEmpty) {
      buildArguments.putIfAbsent(
        'dart-define',
        () => dartDefine,
      );
    }
    if (dartDefineFromFile.isNotEmpty) {
      buildArguments.putIfAbsent(
        'dart-define-from-file',
        () => dartDefineFromFile,
      );
    }
    logger.info('buildArguments: $buildArguments');

    return buildArguments;
  }
}
