part of restlib.example;

Option<Dictionary<MediaRange, ResponseWriter>> feedResourceResponseWriters(final Request request, final Response response) =>
    computeIfEmpty(entryResponseWriters(request,response), () =>
        feedResponseWriters(request,response));

IOResource feedResource(final BlogStore blogStore, final Dictionary<String, MediaRange> entryExtensionMap, final Route route) {
  final Resource<AtomEntry<String>> resource = 
        new Resource.uniform(
            new _FeedResourceDelegate(blogStore, entryExtensionMap, route));
  return new IOResource.conneg(
      resource,
      entryParserProvider, 
      new ResponseWriterProvider.onContentType(feedResourceResponseWriters));
}

class _FeedResourceDelegate extends UniformResourceDelegate<AtomEntry<String>> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Dictionary<String, MediaRange> entryExtensionMap;
  
  final BlogStore blogStore;
  final Route route;
  final Random rand = new Random();
  
  final RequestFilter extensionFilter = 
      requestExtensionAsAccept(
          new Dictionary.wrapMap(
              {"html" : TEXT_HTML,
                "atom" : APPLICATION_ATOM_XML,
                "json" : APPLICATION_JSON,
                "form" : APPLICATION_WWW_FORM}));
  
  _FeedResourceDelegate(this.blogStore, this.entryExtensionMap, this.route);
  
  Future<Response> _processRequest(final Request request, Future<Response> handler(final String userId)) =>
      route.parametersFromPath(request.uri.path)["userid"].map(handler).orCompute(() => 
                throw new ArgumentError("Request URI path doesn't match Route pattern"));
  
  Request filterRequest(Request request) =>
      extensionFilter(request);
  
  Future<Response> get(final Request request) =>
      _processRequest(request, (final String userId) {
        final Iterable<BlogEntry> entries = blogStore.getBlogEntries(userId); 
        final AtomFeed feed = new AtomFeed(
            request.uri, "$userId's blog", first(entries).map((final BlogEntry entry) => 
                entry.updated).orCompute(() => 
                    new DateTime.now()),
            links: generateLinks(request.uri, entryExtensionMap),
            entries: entries.map((final BlogEntry entry) =>
                // FIXME:
                atomEntryFromBlogEntry(entry, request.uri, entryExtensionMap)));
        
        return new Future.value(
            new Response(Status.SUCCESS_OK,
                entity: feed));
      });
    
  
  Future<Response> post(final Request<AtomEntry<String>> request) =>
      _processRequest(request, (final String userId) {
        final String newContent = request.entity.value.content.orElse("");
        final String newTitle = request.entity.value.title;
        final String id = rand.nextInt((1<<32) - 1).toString();
        final DateTime now = new DateTime.now(); 
        
        final BlogEntry result = new BlogEntry(now, newContent, id, newTitle, now, userId);
        
        blogStore.putBlogEntry(result);
                
        return new Future.value(
            new Response(Status.SUCCESS_OK,
                entity: atomEntryFromBlogEntry(result, request.uri, entryExtensionMap),
                lastModified: result.updated));
      });
}