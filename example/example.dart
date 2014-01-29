library restlib.example;

import "dart:async";
import "dart:io";

import "package:logging/logging.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/multipart.dart";
import "package:restlib_core/net.dart";

import "package:restlib_http_connector/connector.dart";
import "package:restlib_server/io.dart";
import "package:restlib_server/server.dart";

import "package:restlib_common/collections.dart";
import "package:restlib_common/collections.immutable.dart";
import "package:restlib_common/io.dart";
import "package:restlib_common/objects.dart";

part "src/echo_resource.dart";
part "src/file_resource.dart";

void main() {       
  hierarchicalLoggingEnabled = false;
  Logger.root.level = Level.FINEST;
  Logger.root.onRecord.forEach((final LogRecord record) => 
      print(record.message));
  
  final Directory fileDirectory = 
      new Directory(Platform.environment["HOME"]);
  
  final UserAgent server = USER_AGENT.parse("restlibExample/1.0").value;
  
  Request requestFilter(final Request request) =>
      requestMethodOverride(request);
   
  Response responseFilter(final Response response) =>
      response.with_(
          server: server);

  final Application app = 
      new Application(
          [ioAuthenticatedEchoResource(ROUTE.parse("/example/echo/authenticated/*path").value),
           ioEchoResource(ROUTE.parse("/example/echo/*path").value),
           ioFileResource(fileDirectory, URI_.parse("/example/file").value)],
           requestFilter : requestFilter,
           responseFilter : responseFilter);
  HttpServer
    .bind("0.0.0.0", 8080)
    .then(httpServerListener((final Request request) => app, "http"));
}