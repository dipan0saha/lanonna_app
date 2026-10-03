import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../media/display_encode.dart';
import 'api_client.dart';

class DisplayPhotoUpload {
  DisplayPhotoUpload(this._api);

  final ApiClient _api;

  /// Uploads a profile avatar to the display bucket; returns a stable HTTPS URL.
  Future<String> uploadProfileAvatar({
    required File imageFile,
    String? contentType,
  }) async {
    final encoded = encodeDisplayAsset(await imageFile.readAsBytes());
    final resolvedType = contentType ?? encoded.contentType;
    final init = await _api.postJson('/v1/uploads/display/signed-url', body: {
      'content_type': resolvedType,
      'byte_length': encoded.bytes.length,
    });
    final uploadUrl = init['upload_url'] as String;
    final bucket = init['bucket'] as String;
    final objectPath = init['object_path'] as String;
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: signedPutHeadersForInit(
        init,
        resolvedType,
        encoded.bytes.length,
      ),
      body: encoded.bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Avatar upload failed (${response.statusCode})');
    }
    return 'https://storage.googleapis.com/$bucket/$objectPath';
  }

  Future<String> uploadGalleryPhoto({
    required String babyProfileId,
    required File imageFile,
    String? contentType,
  }) async {
    final encoded = encodeDisplayAsset(await imageFile.readAsBytes());
    final resolvedType = contentType ?? encoded.contentType;
    final body = encoded.bytes;
    final init = await _api.postJson('/v1/photos/init', body: {
      'baby_profile_id': babyProfileId,
      'content_type': resolvedType,
      'byte_length': body.length,
    });
    final photoId = init['photo_id'] as String;
    final uploadUrl = init['upload_url'] as String;
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: signedPutHeadersForInit(init, resolvedType, body.length),
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Photo upload failed (${response.statusCode})');
    }
    return photoId;
  }

  /// GCS V4 signed PUTs require every header that was included at sign time.
  @visibleForTesting
  static Map<String, String> signedPutHeadersForInit(
    Map<String, dynamic> init,
    String contentType,
    int byteLength,
  ) {
    final fromApi = init['required_headers'];
    final headers = <String, String>{
      'Content-Type': contentType,
    };
    if (fromApi is Map) {
      for (final entry in fromApi.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }
    final maxBytes = init['max_bytes'];
    headers.putIfAbsent(
      'x-goog-content-length-range',
      () => maxBytes is int ? '0,$maxBytes' : '0,$displayMaxBytes',
    );
    headers['Content-Type'] = contentType;
    if (byteLength > displayMaxBytes) {
      throw Exception('Photo exceeds maximum size (2 MB).');
    }
    return headers;
  }
}
