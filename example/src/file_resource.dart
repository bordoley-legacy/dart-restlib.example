part of example;

MediaRange mediaRangeForFile(final file) =>
    new Option(lookupMimeType(file.path))
      .map(MediaRange.parser.parseValue)
      .orElse(APPLICATION_OCTET_STREAM);

class _FileResourceDelegate extends UniformResourceDelegate<FileSystemEntity> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Route route;
  final Directory _base;

  _FileResourceDelegate(this._base, final URI path):
    route = Route.parser.parseValue(path.path.toString() + "/*file");

  Future<Response> get(final Request request) {
    final Dictionary<String, String> params =
        route.parametersFromPath(request.uri.path);

    return params["file"]
      .map((final String path) {
        // FIXME use URI component API instead of Uri.decode
        final Path relativeFilePath = Path.EMPTY.addAll(Path.parser.parseValue(path).skip(1));
        final String filePath = posix.join(_base.path, Uri.decodeComponent(relativeFilePath.toString()));
        return FileSystemEntity.type(filePath)
            .then((final FileSystemEntityType type) =>
                new PatternMatcher<FileSystemEntity>(
                    [inCaseOf(equals(FileSystemEntityType.FILE), (_) =>
                        new ByteRangeableFile(filePath)),
                     inCaseOf(equals(FileSystemEntityType.DIRECTORY), (_) =>
                         new Directory(filePath))])(type)
                  .map((final FileSystemEntity entity) {
                      final Future<int> lengthLookup = (entity is File) ? entity.length() : new Future.value(-1);

                      return Future.wait([lengthLookup, entity.stat()])
                        .then((final List results) =>
                            new Response(
                                Status.SUCCESS_OK,
                                entity : entity,
                                contentInfo : (entity is File) ?
                                    new ContentInfo(
                                      length: results[0],
                                      mediaRange: mediaRangeForFile(entity)) : ContentInfo.NONE,
                                lastModified : results[1].modified));
                  }).orElse(CLIENT_ERROR_NOT_FOUND));
      }).orCompute(() =>
          new Future.error("route does not include a *file parameter"));
  }
}

Future writeDirectory(final Request request, final Response<Directory> response, final StreamSink<List<int>> msgSink) {
  final StringBuffer buffer =
      new StringBuffer("<!DOCTYPE html>\n<html><head>\n</head>\n<body>\n");

  // Assume at this point that the entity is guaranteed to exist
  return response.entity.value
      .list(recursive: false, followLinks: false)
        .forEach((final FileSystemEntity entity) {
          final String path = entity.path.replaceFirst(entity.parent.path, "");

          // FIXME: Use URI codec instead of URI.encode
          final String uriPath = path.split("/").map(Uri.encodeComponent).join("/");

          buffer.write("<a href=\"${request.uri.toString()}${uriPath}\">${path}</a><br/>\n");
        }).then((_) =>
            buffer.write("</body>\n</html>"))
        .then((_) =>
            writeString(request, response.with_(entity:buffer.toString()), msgSink));
  }

Option<Dictionary<MediaRange, ResponseWriter>> responseWriters(final Request request, final Response response) {
  MediaRange mediaRange;
  ResponseEntityWriter writer;
  final entity = response.entity.value;

  if (entity is File) {
    mediaRange = mediaRangeForFile(entity);
    writer = writeFile;
  } else if (entity is Directory) {
    mediaRange = TEXT_HTML;
    writer = writeDirectory;
  } else if (entity is ByteStreamableMultipart) {
    mediaRange = response.contentInfo.mediaRange.value;
    writer = writeMultipart;
  } else {
    mediaRange = TEXT_PLAIN;
    writer = writeString;
  }

  return new Option(
      EMPTY_DICTIONARY.put(
          mediaRange, new ResponseWriter.forContentType(mediaRange, writer)));
}

IOResource ioFileResource(final Directory directory, final URI path) {
  final Resource<FileSystemEntity> resource =
      new Resource.uniform(new _FileResourceDelegate(directory, path));

  final Resource<FileSystemEntity> rangeResource =
      new Resource.byteRangeResource(resource);

  final ResponseWriterProvider responseWriterProvider =
      new ResponseWriterProvider.onContentType(responseWriters);

  return new IOResource.conneg(rangeResource, (_) => Option.NONE, responseWriterProvider);
}


// FIXME: These really belong in some sort of common library.
// However restlib.server and restlib.server.io have no dependency on dart:io and
// restlib.connector seems like a weird place to put them
class ByteRangeableFile
    extends NoSuchMethodForwarder
    implements File, ByteRangeable {

  ByteRangeableFile(final String path) : super(new File(path));

  File get delegate =>
      super.delegate;

  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Future writeFile(final Request request, final Response<File> response, final StreamSink<List<int>> msgSink) =>
    msgSink.addStream(
        response.contentInfo.range
          // Assume the type is ByteContentRange and let the code exception with internal server error
          .map((final BytesContentRange range) {
            // Assume the range is a ByteRangeResp at this point
            final int firstBytePos = range.rangeResp.left.value.firstBytePosition;
            final int lastBytePos =  range.rangeResp.left.value.lastBytePosition;

            // Assume at this point that the entity is guaranteed to exist
            return response.entity.value.openRead(firstBytePos, lastBytePos);
          }).orCompute(() =>
              // Assume at this point that the entity is guaranteed to exist
              response.entity.value.openRead()));
