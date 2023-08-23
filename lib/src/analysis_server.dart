import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analysis_server_utils/src/analysis_server_config.dart';

/// TODO: document
class AnalysisServer {
  AnalysisServer({
    AnalysisServerConfig? config,
  }) {
    _config = config ?? AnalysisServerConfig();
  }

  late final AnalysisServerConfig _config;

  final StreamController<String> _onSend = StreamController.broadcast();
  final StreamController<String> _onReceive = StreamController.broadcast();

  int id = 1;
  Process? _process;
  final Completer<int> processCompleter = Completer<int>();

  Stream<String> get onSend => _onSend.stream;
  Stream<String> get onReceive => _onReceive.stream;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  Future<void> start() async {
    print('process: ${_config.vmPath}');
    print('args: ${_config.processArgs}');
    _process = await Process.start(_config.vmPath, _config.processArgs);
    _process?.exitCode.then((code) {
      print('analysis_server process exited with: $code');
      processCompleter.complete(code);
    });

    _stdoutSubscription =
        _process?.stdout.transform(utf8.decoder).listen((data) {
      _onReceive.add(data);
    }, onError: (error) {
      print('The stdout *stream* produced an error: $error');
    });

    _stderrSubscription =
        _process?.stderr.transform(utf8.decoder).listen((data) {
      print('stderr received: $data');
    }, onError: (error) {
      print('The stderr *stream* produced an error: $error');
    });
  }

  /// Call a server method by wrapping and sending the passed RPC params,
  /// prefixed with the required LSP headers.
  void call(
      {required String method, required Map<String, Object?> params, int? id}) {
    Map<String, Object?> bodyJson = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': id ?? this.id++,
    };

    if (_process == null) {
      throw 'AnlysisServer _process was null, did you start the server?';
    }

    // Encode header as ascii & body as utf8, as per LSP spec.
    final jsonEncodedBody = jsonEncode(bodyJson);
    final utf8EncodedBody = utf8.encode(jsonEncodedBody);
    final header = 'Content-Length: ${utf8EncodedBody.length}\r\n'
        'Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n';
    final asciiEncodedHeader = ascii.encode(header);

    // Emit what is being sent, for any listeners of the onSend stream
    _onSend.add(jsonEncodedBody);

    // Send the message to the analysis_server process via its stdin
    _process!.stdin.add(asciiEncodedHeader);
    _process!.stdin.add(utf8EncodedBody);
  }

  void dispose() {
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _process?.kill();
  }
}
