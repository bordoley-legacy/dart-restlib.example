library restlib.example;

import "dart:async";
import "dart:io";

import "package:logging/logging.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/data.media_ranges.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/http.future_responses.dart";
import "package:restlib_core/multipart.dart";
import "package:restlib_core/net.dart";

import "package:restlib_http_connector/connector.dart";
import "package:restlib_server/io.dart";
import "package:restlib_server/server.dart";

import "package:restlib_common/collections.dart";
import "package:restlib_common/collections.immutable.dart";
import "package:restlib_common/io.dart";
import "package:restlib_common/objects.dart";

import "example.blog.dart";

part "src/echo_resource.dart";
part "src/file_resource.dart";
part "src/form_based_authentication.dart";
part "src/session_authenticated_resource.dart";

void main() {
  hierarchicalLoggingEnabled = false;
  Logger.root.level = Level.FINEST;
  Logger.root.onRecord.forEach((final LogRecord record) =>
      print(record.message));

  final Directory fileDirectory =
      new Directory(Platform.environment["HOME"]);

  final UserAgent server = UserAgent.parser.parseValue("restlibExample/1.0");

  Request requestFilter(final Request request) =>
      requestMethodOverride(request);

  Response responseFilter(final Response response) =>
      response.with_(
          server: server);

  final ImmutableBiMap<_UserPwd, String> userPwdToSid =
      EMPTY_BIMAP.put(new _UserPwd("test", "test"), "1234");

  final Router router =
      Router.EMPTY
        .addAll(blog(PATH.parseValue("/example/blog")))
        .addAll(
          [ioFormBasedAuthResource(ROUTE.parseValue("/example/login"), userPwdToSid),
           sessionAuthenticatedEchoResource(
               ROUTE.parseValue("/example/echo/*session"),
               URI_.parseValue("/example/login"),
               (final Request request, final String sid) =>
                   userPwdToSid.inverse[sid].isNotEmpty),
           ioAuthenticatedEchoResource(ROUTE.parseValue("/example/echo/*authenticated")),
           ioEchoResource(ROUTE.parseValue("/example/*echo")),
           ioFileResource(fileDirectory, URI_.parseValue("/example"))]);

  final Application app =
      new Application(
          router,
          requestFilter : requestFilter,
          responseFilter : responseFilter);

  HttpServer
    .bind("0.0.0.0", 8080)
    .then(httpServerListener((final Request request) => app, "http"));
}