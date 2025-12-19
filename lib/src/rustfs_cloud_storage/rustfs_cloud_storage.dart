import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import '../rustfs_client/client/client.dart';
import '../rustfs_upload/rustfs_upload.dart';

/// Concrete implementation of RustFS cloud storage for use with Serverpod.
class RustFSCloudStorage extends CloudStorage {
  late final String _rustFSAccessKeyId;
  late final String _rustFSSecretKey;
  final String region;
  final String bucket;
  final bool public;

  // RustFS public url
  late final String? publicHost;

  late final RustFSClient _s3Client;

  // RustFS endpoint url
  final String host;

  /// Creates a new [RustFSCloudStorage] reference.
  RustFSCloudStorage({
    required Serverpod serverpod,
    required String storageId,
    required this.public,
    required this.region,
    required this.bucket,
    this.publicHost,
    required this.host,
  }) : super(storageId) {
    serverpod.loadCustomPasswords([
      (envName: 'SERVERPOD_RUSTFS_ACCESS_KEY_ID', alias: 'RustFSAccessKeyId'),
      (envName: 'SERVERPOD_RUSTFS_SECRET_KEY', alias: 'RustFSSecretKey'),
    ]);

    var rustFSAccessKeyId = serverpod.getPassword('RustFSAccessKeyId');
    var rustFSSecretKey = serverpod.getPassword('RustFSSecretKey');

    if (rustFSAccessKeyId == null) {
      throw StateError(
        'RustFSAccessKeyId must be configured in your passwords.',
      );
    }

    if (rustFSSecretKey == null) {
      throw StateError('RustFSSecretKey must be configured in your passwords.');
    }

    _rustFSAccessKeyId = rustFSAccessKeyId;
    _rustFSSecretKey = rustFSSecretKey;

    // Create client
    _s3Client = RustFSClient(
      accessKey: _rustFSAccessKeyId,
      secretKey: _rustFSSecretKey,
      bucketId: bucket,
      region: region,
      host: host,
    );

    // this.publicHost = publicHost ?? '$host$bucket';
  }

  @override
  Future<void> storeFile({
    required Session session,
    required String path,
    required ByteData byteData,
    DateTime? expiration,
    bool verified = true,
  }) async {
    await RustFSUploader.uploadData(
      accessKey: _rustFSAccessKeyId,
      secretKey: _rustFSSecretKey,
      bucket: bucket,
      region: region,
      data: byteData,
      uploadDst: path,
      public: public,
      host: host,
    );
  }

  @override
  Future<ByteData?> retrieveFile({
    required Session session,
    required String path,
  }) async {
    final response = await _s3Client.getObject(path);
    if (response.statusCode == 200) {
      return ByteData.view(response.bodyBytes.buffer);
    }
    return null;
  }

  @override
  Future<Uri?> getPublicUrl({
    required Session session,
    required String path,
  }) async {
    if (await fileExists(session: session, path: path)) {
      if (publicHost == null) {
        // use presigned url
        var url = _s3Client.buildPresignedGetObjectUrl(key: path);
        return url;
      } else {
        return Uri.parse('https://$publicHost/$bucket/$path');
      }
      // return Uri.parse('https://$publicHost/$bucket/$path');
      // return Uri.parse('https://$publicHost/$path');
    }
    return null;
  }

  @override
  Future<bool> fileExists({
    required Session session,
    required String path,
  }) async {
    var response = await _s3Client.headObject(path);
    print('> fileExists statusCode: ${response.statusCode}');
    return response.statusCode == 200;
  }

  @override
  Future<void> deleteFile({
    required Session session,
    required String path,
  }) async {
    await _s3Client.deleteObject(path);
  }

  @override
  Future<String?> createDirectFileUploadDescription({
    required Session session,
    required String path,
    Duration expirationDuration = const Duration(minutes: 10),
    int maxFileSize = 10 * 1024 * 1024,
  }) async {
    return await RustFSUploader.getDirectUploadDescription(
      accessKey: _rustFSAccessKeyId,
      secretKey: _rustFSSecretKey,
      bucket: bucket,
      region: region,
      uploadDst: path,
      expires: expirationDuration,
      maxFileSize: maxFileSize,
      public: public,
      host: host,
    );
  }

  @override
  Future<bool> verifyDirectFileUpload({
    required Session session,
    required String path,
  }) async {
    return fileExists(session: session, path: path);
  }
}
