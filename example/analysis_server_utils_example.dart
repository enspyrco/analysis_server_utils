import 'dart:convert';

import 'package:analysis_server_utils/analysis_server_utils.dart';

void main() async {
  AnalysisServer server = AnalysisServer(
    config: AnalysisServerConfig(
      clientId: 'enspyr.co',
      clientVersion: '0.0.1',
      logFile: 'analysis_server_utils.log',
    ),
  );

  await server.start();
  server.initialize();

  await for (List<int> data in server.streamChannel.stream) {
    print(utf8.decode(data));
  }

  server.dispose();
}
