part of example;

typedef bool _ValidateSID(Request request, String sid);

const String _SID = "SID";
const String _TARGET = "target";

class _SessionAuthenticatedResource<T> extends ForwardingResource<T> {
  final Resource<T> delegate;
  final URI loginURI;
  final _ValidateSID validateSID;
  
  _SessionAuthenticatedResource(this.delegate, this.loginURI, this.validateSID);
  
  Future<Response> handle(final Request request) => 
      firstWhere(request.cookies[_SID], (final String sid) => 
          validateSID(request, sid))
        .map((final String sid) => 
            delegate.handle(request))
        .orCompute(() {
          final Form form = Form.EMPTY.put(_TARGET, request.uri.toString());
      
          // FIXME: Add URI.with_()
          final URI redirectUri =
             new URI(
                  scheme: loginURI.scheme,
                  authority: loginURI.authority.nullableValue,
                  path: loginURI.path,
                  query: form.toString());

          final Response response =
              new Response(Status.REDIRECTION_FOUND,
                  location: redirectUri);
      
          return new Future.value(response);
        });
}