import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LspClient {
  late Process _process;
  late StreamSubscription<List<int>> _stdoutSubscription;
  late StreamSubscription<List<int>> _stderrSubscription;
  int _messageId = 0;
  final _responseCompleters = <int, Completer<Map<String, dynamic>>>{};
  Completer<void> _serverReady = Completer<void>();
  List<int> _buffer = [];

  Future<void> start(String command, List<String> arguments) async {
    try {
      print("Starting LSP process: $command ${arguments.join(' ')}");
      _process = await Process.start(command, arguments);

      _process.exitCode.then((exitCode) {
        print("LSP process exited with code: $exitCode");
        if (!_serverReady.isCompleted) {
          _serverReady.completeError("LSP process exited unexpectedly");
        }
      });

      _stdoutSubscription =
          _process.stdout.listen(_handleServerOutput, onError: (error) {
        print("Error in stdout stream: $error");
      });

      _stderrSubscription = _process.stderr.listen((data) {
        print("LSP server error: ${utf8.decode(data)}");
      }, onError: (error) {
        print("Error in stderr stream: $error");
      });

      await sendRequest('initialize',
          {'processId': null, 'rootUri': null, 'capabilities': {}});

      print("LSP process started and initialized");
    } catch (e) {
      print("Error starting LSP process: $e");
      rethrow;
    }
  }

  void _handleServerOutput(List<int> data) {
    print("Received raw data: ${utf8.decode(data)}");
    _buffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    while (true) {
      int headerEnd = _indexOf(_buffer, utf8.encode('\r\n\r\n'));
      if (headerEnd == -1) return;

      List<int> headerBytes = _buffer.sublist(0, headerEnd);
      String headerStr = utf8.decode(headerBytes);
      Map<String, String> headers = _parseHeader(headerStr);

      int contentLength;
      try {
        contentLength = int.parse(headers['Content-Length'] ?? '');
      } catch (e) {
        print("Error parsing content length: $e");
        print("Received headers: $headers");
        _buffer = _buffer.sublist(headerEnd + 4);
        continue;
      }

      if (_buffer.length < headerEnd + 4 + contentLength) return;

      List<int> jsonData =
          _buffer.sublist(headerEnd + 4, headerEnd + 4 + contentLength);
      _buffer = _buffer.sublist(headerEnd + 4 + contentLength);

      String jsonStr = utf8.decode(jsonData);
      try {
        Map<String, dynamic> message = json.decode(jsonStr);
        _handleMessage(message);
      } catch (e) {
        print("Error parsing JSON: $e");
        print("Received data: $jsonStr");
      }
    }
  }

  Map<String, String> _parseHeader(String headerStr) {
    Map<String, String> result = {};
    for (String line in headerStr.split('\r\n')) {
      int colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        String key = line.substring(0, colonIndex).trim();
        String value = line.substring(colonIndex + 1).trim();
        result[key] = value;
      }
    }
    return result;
  }

  int _indexOf(List<int> source, List<int> target) {
    for (int i = 0; i <= source.length - target.length; i++) {
      bool found = true;
      for (int j = 0; j < target.length; j++) {
        if (source[i + j] != target[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  void _handleMessage(Map<String, dynamic> message) {
    print("Received message: $message");
    if (message.containsKey('id')) {
      int id = message['id'];
      final completer = _responseCompleters.remove(id);
      completer?.complete(message);
      if (!_serverReady.isCompleted && message.containsKey('result')) {
        _serverReady.complete();
      }
    } else if (message.containsKey('method')) {
      print('Server notification: ${message['method']}');
    }
  }

  Future<Map<String, dynamic>> sendRequest(String method,
      [Map<String, dynamic>? params]) async {
    final id = _messageId++;
    final request = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };

    final completer = Completer<Map<String, dynamic>>();
    _responseCompleters[id] = completer;

    final jsonRequest = json.encode(request);
    final message = 'Content-Length: ${jsonRequest.length}\r\n\r\n$jsonRequest';

    print("Sending request to LSP server: $message");

    try {
      _process.stdin.add(utf8.encode(message));
    } catch (e) {
      print("Error sending request to LSP server: $e");
      _responseCompleters.remove(id);
      throw Exception("Failed to send request to LSP server: $e");
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        print("Request timed out: $method");
        _responseCompleters.remove(id);
        throw TimeoutException("LSP server did not respond in time");
      },
    );
  }

  Future<void> stop() async {
    print("Stopping LSP client");
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    _process.kill();
  }
}
