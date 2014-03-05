part of example.blog;

Future writeAtomXMLFeed(final Request request, final Response<AtomFeed> response, final StreamSink<List<int>> msgSink) {
  final AtomFeed feed = response.entity.value;
  final String atom =
"""<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom
      xmlns:os="http://a9.com/-/spec/opensearch/1.1/"
      xmlns:app="http://www.w3.org/2007/app">
  <id>${feed.id}</id>
  <updated>${feed.updated}</updated>
  ${feed.links.map(writeAtomLink).join("\n  ")}

          
  <title>${feed.title}</title>

  ${feed.entries.map(entryToAtomXML).join("\n")}
</feed>
""";
  final Response<String> htmlResponse = response.with_(entity:atom);
  return writeString(request, htmlResponse, msgSink);   
}

Future writeHtmlFeed(final Request request, final Response<AtomFeed<AtomEntry<String>>> response, final StreamSink<List<int>> msgSink) {
  final AtomFeed feed = response.entity.value;
  final String html = """
<!DOCTYPE html>
<html>
  <head>
    <title>${feed.title}</title>
        ${feed.links.map(writeAtomLink).join("\n    ")}
    </head>
    <body class="hfeed">
    ${firstWhere(feed.links, (final AtomLink link) =>
        link.rel
        .map((final String rel) =>
            rel == "edit")
        .orElse(false)).map((final AtomLink link) =>
            """
        <form method="post" action="${link.href}" enctype="application/x-www-form-urlencoded">
            <label>Title: <input type="text" name="title" value=""></label><br>
            <label>Content: <input type="text" name="content" value=""></label><br>
            <input type="submit" value="Create New Entry">
        </form>  
            """).orElse("")}       
                
      ${feed.entries.map(entryToHTML).join("\n")}
    </body>
</html>
""";
  final Response<String> htmlResponse = response.with_(entity:html);
  return writeString(request, htmlResponse, msgSink);    
}

Future writeJsonFeed(final Request request, final Response<AtomFeed<AtomEntry<String>>> response, final StreamSink<List<int>> msgSink) {
  final AtomFeed feed = response.entity.value;
  final Map jsonMap =
      EMPTY_DICTIONARY
        .putAllFromMap({
          "id" : feed.id.toString(),
          "updated" : feed.updated.toString(),
          "title" : feed.title,
          "links" : feed.links.map(linkToJson).toList(),
        }).put("entry", feed.entries.map(entryToJsonMap).toList()).asMap();
  final Response<String> jsonResponse = response.with_(entity:JSON.encode(jsonMap));
  return writeString(request, jsonResponse, msgSink);
}

Option<Dictionary<MediaRange, ResponseWriter>> feedResponseWriters(final Request request, final Response response) {
  final entity = response.entity.value;
  
  if (entity is AtomFeed) {
    return new Option(
        EMPTY_DICTIONARY
          .put(APPLICATION_JSON, new ResponseWriter.forContentType(APPLICATION_JSON, writeJsonFeed))
          .put(APPLICATION_ATOM_XML, new ResponseWriter.forContentType(APPLICATION_ATOM_XML, writeAtomXMLFeed))
          .put(TEXT_HTML, new ResponseWriter.forContentType(TEXT_HTML, writeHtmlFeed)));
  }
  
  return Option.NONE;
}

