import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

const _offlineMessage =
    "You're offline. Check your connection and try again.";
const _networkMessage =
    "Couldn't reach the server. Check your connection and try again.";

String apiErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 401 && error.detail?['error'] == 'user_deleted') {
      return 'This account was deleted.';
    }
    return error.message;
  }
  if (error is SocketException) return _offlineMessage;
  if (error is TimeoutException) return _networkMessage;
  if (error is http.ClientException) return _networkMessage;
  if (error is HandshakeException) return _networkMessage;
  final text = error.toString();
  if (text.contains('ClientException') || text.contains('SocketException')) {
    return _networkMessage;
  }
  return text;
}
