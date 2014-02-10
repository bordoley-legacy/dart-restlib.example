part of restlib.example;

IOResource ioAuthenticatedEchoResource(final Route route) =>
    new IOResource.conneg(
        new Resource.authorizingResource(
            new Resource.uniform(new _EchoResourceDelegate(route)), [new _EchoAuthorizer()]),
        (_) => new Option(parseString), 
        new ResponseWriterProvider.alwaysProvides(new ResponseWriter.string(TEXT_PLAIN)));

IOResource sessionAuthenticatedEchoResource(final Route route, final URI loginForm, bool validateSID(Request request, String sid)) =>
    new IOResource.conneg(
        new _SessionAuthenticatedResource(
            new Resource.uniform(new _EchoResourceDelegate(route)),
            loginForm, validateSID),
        (_) => new Option(parseString), 
        new ResponseWriterProvider.alwaysProvides(new ResponseWriter.string(TEXT_PLAIN)));

IOResource ioEchoResource(final Route route) =>
    new IOResource.conneg(
        new Resource.uniform(new _EchoResourceDelegate(route)), 
        (_) => new Option(parseString), 
        new ResponseWriterProvider.alwaysProvides(new ResponseWriter.string(TEXT_PLAIN)));

class _EchoResourceDelegate extends UniformResourceDelegate<String> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Route route;
  
  final RequestFilter extensionFilter = 
      requestExtensionAsAccept(
          new Dictionary.wrapMap(
              {"html" : TEXT_HTML}));
  
  _EchoResourceDelegate(this.route);
  
  Request filterRequest(final Request request) =>
      extensionFilter(request);
  
  Future<Response> get(final Request request) => 
      new Future.value(
          new Response(
              Status.SUCCESS_OK,
              entity : request));
  
  Future<Response> post(final Request<String> request) => 
      new Future.value(
          new Response(
              Status.SUCCESS_OK,
              entity : request));
}

class _EchoAuthorizer 
    extends Object 
    with ForwardingAuthorizer {
  static Future<bool> authenticateUserAndPwd(final Request, final String user, final String pwd) => 
      new Future.value(user == "test" && pwd == "test");
  
  final Authorizer delegate = new Authorizer.basicAuth("testrealm", authenticateUserAndPwd);
  
  Future<bool> authenticate(final Request request) =>
      (request.method != Method.GET) ? delegate.authenticate(request) : new Future.value(true);
}