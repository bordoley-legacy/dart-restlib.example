library example;

import "dart:async";
import "dart:io" as io;

import "package:logging/logging.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/data.media_ranges.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/http.future_responses.dart";
import "package:restlib_core/http.methods.dart";
import "package:restlib_core/http.statuses.dart" as Status;
import "package:restlib_core/multipart.dart";
import "package:restlib_core/net.dart";

import "package:restlib_client/client.dart";

import "package:restlib_http_connector/connector.dart";
import "package:restlib_http_connector/connector.http_1_1.dart";
import "package:restlib_server/io.dart";
import "package:restlib_server/server.dart";
import "package:restlib_server/io.dart" as serverIO;

import "package:restlib_common/collections.dart";
import "package:restlib_common/collections.immutable.dart";
import "package:restlib_common/io.dart";
import "package:restlib_common/objects.dart";
import "package:restlib_common/preconditions.dart";

import "example.blog.dart";
import "example.proxy.dart";

part "src/echo_resource.dart";
part "src/file_resource.dart";
part "src/form_based_authentication.dart";
part "src/session_authenticated_resource.dart";

void main() {
  hierarchicalLoggingEnabled = false;
  Logger.root.level = Level.FINEST;
  Logger.root.onRecord.forEach((final LogRecord record) =>
      print(record.message));

  final io.Directory fileDirectory =
      new io.Directory(io.Platform.environment["HOME"]);

  final UserAgent server = UserAgent.parser.parseValue("restlibExample/1.0");

  Request requestFilter(final Request request) =>
      requestMethodOverride(request);

  Response responseFilter(final Response response) =>
      response.with_(
          server: server);

  final ImmutableBiMap<_UserPwd, String> userPwdToSid =
      EMPTY_BIMAP.put(new _UserPwd("test", "test"), "1234");

  final HttpClient client = new Http_1_1_Client((final URI uri) {
      checkNotNull(uri);
      checkArgument(uri.authority.isNotEmpty);
      checkArgument(uri.scheme.isNotEmpty);

      final String host = uri.authority.value.host.value.toString();
      final Option<int> port = uri.authority.value.port;

      if (uri.scheme == "http") {
        return io.Socket.connect(host, port.orElse(80));
      } else if (uri.scheme == "https") {
        return io.Socket.connect(host, port.orElse(443));
      } else {
        throw new ArgumentError("invalid scheme: $uri.scheme");
      }
    });

  final Router router =
      Router.EMPTY
        .addAll(blog(Path.parser.parseValue("/example/blog")))
        .addAll(
          [ioFormBasedAuthResource(Route.parser.parseValue("/example/login"), userPwdToSid),
           sessionAuthenticatedEchoResource(
               Route.parser.parseValue("/example/echo/*session"),
               URI.parser.parseValue("/example/login"),
               (final Request request, final String sid) =>
                   userPwdToSid.inverse[sid].isNotEmpty),
           ioAuthenticatedEchoResource(Route.parser.parseValue("/example/echo/*authenticated")),
           ioEchoResource(Route.parser.parseValue("/example/*echo")),
           ioFileResource(fileDirectory, URI.parser.parseValue("/example")),
           new ProxyResource(Route.parser.parseValue("/example/proxy"), client)]);

  final Application app =
      new Application(
          router,
          requestFilter : requestFilter,
          responseFilter : responseFilter);

  io.HttpServer
    .bind("0.0.0.0", 8080)
    .then(httpServerListener((final Request request) => app, "http"));
}