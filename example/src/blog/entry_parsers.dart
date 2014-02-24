part of restlib.example.blog;

AtomEntry<String> atomEntryFromAssociative(final Associative<String,String> assoc) =>
    // FIXME: use IRI_, but its crashing right now.
    new AtomEntry(URI.parser.parseValue(first(assoc["id"]).orElse("")), first(assoc["title"]).orElse(""), new DateTime.now(), content: assoc["content"].first);

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
