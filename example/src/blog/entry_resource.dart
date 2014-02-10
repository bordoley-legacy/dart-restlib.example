part of restlib.example;

Future<Request<AtomEntry<String>>> parseAtomXmlEntry(final Request request, final Stream<List<int>> msgStream) {
  
}

Future<Request<AtomEntry<String>>> parseFormEntry(final Request request, final Stream<List<int>> msgStream) =>
    parseForm(request, msgStream)
      .then((final Request<Form> request) {
        final Form form = request.entity.value;
        return request.with_(
              entity: atomEntryFromAssociative(form));
      });

Future<Request<AtomEntry<String>>> parseHtmlEntry(final Request request, final Stream<List<int>> msgStream) {
  
}

Future<Request<AtomEntry<String>>> parseJsonEntry(final Request request, final Stream<List<int>> msgStream) =>
    parseString(request, msgStream)
      .then((final Request<String> request) {
        final Map<String, String> json = JSON.decode(request.entity.value);
        return request.with_(entity: atomEntryFromAssociative(new Dictionary.wrapMap(json)));
      });

AtomEntry<String> atomEntryFromAssociative(final Associative<String,String> assoc) => 
    // FIXME: use IRI_, but its crashing right now.
    new AtomEntry(URI_.parseValue(assoc["id"].first), assoc["title"].first, DateTime.parse(assoc["updated"].first), content: assoc["content"].first);  

Option<RequestParser> entryParserProvider(final ContentInfo contentInfo) =>
    contentInfo.mediaRange.map((final MediaRange mr) {
      if (mr == APPLICATION_JSON) {
        return parseJsonEntry;
      } else if (mr == APPLICATION_ATOM_XML_ENTRY) {
        return parseAtomXmlEntry;
      } else if (mr == APPLICATION_WWW_FORM) {
        return parseFormEntry;
      } else if (mr == TEXT_HTML) {
        return parseHtmlEntry;
      } else {
        return null;
      }
    });

String writeAtomLink(final AtomLink link) =>
    "<link ${link.rel.map((final String rel) => 
        "rel=\"$rel\"").orElse("")} ${link.type.map((final MediaRange mr) => 
            "type=\"$mr\"").orElse("")} href=\"${link.href}\"/>"; 

Future writeAtomXMLEntry(final Request request, final Response<AtomEntry<String>> response, final StreamSink<List<int>> msgSink) {
  final AtomEntry<String> entry = response.entity.value;
  final String atom =
"""<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom">
  <id>${entry.id}</id>
  <title>${entry.title}</title>
  ${entry.published.map((final DateTime date) =>
      "<published>$date</published>").orElse("")}
  <updated>${entry.updated}</updated>

  <content type="text">${entry.content.value}</content>

  ${entry.links.map(writeAtomLink).join("\n  ")}
</entry>
""";

  return writeString(request, response.with_(entity: atom), msgSink);
}

Future writeFormEntry(final Request request, final Response<AtomEntry<String>> response, final StreamSink<List<int>> msgSink) {
  final AtomEntry<String> entry = response.entity.value;
  final Form form = 
      Form.EMPTY
        .put("id", entry.id.toString())
        .put("title", entry.title)
        .put("update", entry.updated.toString())
        .put("content", entry.content.value);
  final Response<String> formResponse = response.with_(entity:form.toString());
  return writeString(request, formResponse, msgSink);
}

Future writeHtmlEntry(final Request request, final Response<AtomEntry<String>> response, final StreamSink<List<int>> msgSink) {
  final AtomEntry<String> entry = response.entity.value;
  final String html = 
"""<!DOCTYPE html>
<html>
  <head>
    <title>${entry.title}</title>
    ${entry.links.map(writeAtomLink).join("\n    ")}
  </head>
  <body>
    <div id="${entry.id}" class="hentry">
      <h1 class="entry-title">${entry.title}</h1>        
      <div>
        Updated: <abbr class="updated" title="${entry.updated}">${entry.updated}</abbr>
      </div>
      ${entry.published.map((final DateTime published) =>
          """"<div>
        Created: <abbr class="published" title="${published}">${published}</abbr>
      </div>""").orElse("")}
      
      <p class="entry-content">${entry.content.value}</p>
    </div>
  </body>
</html>""";
  final Response<String> htmlResponse = response.with_(entity:html);
  return writeString(request, htmlResponse, msgSink);
}

Future writeJsonEntry(final Request request, final Response<AtomEntry<String>> response, final StreamSink<List<int>> msgSink) {
  final AtomEntry<String> entry = response.entity.value;
  final Map map = new Map()
    ..["id"] = entry.id.toString()
    ..["title"] = entry.title
    ..["update"] = entry.updated.toString()
    ..["content"] = entry.content.value;
  final Response<String> jsonResponse = response.with_(entity:JSON.encode(map));
  return writeString(request, jsonResponse, msgSink);
}

