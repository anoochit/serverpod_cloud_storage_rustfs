![Serverpod banner](https://github.com/serverpod/serverpod/raw/main/misc/images/github-header.webp)

## What is Serverpod?

Serverpod is an open-source, scalable app server, written in Dart for the Flutter community. Check it out! [Serverpod.dev](https://serverpod.dev)

## What is RustFS?

[RustFS](https://github.com/rustfs/rustfs) is an open-source, S3-compatible object storage server.
It can be used as a drop-in replacement for AWS S3, MinIO, or other S3-compatible services, making it ideal for:

* Local development
* On-premise deployments
* Private cloud environments
* Cost-effective production setups

## Using RustFS (S3-compatible storage)

This section shows how to set up a storage using **RustFS**, an S3-compatible object storage. Before you write your Dart code, you need to set up a RustFS instance and create a bucket.

If you plan to expose files publicly, you may also want to place RustFS behind a reverse proxy or CDN (such as Nginx or Cloudflare) so you can use a custom domain and your own SSL certificate.

Next, generate an **access key** and **secret key** in RustFS. Add these credentials to your Serverpod password file (`RustFSAccessKeyId` and `RustFSSecretKey`) or provide them as environment variables (`SERVERPOD_RUSTFS_ACCESS_KEY_ID` and `SERVERPOD_RUSTFS_SECRET_KEY`).

When your RustFS setup is ready, include the RustFS client package in your `pubspec.yaml` file and import it in your `server.dart` file. Serverpod will communicate with RustFS through the S3 API, so no additional storage-specific code changes are required beyond configuring the custom endpoint.

```yaml
dependencies:
  serverpod_cloud_storage_rustfs:
    git:
      url: https://github.com/anoochit/serverpod_cloud_storage_rustfs.git
```

```dart
import 'package:serverpod_cloud_storage_rustfs/serverpod_cloud_storage_rustfs.dart'
    as rustfs;
```

After creating your Serverpod, you add a cloud storage configuration. If you want to replace the default public or private storages, set the `storageId` to `public` or `private`. You should add the cloud storage **before starting your pod**.

When using **RustFS**, you configure it through the same `S3CloudStorage` class, but point it to your RustFS endpoint instead of AWS. If your RustFS instance is exposed via a custom domain (for example, behind Nginx or a CDN), set the `publicHost` accordingly.

```dart
pod.addCloudStorage(
  rustfs.RustFSCloudStorage(
    serverpod: pod,
    storageId: 'public',
    public: true,
    region: 'us-west-2',
    bucket: 'mybucket',
    host: 'd0beb585a210.ngrok-free.app', // RustFS endpoint
    publicHost: 'd0beb585a210.ngrok-free.app', // RustFS public host
  ),
);
```

> **Note** For S3-compatible services like RustFS, the `region` value is not validated and can be set to any valid AWS region string.

### Credentials configuration

For the storage configuration to work, you must also add your **RustFS access key and secret key** to the `passwords.yaml` file. Serverpod reuses AWS-style credential names for all S3-compatible storage providers.

```yaml
shared:
  RustFSAccessKeyId: 'RUSTFS_ACCESS_KEY'
  RustFSSecretKey: 'RUSTFS_SECRET_KEY'
```

You generate these credentials from your RustFS configuration (or environment variables if running via Docker). Once configured, Serverpod will communicate with RustFS using the standard S3 API, without requiring any further code changes.

## How to upload a file

Serverpod sets up a **public** and **private** file storage by default using the database. You can replace these defaults or add additional storage configurations backed by **RustFS** or any other S3-compatible service.

Once RustFS is configured using `RustFSCloudStorage`, file uploads work exactly the same as with AWS S3.

## Server-side code

Uploading a file requires a few steps. First, you create an **upload description** on the server and pass it to the client. This description grants temporary permission for the client to upload a file directly to RustFS.

In the simplest case, you can allow uploads to any path, though in production you should usually restrict allowed paths.

```dart
Future<String?> getUploadDescription(Session session, String path) async {
  return await session.storage.createDirectFileUploadDescription(
    storageId: 'public',
    path: path,
  );
}
```

After the upload is completed, you should **verify the upload**.
When uploading directly to third-party storage such as **RustFS**, this is the only reliable way to know whether the upload succeeded or was canceled.

```dart
Future<bool> verifyUpload(Session session, String path) async {
  return await session.storage.verifyDirectFileUpload(
    storageId: 'public',
    path: path,
  );
}
```

## Client-side code

On the client side, you first request the upload description from your server. Then you upload the file using the provided upload information.

You can upload from either a `Stream` or a `ByteData` object. For large files, using a `Stream` is recommended to avoid holding the entire file in memory.

Finally, verify the upload with the server.

```dart
var uploadDescription =
    await client.myEndpoint.getUploadDescription('myfile');

if (uploadDescription != null) {
  var uploader = FileUploader(uploadDescription);
  await uploader.upload(myStream);
  var success = await client.myEndpoint.verifyUpload('myfile');
}
```

## File path best practices (important for RustFS)

In a real-world application, file paths should typically be **generated on the server**, not by the client.

For compatibility with **RustFS and S3-style object storage**:

* Do **not** use a leading slash
* Use only standard characters, numbers, and `/`
* Avoid spaces and special characters

Example of a valid path:

```dart
'profile/$userId/images/avatar.png'
```

## Accessing stored files

You can easily check whether a file exists, retrieve it, or generate a public URL.

### Check if a file exists

```dart
var exists = await session.storage.fileExists(
  storageId: 'public',
  path: 'my/file/path',
);
```

### Get a public URL (public storage only)

If the file is stored in a **public** RustFS bucket, it can be accessed via a URL.
If you configured `publicHost`, the returned URL will use your custom domain.

```dart
var url = await session.storage.getPublicUrl(
  storageId: 'public',
  path: 'my/file/path',
);
```

### Retrieve a file on the server

You can also retrieve the file directly from your server code.

```dart
var myByteData = await session.storage.retrieveFile(
  storageId: 'public',
  path: 'my/file/path',
);
```
