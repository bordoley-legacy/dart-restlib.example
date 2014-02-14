part of restlib.example.blog;

class _FeedResourceDelegate extends UniformResourceDelegate<AtomEntry<String>> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Dictionary<String, MediaRange> entryExtensionMap;
  final Dictionary<String, MediaRange> feedExtensionMap;
  
  final _BlogStore blogStore;
  final Route route;
  final Random rand = new Random();

  final RequestFilter extensionFilter; 
      
  
  _FeedResourceDelegate(this.blogStore, this.feedExtensionMap, final Dictionary<String, MediaRange> entryExtensionMap, this.route) :
    this.entryExtensionMap = entryExtensionMap,
        
    // FIXME: requestExtensionAsAccept should take an Iterable of pairs.
    // Then we should create a set of all pairs from both extension maps
    // and use those as the argument.
    extensionFilter = requestExtensionAsAccept(entryExtensionMap);
  
  Future<Response> _processRequest(final Request request, Future<Response> handler(final String userId)) =>
      route.parametersFromPath(request.uri.path)["userid"].map(handler).orCompute(() => 
                throw new ArgumentError("Request URI path doesn't match Route pattern"));
  
  Request filterRequest(Request request) =>
      extensionFilter(request);
  
  Future<Response> get(final Request request) =>
      _processRequest(request, (final String userId) {
        final Iterable<_BlogEntry> entries = blogStore.getBlogEntries(userId); 
        final AtomFeed feed = new AtomFeed(
            request.uri, "$userId's blog", first(entries).map((final _BlogEntry entry) => 
                entry.updated).orCompute(() => 
                    new DateTime.now()),
            links: generateLinks(request.uri, entryExtensionMap),
            entries: entries.map((final _BlogEntry entry) =>
                // FIXME:
                _atomEntryFromBlogEntry(entry, request.uri, entryExtensionMap)));
        
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
        
        final _BlogEntry result = new _BlogEntry(now, newContent, id, newTitle, now, userId);
        
        blogStore.putBlogEntry(result);
                
        return new Future.value(
            new Response(Status.SUCCESS_OK,
                entity: _atomEntryFromBlogEntry(result, request.uri, entryExtensionMap),
                lastModified: result.updated));
      });
}