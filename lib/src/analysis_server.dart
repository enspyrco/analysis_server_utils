import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:analysis_server_utils/src/analysis_server_config.dart';
import 'package:logging/logging.dart';
import 'package:lsp_models/lsp_models.dart';
import 'package:stream_channel/stream_channel.dart';

/// The [AnalysisServer] starts the analysis_server process and provides a
/// [StreamChannel] that can be used by other objects to communicate with the
/// running process.
///
/// Input to (and output from) the [StreamChannel] must be a UInt8List message
/// with a header and a content part, separated by a ‘\r\n’, where the header is
/// ascii encoded and the body is utf8 encoded. See: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#baseProtocol
class AnalysisServer {
  AnalysisServer({
    AnalysisServerConfig? config,
  }) {
    _config = config ?? AnalysisServerConfig();
  }

  late final AnalysisServerConfig _config;

  final StreamChannelController<List<int>> _streamChannelController =
      StreamChannelController(allowForeignErrors: false);

  Process? _process;
  final Completer<int> processCompleter = Completer<int>();

  Future<void> start() async {
    // Spawn the analysis_server process
    log('Spawning: ${_config.vmPath} with args ${_config.processArgs}',
        level: Level.INFO.value);
    _process = await Process.start(_config.vmPath, _config.processArgs);
    _process?.exitCode.then((code) {
      log('analysis_server process exited with: $code',
          level: Level.INFO.value);
      processCompleter.complete(code);
    });

    // Pipe all events from stdout into the local sink...
    _process!.stdout.pipe(_streamChannelController.local.sink);

    // ... and all events from the local stream into stdin
    _streamChannelController.local.stream
        .listen(_process!.stdin.add, onDone: _process!.stdin.close);
  }

  /// The id is the method is given by the AnalysisProcess.initialize enum index
  /// so that the response can be identified in the analysis_client
  void initialize({required Map<String, Object?> paramsJson}) {
    if (_process == null) {
      throw 'AnlysisServer _process was null, did you start the server?';
    }

    // When the lsp_client and analysis_server_utils are running in separate
    // processses (eg. communicating over websockets) we need to set the pid
    // here.
    paramsJson['processId'] ??= pid;

    Map<String, Object?> bodyJson = {
      'jsonrpc': '2.0',
      'method': 'initialize',
      'params': paramsJson,
      'id': AnalysisProcess.initialize.index,
    };

    // Encode header as ascii & body as utf8, as per LSP spec.
    final jsonEncodedBody = jsonEncode(bodyJson);
    final utf8EncodedBody = utf8.encode(jsonEncodedBody);
    final header = 'Content-Length: ${utf8EncodedBody.length}\r\n'
        'Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n';
    final asciiEncodedHeader = ascii.encode(header);

    // Send the message to the analysis_server process via its stdin
    _process!.stdin.add(asciiEncodedHeader);
    _process!.stdin.add(utf8EncodedBody);
  }

  /// Return the foreign [StreamChannel] for users of the [AnalysisServer].
  StreamChannel<List<int>> get streamChannel =>
      _streamChannelController.foreign;

  Future<void> dispose() async {
    _process?.kill();
  }
}
