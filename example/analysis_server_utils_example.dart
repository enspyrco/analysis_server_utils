import 'dart:convert';
import 'dart:io';

import 'package:analysis_server_utils/analysis_server_utils.dart';
import 'package:intl/intl.dart';
import 'package:lsp_models/lsp_models.dart';
import 'package:path/path.dart';

void main() async {
  AnalysisServer server = AnalysisServer(
    config: AnalysisServerConfig(
      clientId: 'enspyr.co',
      clientVersion: '0.0.1',
      logFile: 'analysis_server_utils.log',
    ),
  );

  await server.start();

  final initializeParams = InitializeParams(
    processId: pid,
    rootUri: Directory.current.uri,
    capabilities: ClientCapabilities(),
    initializationOptions: {},
    trace: const TraceValues.fromJson('verbose'),
    workspaceFolders: [
      WorkspaceFolder(
        name: basename(Directory.current.path),
        uri: Directory.current.uri,
      )
    ],
    clientInfo: InitializeParamsClientInfo(name: 'enspyr.co', version: '0.0.1'),
    locale: Intl.getCurrentLocale(),
  );

  server.initialize(paramsJson: initializeParams.toJson());

  await for (List<int> data in server.streamChannel.stream) {
    print(utf8.decode(data));
  }

  server.dispose();
}
