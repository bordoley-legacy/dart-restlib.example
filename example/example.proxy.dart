library example.proxy;

import "dart:async";

import "package:restlib_client/client.dart";
import "package:restlib_common/collections.dart";
import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/http.future_responses.dart";
import "package:restlib_core/http.methods.dart";
import "package:restlib_core/net.dart";
import "package:restlib_server/io.dart";
import "package:restlib_server/server.dart";

class ProxyResource extends ForwardingResource<Stream<List<int>>> implements IOResource {
  final Resource delegate;

  ProxyResource(final Route route, final RestClient client) :
    delegate = new Resource.uniform(new _ProxyResourceDelegate(route, client));

  Future<Request<Stream<List<int>>>> parse(Request request, Stream<List<int>> msgStream) =>
      new Future.value(request.with_(entity: msgStream));

  Future write(Request request, Response response, StreamSink<List<int>> msgSink) =>
      response.entity
        .map((final Stream<List<int>> entity) =>
            msgSink.addStream(entity))
        .orCompute(() =>
            new Future.value());
}

class _ProxyResourceDelegate extends UniformResourceDelegate<String> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Route route;
  final RestClient _client;

  _ProxyResourceDelegate(this.route, this._client);

  Future<Response> get(final Request request) =>
      Form.parser.parse(request.uri.query)
        .flatMap((final Form form) =>
            first(form["uri"]).flatMap(URI.parser.parse).map((final URI uri) =>
                _client.call(new Request(GET, uri)))
        ).orElse(CLIENT_ERROR_BAD_REQUEST);
}