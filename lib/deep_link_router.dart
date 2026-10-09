enum DeepLinkDestination { home, events, publications, cases, gallery, notices }

DeepLinkDestination resolveDeepLink(Uri uri) {
  final path = uri.scheme == 'bsci' ? '/${uri.host}${uri.path}' : uri.path;
  if (path.startsWith('/events')) return DeepLinkDestination.events;
  if (path.startsWith('/notices') || path.startsWith('/notice')) {
    return DeepLinkDestination.notices;
  }
  if (path.startsWith('/publications')) return DeepLinkDestination.publications;
  if (path.startsWith('/cases') || path.contains('case-forum')) {
    return DeepLinkDestination.cases;
  }
  if (path.startsWith('/gallery')) return DeepLinkDestination.gallery;
  return DeepLinkDestination.home;
}
