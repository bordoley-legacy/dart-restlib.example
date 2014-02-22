part of restlib.example;

const String _USERNAME = "username";
const String _PASSWORD = "password";

String _authform(final URI callback, [final String error]) =>
"""
<!DOCTYPE html>
  <html>
    <head>

    </head>
    <body>
    ${isNull(error) ? "" : "<p>$error</p>" }
    <form method="post" action="${callback /* FIXME: callback should be HTML encoded*/}">
      <input type="text" name=$_USERNAME required>
      <input type="password" name=$_PASSWORD required>
      <input type="submit" value="Login">
    </form>
  </body>
</html>
""";

class _UserPwd {
  final String user;
  final String pwd;

  _UserPwd(this.user, this.pwd);

  int get hashCode =>
      computeHashCode([user, pwd]);

  bool operator==(other) {
    if (identical(this,other)) {
      return true;
    } else if (other is _UserPwd) {
      return this.user == other.user &&
          this.pwd == other.pwd;
    } else {
      return false;
    }
  }
}

IOResource ioFormBasedAuthResource(final Route route, Option<String> sidForUserPwd(final _UserPwd userPwd)) =>
    new IOResource.conneg(
      new Resource.uniform(new _FormBasedAuthResource(route, sidForUserPwd)),
      (final ContentInfo contentInfo) =>
          contentInfo.mediaRange
            .map((final MediaRange mr) {
              if (mr == APPLICATION_WWW_FORM) {
                return parseForm;
              }
            }),
      new ResponseWriterProvider.alwaysProvides(new ResponseWriter.string(TEXT_HTML))
    );

typedef Option<String> _SidForUserPwd(final _UserPwd userPwd);

class _FormBasedAuthResource extends UniformResourceDelegate<Form> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Route route;
  final _SidForUserPwd sidForUserPwd;

  _FormBasedAuthResource(this.route, this.sidForUserPwd);

  Future<Response> get(final Request request) =>
        new Future.value(
          new Response(
            Status.SUCCESS_OK,
            entity : _authform(request.uri)));

  Future<Response> post(final Request<Form> request) {
    final Form entity = request.entity.value;
    final Option<String> user = first(entity[_USERNAME]);
    final Option<String> pwd = first(entity[_PASSWORD]);

    Response response;

    if (user.isEmpty || pwd.isEmpty) {
      response =
          new Response(
              Status.SUCCESS_OK,
              entity : _authform(request.uri, "Missing either username or pwd"));
    } else {
      response = sidForUserPwd(new _UserPwd(user.value, pwd.value)).map((final String sid) {
        Form form;
        try {
          form = Form.parser.parseValue(request.uri.query);
        } on ArgumentError {
          return CLIENT_ERROR_BAD_REQUEST;
        }

        final URI redirectURI =
            first(form[_TARGET])
              .flatMap((final String uri) =>
                  URI_.parse(uri))
              .orCompute(() =>
                  request.uri);

        return new Response(
            Status.REDIRECTION_FOUND,
            setCookies: [SetCookie.parser.parseValue("$_SID=$sid")],
            location: redirectURI);
      }).orCompute(() =>
          new Response(
              Status.SUCCESS_OK,
              entity : _authform(request.uri, "Bad username or pwd")));
    }
    return new Future.value(response);
  }
}