Option<Dictionary<MediaRange, ResponseWriter>> entryResponseWriters(final Request request, final Response response) {
  final entity = response.entity.value;
  
  if (entity is AtomEntry) {
    return new Option(
        Persistent.EMPTY_DICTIONARY
          .put(APPLICATION_JSON, new ResponseWriter.forContentType(APPLICATION_JSON, writeJsonEntry))
          .put(APPLICATION_ATOM_XML, new ResponseWriter.forContentType(APPLICATION_ATOM_XML, writeAtomXMLEntry))
          .put(TEXT_HTML, new ResponseWriter.forContentType(TEXT_HTML, writeHtmlEntry))
          .put(APPLICATION_WWW_FORM, new ResponseWriter.forContentType(APPLICATION_WWW_FORM, writeFormEntry)));
  }
  
  return Option.NONE;
}

IOResource entryResource(final BlogStore blogStore, final Route route) {
  final Dictionary<String, MediaRange> extensionMap = 
      Persistent.EMPTY_DICTIONARY.putAllFromMap(
          {"html" : TEXT_HTML,
            "atom" : APPLICATION_ATOM_XML,
            "form" : APPLICATION_WWW_FORM,
            "json" : APPLICATION_JSON});
  
  // FIXME: add methods to route to allow for validating parameters.
  final Resource<AtomEntry<String>> resource = 
      new Resource.uniform(
          new _EntryResourceDelegate(null, blogStore, extensionMap, route));
  return new IOResource.conneg(
      resource,
      entryParserProvider, 
      new ResponseWriterProvider.onContentType(entryResponseWriters));
}

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



class _EntryResourceDelegate extends UniformResourceDelegate<AtomEntry<String>> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  
  final Iterable<MediaRange> acceptedMediaRanges;
  final BlogStore blogStore;
  final Dictionary<String, MediaRange> extensionMap;
  final Route route;
  
  final RequestFilter extensionFilter = 
      requestExtensionAsAccept(
          new Dictionary.wrapMap(
              {"html" : TEXT_HTML,
                "atom" : APPLICATION_ATOM_XML,
                "json" : APPLICATION_JSON,
                "form" : APPLICATION_WWW_FORM}));
  
  _EntryResourceDelegate(
      this.acceptedMediaRanges, this.blogStore,
      this.extensionMap, this.route);
  
  Future<Response> _processRequest(final Request request, Future<Response> handler(final Pair<String, String> userAndItemId)) {
    final Dictionary<String, String> parameters = route.parsePathParameters(request.uri);
    final Option<String> userid = parameters["userid"];
    final Option<String> itemid = parameters["itemid"];
    
    return first(zip(userid, itemid)).map(handler).orCompute(() => 
            throw new ArgumentError("Request URI path doesn't match Route pattern"));
  }
  
  AtomEntry atomEntryFromBlogEntry(final BlogEntry entry, final URI uri) =>
      new AtomEntry(generateId(uri, entry.created), entry.title, entry.updated, 
          content: entry.content,
          links: generateLinks(uri));
  
  Request filterRequest(Request request) =>
      extensionFilter(request);
  
  ImmutableSequence<AtomLink> generateLinks(final URI uri) =>
      AtomLink.alternativeLinks(uri, this.extensionMap)
        .add(new AtomLink.self(uri))
        .add(new AtomLink.edit(uri));
  
  Future<Response> delete(final Request request) =>
      _processRequest(request, (final Pair<String, String> userAndItemId) =>
            blogStore.deleteBlogEntry(userAndItemId.fst, userAndItemId.snd)
              .map((_) =>
                  SUCCESS_NO_CONTENT)
              .orElse(CLIENT_ERROR_NOT_FOUND));

  Future<Response> get(final Request request) =>
      _processRequest(request, (final Pair<String, String> userAndItemId) => 
            blogStore.getBlogEntry(userAndItemId.fst, userAndItemId.snd)
              .map((final BlogEntry blogEntry) =>
                  new Future.value(
                      // FIXME: include the entity
                      new Response(
                          Status.SUCCESS_OK,
                          entity: atomEntryFromBlogEntry(blogEntry, request.uri),
                          lastModified: blogEntry.updated)))
              .orElse(CLIENT_ERROR_NOT_FOUND));

  Future<Response> put(final Request<AtomEntry<String>> request) =>
      _processRequest(request, (final Pair<String, String> userAndItemId) {
        // FIXME: parse from request atom body
        final String newContent = request.entity.value.content.orElse("");
        final String newTitle = request.entity.value.title;
        
        final BlogEntry result =
            blogStore.getBlogEntry(userAndItemId.fst, userAndItemId.snd)
              .map((final BlogEntry blogEntry) =>
                  new BlogEntry(blogEntry.created, newContent, blogEntry.itemId, newTitle, new DateTime.now(), blogEntry.userId))
              .orCompute(() {
                final DateTime now = new DateTime.now();   
                return new BlogEntry(now, newContent, userAndItemId.snd, newTitle, now, userAndItemId.fst);
              });
        blogStore.putBlogEntry(result);
        
        // FIXME: include the entity
        return new Future.value(
            new Response(Status.SUCCESS_OK,
                entity: atomEntryFromBlogEntry(result, request.uri),
                lastModified: result.updated));
      });
}