library restlib.example.blog;

import "dart:async";
import "dart:convert";
import "dart:math";

import "package:restlib_atom/atom.dart";

import "package:restlib_common/collections.dart";
import "package:restlib_common/collections.immutable.dart";
import "package:restlib_common/collections.mutable.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/data.media_ranges.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/http.future_responses.dart";
import "package:restlib_core/net.dart";

import "package:restlib_server/io.dart";
import "package:restlib_server/server.dart";

part "src/blog/entry_parsers.dart";
part "src/blog/entry_resource.dart";
part "src/blog/entry_serializers.dart";
part "src/blog/feed_resource.dart";
part "src/blog/feed_serializers.dart";
part "src/blog/blog_store.dart";

Iterable<IOResource> blog(final Path basePath) {
  final _BlogStore blogStore = new _BlogStore();
  
  final ImmutableDictionary<String, MediaRange> feedExtensionMap = 
      EMPTY_DICTIONARY.putAllFromMap(
                {"html" : TEXT_HTML,
                  "atom" : APPLICATION_ATOM_XML,
                  "json" : APPLICATION_JSON});
  
  final ImmutableDictionary<String, MediaRange> entryExtensionMap = 
      feedExtensionMap.put("form", APPLICATION_WWW_FORM);

  final Route feedRoute = Route.EMPTY.addAll(basePath).add(":userid");
  final Route entryRoute = feedRoute.add("blog").add(":itemid");
  
  return EMPTY_SEQUENCE
      .add(entryResource(blogStore, entryExtensionMap, entryRoute))
      .add(feedResource(blogStore, feedExtensionMap, entryExtensionMap, feedRoute));
}

IOResource entryResource(final _BlogStore blogStore, final Dictionary<String, MediaRange> extensionMap, final Route route) {
  // FIXME: add methods to route to allow for validating parameters.
  final Resource<AtomEntry<String>> resource = 
      new Resource.uniform(
          new _EntryResourceDelegate(blogStore, extensionMap, route));
  return new IOResource.conneg(
      resource,
      entryParserProvider, 
      new ResponseWriterProvider.onContentType(entryResponseWriters));
}

Option<Dictionary<MediaRange, ResponseWriter>> feedResourceResponseWriters(final Request request, final Response response) =>
    computeIfEmpty(entryResponseWriters(request,response), () =>
        feedResponseWriters(request,response));

IOResource feedResource(final _BlogStore blogStore, final Dictionary<String, MediaRange> feedExtensionMap, final Dictionary<String, MediaRange> entryExtensionMap, final Route route) {
  final Resource<AtomEntry<String>> resource = 
        new Resource.uniform(
            new _FeedResourceDelegate(blogStore, feedExtensionMap, entryExtensionMap, route));
  return new IOResource.conneg(
      resource,
      entryParserProvider, 
      new ResponseWriterProvider.onContentType(feedResourceResponseWriters));
}

ImmutableSequence<AtomLink> generateLinks(final URI uri, final Dictionary<String, MediaRange> extensionMap) =>
    AtomLink.alternativeLinks(uri, extensionMap)
      .add(new AtomLink.self(uri))
      .add(new AtomLink.edit(uri));

IRI generateId(final URI uri, final DateTime created) =>
    uri.authority
      .map((final Authority authority) =>
          authority.host.fold(
              (final DomainName name) =>
                  new URI.tag(authorityDomain: name , date: created, specificPath: uri.path), 
              (final IPAddress ip) =>
                  new URI.tag(authorityAddress: ip, date: created, specificPath: uri.path)))
      .orCompute(() =>
          throw new ArgumentError("URI must include an authority component."));