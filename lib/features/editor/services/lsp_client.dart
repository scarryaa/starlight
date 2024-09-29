import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LspClient {
  Process? _process;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  int _messageId = 0;
  final _responseCompleters = <int, Completer<Map<String, dynamic>>>{};
  final _initializationCompleter = Completer<void>();
  List<int> _buffer = [];
  bool _verbose = false;
  final Duration _timeout;

  LspClient({Duration timeout = const Duration(seconds: 15)})
      : _timeout = timeout;

  Future<void> get initialized => _initializationCompleter.future;

  Future<void> start(String command, List<String> arguments) async {
    try {
      if (_verbose) {
        print("Starting LSP process: $command ${arguments.join(' ')}");
      }
      _process = await Process.start(command, arguments);

      _process!.exitCode.then((exitCode) {
        if (exitCode != 0) {
          print("LSP process exited with code: $exitCode");
        }
        if (!_initializationCompleter.isCompleted) {
          _initializationCompleter
              .completeError("LSP process exited unexpectedly");
        }
      });

      _stdoutSubscription =
          _process!.stdout.listen(_handleServerOutput, onError: (error) {
        print("Error in stdout stream: $error");
      });

      _stderrSubscription = _process!.stderr.listen((data) {
        print("LSP server error: ${utf8.decode(data)}");
      }, onError: (error) {
        print("Error in stderr stream: $error");
      });

      await sendRequest('initialize',
          {'processId': null, 'rootUri': null, 'capabilities': {}});

      if (_verbose) print("LSP process started and initialized");
      _initializationCompleter.complete();
    } catch (e) {
      print("Error starting LSP process: $e");
      _initializationCompleter.completeError(e);
      rethrow;
    }
  }

  void setVerboseLogging(bool verbose) {
    _verbose = verbose;
  }

  void _handleServerOutput(List<int> data) {
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
        if (_verbose) print("Error parsing JSON: $e");
        if (_verbose) print("Received data: $jsonStr");
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
    if (_verbose) print("Received message: $message");
    if (message.containsKey('id')) {
      int id = message['id'];
      final completer = _responseCompleters.remove(id);
      completer?.complete(message);
    } else if (message.containsKey('method')) {
      if (_verbose) print('Server notification: ${message['method']}');
      // Handle server notifications if needed
    }
  }

  Future<Map<String, dynamic>> sendRequest(String method,
      [Map<String, dynamic>? params]) async {
    await initialized; // Ensure the client is initialized before sending requests
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

    if (_verbose) print("Sending request to LSP server: $message");

    try {
      _process!.stdin.add(utf8.encode(message));
    } catch (e) {
      print("Error sending request to LSP server: $e");
      _responseCompleters.remove(id);
      throw Exception("Failed to send request to LSP server: $e");
    }

    return completer.future.timeout(
      _timeout,
      onTimeout: () {
        print("Request timed out: $method");
        _responseCompleters.remove(id);
        throw TimeoutException("LSP server did not respond in time");
      },
    );
  }

  Future<List<int>> getSemanticTokens(String uri) async {
    try {
      final response = await sendRequest('textDocument/semanticTokens/full', {
        'textDocument': {'uri': uri}
      });
      return List<int>.from(response['result']['data']);
    } catch (e) {
      print("Error getting semantic tokens: $e");
      return [];
    }
  }

  Future<void> stop() async {
    print("Stopping LSP client");
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _process?.kill();
  }
}
