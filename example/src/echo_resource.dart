part of restlib.example;

Future<bool> authenticateUserAndPwd(final String user, final String pwd) => 
    new Future.value(user == "test" && pwd == "test");

IOResource ioAuthenticatedEchoResource(final Route route) =>
    new IOResource.conneg(
        new Resource.authorizingResource(
            new _EchoResource(route), [new Authorizer.basicAuth("testrealm", authenticateUserAndPwd)]),
        (_) => new Option(parseString), 
        new ResponseWriterProvider.alwaysProvides(new ResponseWriter.string(MediaRange.TEXT_PLAIN)));

IOResource ioEchoResource(final Route route) =>
    new IOResource.conneg(
        new _EchoResource(route), 
        (_) => new Option(parseString), 
        new ResponseWriterProvider.alwaysProvides(new ResponseWriter.string(MediaRange.TEXT_PLAIN)));

class _EchoResourceDelegate implements UniformResourceDelegate<String> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Route route;
  
  _EchoResourceDelegate(this.route);
  
  Future<Response> get(final Request request) => 
      new Future.value(
        (new ResponseBuilder()
          ..entity = request
          ..status = Status.SUCCESS_OK
        ).build());
  
  Future<Response> post(final Request<String> request) => 
      new Future.value(
        (new ResponseBuilder()
          ..entity = request
          ..status = Status.SUCCESS_OK
        ).build());
}

class _EchoResource
    extends Object
    with ForwardingResource<String> {
  final Resource<String> delegate;
  
  _EchoResource(final Route route):
    delegate = new Resource.uniform(new _EchoResourceDelegate(route));
}