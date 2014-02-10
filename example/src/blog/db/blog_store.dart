part of restlib.example;

class BlogStore {
  final MutableDictionary<String, BlogEntry> entries =
      new MutableDictionary.hash();
  
  Option<BlogEntry> getBlogEntry(final String userId, final String itemId) =>
      entries["$userId:$itemId"];
  
  Option<BlogEntry> deleteBlogEntry(final String userId, final String itemId) =>
      entries.removeAt("$userId:$itemId");
  
  void putBlogEntry(final BlogEntry blogEntry) =>
      entries.put("${blogEntry.userId}:${blogEntry.itemId}", blogEntry);
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