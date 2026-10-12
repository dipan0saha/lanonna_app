import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

const String offlineErrorMessage =
    "You're offline. Check your connection and try again.";
const _networkMessage =
    "Couldn't reach the server. Check your connection and try again.";

String apiErrorMessage(Object error) {
  if (error is ApiException) {
    final code = error.detail?['error'];
    if (error.statusCode == 401 && code == 'user_deleted') {
      return 'This account was deleted.';
    }
    if (code == 'network_unavailable') return offlineErrorMessage;
    if (code == 'network_timeout') return _networkMessage;
    return error.message;
  }
  if (error is SocketException) return offlineErrorMessage;
  if (error is TimeoutException) return _networkMessage;
  if (error is http.ClientException) return _networkMessage;
  if (error is HandshakeException) return _networkMessage;
  final text = error.toString();
  if (text.contains('ClientException') || text.contains('SocketException')) {
    return _networkMessage;
  }
  return text;
}
