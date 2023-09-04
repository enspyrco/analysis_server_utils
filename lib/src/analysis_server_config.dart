import 'dart:io';

import 'package:path/path.dart' as path;

/// TODO: document
/// [sdkPath] override the default sdk path
/// [scriptPath] override the default entry-point script to use for the analysis server
class AnalysisServerConfig {
  AnalysisServerConfig({
    String? sdkPath,
    String? scriptPath,
    String? logFile,
    List<String>? vmArgs,
    List<String>? serverArgs,
    String? clientId,
    String? clientVersion,
  }) {
    print('${path.dirname(Platform.script.path)}/$logFile');
    if (sdkPath != null) {
      vmPath =
          path.join(sdkPath, 'bin', Platform.isWindows ? 'dart.exe' : 'dart');
    } else {
      sdkPath = path.dirname(path.dirname(Platform.resolvedExecutable));
      vmPath = Platform.resolvedExecutable;
    }

    // we use the path of the snapshot to check that sdk path is valid
    scriptPath ??= '$sdkPath/bin/snapshots/analysis_server.dart.snapshot';
    if (!File(scriptPath).existsSync()) {
      throw 'It seems we are looking in the wrong place for the analysis_server.\n'
          'The SDK path used was $sdkPath\n'
          'You can try explicitly setting the Dart SDK path by adding an `AnalysisServerConfig` parameter with the `sdkPath` set, eg:\n\n'
          'AnalysisServer server = AnalysisServer(..., config: AnalysisServerConfig(sdkPath: \'a_valid_path\'),'
          ');';
    }

    processArgs = ['language-server', '--sdk', sdkPath];
    if (vmArgs != null) processArgs.insertAll(0, vmArgs);
    if (serverArgs != null) processArgs.addAll(serverArgs);
    if (clientId != null) processArgs.add('--client-id=$clientId');
    if (clientVersion != null) {
      processArgs.add('--client-version=$clientVersion');
    }
    if (logFile != null) {
      processArgs.add(
          '--instrumentation-log-file=${path.dirname(Platform.script.path)}/$logFile');
    }
  }

  late final String vmPath;
  late final String sdkPath;
  late final List<String> processArgs;
}
