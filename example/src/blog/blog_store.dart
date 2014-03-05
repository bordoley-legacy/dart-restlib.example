part of example.blog;

AtomEntry _atomEntryFromBlogEntry(final _BlogEntry entry, final URI uri, final Dictionary<String, MediaRange> extensionMap) =>
    new AtomEntry(generateId(uri, entry.created), entry.title, entry.updated, 
        content: entry.content,
        links: generateLinks(uri, extensionMap));

class _BlogStore {
  final MutableDictionary<String, MutableDictionary<String, _BlogEntry>> entries =
      new MutableDictionary.hash();
  
  Iterable<_BlogEntry> getBlogEntries(final String userId) =>
      entries[userId]
        .orElse(EMPTY_DICTIONARY).values
        .toList()..sort((final _BlogEntry x, final _BlogEntry y) =>
            x.updated.compareTo(y.updated));
  
  Option<_BlogEntry> getBlogEntry(final String userId, final String itemId) =>
      entries[userId].flatMap((final MutableDictionary<String, _BlogEntry> entries) =>
          entries[itemId]);
  
  Option<_BlogEntry> deleteBlogEntry(final String userId, final String itemId) =>
      entries[userId].flatMap((final MutableDictionary<String, _BlogEntry> entries) =>
          entries.removeAt(itemId));
  
  void putBlogEntry(final _BlogEntry blogEntry) =>
      entries[blogEntry.userId].orCompute(() {
        final MutableDictionary<String, _BlogEntry> blogEntries = new MutableDictionary.hash();
        entries[blogEntry.userId] = blogEntries;
        return blogEntries;
      }).put(blogEntry.itemId, blogEntry);
}


class _BlogEntry {
  final DateTime created;
  final String content;
  final String itemId;
  final String title;
  final DateTime updated;
  final String userId;
  
  _BlogEntry(this.created, this.content, this.itemId, this.title, this.updated, this.userId);
}