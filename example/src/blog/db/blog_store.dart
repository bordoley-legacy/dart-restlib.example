part of restlib.example;

class BlogStore {
  final MutableDictionary<String, MutableDictionary<String, BlogEntry>> entries =
      new MutableDictionary.hash();
  
  Iterable<BlogEntry> getBlogEntries(final String userId) =>
      entries[userId]
        .orElse(Persistent.EMPTY_DICTIONARY).values
        .toList()..sort((final BlogEntry x, final BlogEntry y) =>
            x.updated.compareTo(y.updated));
  
  Option<BlogEntry> getBlogEntry(final String userId, final String itemId) =>
      entries[userId].flatMap((final MutableDictionary<String, BlogEntry> entries) =>
          entries[itemId]);
  
  Option<BlogEntry> deleteBlogEntry(final String userId, final String itemId) =>
      entries[userId].flatMap((final MutableDictionary<String, BlogEntry> entries) =>
          entries.removeAt(itemId));
  
  void putBlogEntry(final BlogEntry blogEntry) =>
      entries[blogEntry.userId].orCompute(() {
        final MutableDictionary<String, BlogEntry> blogEntries = new MutableDictionary.hash();
        entries[blogEntry.userId] = blogEntries;
        return blogEntries;
      }).put(blogEntry.itemId, blogEntry);
}


class BlogEntry {
  final DateTime created;
  final String content;
  final String itemId;
  final String title;
  final DateTime updated;
  final String userId;
  
  BlogEntry(this.created, this.content, this.itemId, this.title, this.updated, this.userId);
}