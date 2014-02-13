part of restlib.example;

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

AtomEntry atomEntryFromBlogEntry(final BlogEntry entry, final URI uri, final Dictionary<String, MediaRange> extensionMap) =>
    new AtomEntry(generateId(uri, entry.created), entry.title, entry.updated, 
        content: entry.content,
        links: generateLinks(uri, extensionMap));

ImmutableSequence<AtomLink> generateLinks(final URI uri, final Dictionary<String, MediaRange> extensionMap) =>
    AtomLink.alternativeLinks(uri, extensionMap)
      .add(new AtomLink.self(uri))
      .add(new AtomLink.edit(uri));

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
    final Dictionary<String, String> parameters = route.parametersFromPath(request.uri.path);
    final Option<String> userid = parameters["userid"];
    final Option<String> itemid = parameters["itemid"];
    
    return first(zip(userid, itemid)).map(handler).orCompute(() => 
            throw new ArgumentError("Request URI path doesn't match Route pattern"));
  }
  
  Request filterRequest(Request request) =>
      extensionFilter(request);
  
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
                          entity: atomEntryFromBlogEntry(blogEntry, request.uri, extensionMap),
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
                entity: atomEntryFromBlogEntry(result, request.uri, extensionMap),
                lastModified: result.updated));
      });
}