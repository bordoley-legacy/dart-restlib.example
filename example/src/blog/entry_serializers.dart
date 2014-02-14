part of restlib.example.blog;

String entryToAtomXML(final AtomEntry entry) =>
    """<entry>
    <id>${entry.id}</id>
    <title>${entry.title}</title>
    ${entry.published.map((final DateTime date) =>
        "<published>$date</published>").orElse("")}
    <updated>${entry.updated}</updated>

    <content type="text">${entry.content.value}</content>

    ${entry.links.map(writeAtomLink).join("\n  ")}
  </entry>""";
  
String entryToHTML(final AtomEntry entry) =>
    """
    <div id="${entry.id}" class="hentry">
      <h2 class="entry-title">${entry.title}</h1>        
      <div>
        Updated: <abbr class="updated" title="${entry.updated}">${entry.updated}</abbr>
      </div>
      ${entry.published.map((final DateTime published) =>
        """"<div>
          Created: <abbr class="published" title="${published}">${published}</abbr>
        </div>""").orElse("")}
      
      <p class="entry-content">${entry.content.value}</p>
    </div> 
    """;

Map linkToJson(final AtomLink link) {
  ImmutableDictionary<String, dynamic> retval = 
      Persistent.EMPTY_DICTIONARY.put("href", link.href.toString());
  link.hrefLanguage.map((final Language language) =>
      retval = retval.put("hrefLang", language.toString()));
  link.length.map((final int length) =>
      retval = retval.put("length", length));
  link.rel.map((final String rel) =>
      retval = retval.put("rel", rel));
  link.title.map((final String title) =>
      retval = retval.put("title", title));
  link.type.map((final MediaRange type) => 
      retval = retval.put("type", type.toString()));
  return retval.asMap();
}
    
Map entryToJsonMap(final AtomEntry entry) =>
    {"id" : entry.id.toString(),
     "title" : entry.title,
     "updated" : entry.updated.toString(),
     "content" : entry.content.value,
     "links" : entry.links.map(linkToJson).toList(),
    };
  
String writeAtomLink(final AtomLink link) =>
    "<link ${link.rel.map((final String rel) => 
        "rel=\"$rel\"").orElse("")} ${link.type.map((final MediaRange mr) => 
            "type=\"$mr\"").orElse("")} href=\"${link.href}\"/>"; 

Future writeAtomXMLEntry(final Request request, final Response<AtomEntry<String>> response, final StreamSink<List<int>> msgSink) {
  final AtomEntry<String> entry = response.entity.value;
  final String atom =
"""<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom">
  <id>${entry.id}</id>
  <title>${entry.title}</title>
  ${entry.published.map((final DateTime date) =>
      "<published>$date</published>").orElse("")}
  <updated>${entry.updated}</updated>

  <content type="text">${entry.content.value}</content>

  ${entry.links.map(writeAtomLink).join("\n  ")}
</entry>
""";

  return writeString(request, response.with_(entity: atom), msgSink);
}

Future writeFormEntry(final Request request, final Response<AtomEntry<String>> response, final StreamSink<List<int>> msgSink) {
  final AtomEntry<String> entry = response.entity.value;
  final Form form = 
      Form.EMPTY
        .put("id", entry.id.toString())
        .put("title", entry.title)
        .put("update", entry.updated.toString())
        .put("content", entry.content.value);
  final Response<String> formResponse = response.with_(entity:form.toString());
  return writeString(request, formResponse, msgSink);
}

Future writeHtmlEntry(final Request request, final Response<AtomEntry<String>> response, final StreamSink<List<int>> msgSink) {
  final AtomEntry<String> entry = response.entity.value;
  final String html = 
"""<!DOCTYPE html>
<html>
  <head>
    <title>${entry.title}</title>
    ${entry.links.map(writeAtomLink).join("\n    ")}
  </head>
  <body>
    <div id="${entry.id}" class="hentry">
      <h1 class="entry-title">${entry.title}</h1>        
      <div>
        Updated: <abbr class="updated" title="${entry.updated}">${entry.updated}</abbr>
      </div>
      ${entry.published.map((final DateTime published) =>
          """"<div>
        Created: <abbr class="published" title="${published}">${published}</abbr>
      </div>""").orElse("")}
      
      <p class="entry-content">${entry.content.value}</p>
    </div>
  </body>
</html>""";
  final Response<String> htmlResponse = response.with_(entity:html);
  return writeString(request, htmlResponse, msgSink);
}

Future writeJsonEntry(final Request request, final Response<AtomEntry<String>> response, final StreamSink<List<int>> msgSink) {
  final AtomEntry<String> entry = response.entity.value;
  final Map map = entryToJsonMap(entry);
  final Response<String> jsonResponse = response.with_(entity:JSON.encode(map));
  return writeString(request, jsonResponse, msgSink);
}

Option<Dictionary<MediaRange, ResponseWriter>> entryResponseWriters(final Request request, final Response response) {
  final entity = response.entity.value;
  
  if (entity is AtomEntry) {
    return new Option(
        Persistent.EMPTY_DICTIONARY
          .put(APPLICATION_JSON, new ResponseWriter.forContentType(APPLICATION_JSON, writeJsonEntry))
          .put(APPLICATION_ATOM_XML, new ResponseWriter.forContentType(APPLICATION_ATOM_XML, writeAtomXMLEntry))
          .put(TEXT_HTML, new ResponseWriter.forContentType(TEXT_HTML, writeHtmlEntry))
          .put(APPLICATION_WWW_FORM, new ResponseWriter.forContentType(APPLICATION_WWW_FORM, writeFormEntry)));
  }
  
  return Option.NONE;
}