import 'api_exception.dart';

String apiErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return error.toString();
}
