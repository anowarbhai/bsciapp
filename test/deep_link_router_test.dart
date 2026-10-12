import 'package:bsciapp/deep_link_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes HTTPS and custom BSCI links to matching app sections', () {
    expect(
      resolveDeepLink(Uri.parse('https://bscibd.com/events/8')),
      DeepLinkDestination.events,
    );
    expect(
      resolveDeepLink(Uri.parse('bsci://publications/3')),
      DeepLinkDestination.publications,
    );
    expect(
      resolveDeepLink(Uri.parse('bsci://cases/12')),
      DeepLinkDestination.cases,
    );
    expect(
      resolveDeepLink(Uri.parse('bsci://gallery')),
      DeepLinkDestination.gallery,
    );
  });
}
