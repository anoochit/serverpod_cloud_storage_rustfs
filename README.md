![Serverpod banner](https://github.com/serverpod/serverpod/raw/main/misc/images/github-header.webp)

## What is Serverpod?

Serverpod is an open-source, scalable application server written in Dart, designed specifically for the Flutter ecosystem. It provides a productive backend framework with built-in tooling for APIs, databases, authentication, and file storage.

Learn more at [serverpod.dev](https://serverpod.dev).

## What is RustFS?

[RustFS](https://github.com/rustfs/rustfs) is an open-source, S3-compatible object storage server. It can be used as a drop-in replacement for AWS S3, MinIO, and other S3-compatible services, making it a flexible and cost-effective storage solution for many environments.

RustFS is well suited for:

* Local development
* On-premise deployments
* Private cloud environments
* Cost-effective production setups

## Using RustFS (S3-compatible storage)

This section explains how to configure **RustFS** as a storage backend for Serverpod. Since RustFS implements the S3 API, Serverpod can communicate with it using the same mechanisms as AWS S3.

Before writing any Dart code, you need to:

1. Set up a RustFS instance
2. Create a bucket
3. Generate an **access key** and **secret key**

If you plan to expose files publicly, it is recommended to run RustFS behind a reverse proxy or CDN (such as Nginx or Cloudflare). This allows you to use a custom domain and manage TLS/SSL certificates more easily.

### Credentials setup

After creating your access key and secret key in RustFS, add them to your Serverpod password configuration.

You can either:

* Add them to your `passwords.yaml` file, or
* Provide them as environment variables

Serverpod uses AWS-style credential names for all S3-compatible storage providers.

```yaml
shared:
  RustFSAccessKeyId: 'RUSTFS_ACCESS_KEY'
  RustFSSecretKey: 'RUSTFS_SECRET_KEY'
```

Alternatively, you can use environment variables:

* `SERVERPOD_RUSTFS_ACCESS_KEY_ID`
* `SERVERPOD_RUSTFS_SECRET_KEY`

### Adding the RustFS client package

Include the RustFS cloud storage integration in your `pubspec.yaml` file:

```yaml
dependencies:
  serverpod_cloud_storage_rustfs:
    git:
      url: https://github.com/anoochit/serverpod_cloud_storage_rustfs.git
```

Then import it in your `server.dart` file:

```dart
import 'package:serverpod_cloud_storage_rustfs/serverpod_cloud_storage_rustfs.dart'
    as rustfs;
```

### Configuring cloud storage

After creating your Serverpod instance, add a cloud storage configuration **before starting the pod**.

If you want to replace the default `public` or `private` storage, set `storageId` accordingly.

When using **RustFS**, you configure storage in the same way as S3, but point it to your RustFS endpoint instead of AWS. If RustFS is exposed via a custom domain, set `publicHost` to that domain.

```dart
pod.addCloudStorage(
  rustfs.RustFSCloudStorage(
    serverpod: pod,
    storageId: 'public',
    public: true,
    region: 'us-west-2',
    bucket: 'mybucket',
    host: 'd0beb585a210.ngrok-free.app', // RustFS endpoint
    publicHost: 'd0beb585a210.ngrok-free.app', // Public host
  ),
);
```

> **Note**
> For S3-compatible services such as RustFS, the `region` value is not strictly validated and can be set to any valid AWS region string.

## Uploading files

By default, Serverpod provides **public** and **private** file storage backed by the database. These defaults can be replaced or extended using RustFS or any other S3-compatible storage service.

Once RustFS is configured via `RustFSCloudStorage`, file uploads work exactly the same as with AWS S3.

## Server-side code

Uploading a file involves two main steps:

1. Creating an **upload description** on the server
2. Verifying the upload after it completes

The upload description grants the client temporary permission to upload a file directly to RustFS.

```dart
Future<String?> getUploadDescription(Session session, String path) async {
  return await session.storage.createDirectFileUploadDescription(
    storageId: 'public',
    path: path,
  );
}
```

After the upload finishes, you must verify it. When uploading directly to third-party storage like RustFS, this is the only reliable way to determine whether the upload succeeded or was canceled.

```dart
Future<bool> verifyUpload(Session session, String path) async {
  return await session.storage.verifyDirectFileUpload(
    storageId: 'public',
    path: path,
  );
}
```

## Client-side code

On the client, you first request an upload description from the server. Then you upload the file using the provided information.

Uploads can be performed using either a `Stream` or a `ByteData` object. For large files, using a `Stream` is recommended to avoid loading the entire file into memory.

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

In production applications, file paths should typically be **generated on the server**, not provided by the client.

For compatibility with **RustFS and S3-style object storage**, follow these rules:

* Do **not** use a leading slash
* Use only alphanumeric characters and `/`
* Avoid spaces and special characters

Example of a valid file path:

```dart
'profile/$userId/images/avatar.png'
```

## Accessing stored files

Serverpod provides convenient APIs for checking file existence, retrieving files, and generating public URLs.

### Check if a file exists

```dart
var exists = await session.storage.fileExists(
  storageId: 'public',
  path: 'my/file/path',
);
```

### Get a public URL (public storage only)

Files stored in a **public** RustFS bucket can be accessed via a URL. If `publicHost` is configured, the returned URL will use your custom domain.

```dart
var url = await session.storage.getPublicUrl(
  storageId: 'public',
  path: 'my/file/path',
);
```

### Retrieve a file on the server

You can also retrieve the file directly in server-side code:

```dart
var myByteData = await session.storage.retrieveFile(
  storageId: 'public',
  path: 'my/file/path',
);
```
