part of restlib.example;

class FeedResource extends UniformResourceDelegate {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Route route;
  
  Future<Response> get(final Request request) {
    
  }

  Future<Response> post(final Request/*<T>*/ request) {
    
  }
  
}