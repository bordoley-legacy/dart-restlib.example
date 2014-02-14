part of restlib.example.blog;

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

class _EntryResourceDelegate extends UniformResourceDelegate<AtomEntry<String>> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  
  final _BlogStore blogStore;
  final Dictionary<String, MediaRange> extensionMap;
  final Route route;
  
  final RequestFilter extensionFilter;
  
  _EntryResourceDelegate(this.blogStore, final Dictionary<String, MediaRange> extensionMap, this.route) :
    this.extensionMap = extensionMap,
    extensionFilter = requestExtensionAsAccept(extensionMap);
  
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
              .map((final _BlogEntry blogEntry) =>
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
        
        final _BlogEntry result =
            blogStore.getBlogEntry(userAndItemId.fst, userAndItemId.snd)
              .map((final _BlogEntry blogEntry) =>
                  new _BlogEntry(blogEntry.created, newContent, blogEntry.itemId, newTitle, new DateTime.now(), blogEntry.userId))
              .orCompute(() {
                final DateTime now = new DateTime.now();   
                return new _BlogEntry(now, newContent, userAndItemId.snd, newTitle, now, userAndItemId.fst);
              });
        blogStore.putBlogEntry(result);
        
        // FIXME: include the entity
        return new Future.value(
            new Response(Status.SUCCESS_OK,
                entity: atomEntryFromBlogEntry(result, request.uri, extensionMap),
                lastModified: result.updated));
      });
}