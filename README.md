# websitecategorizationapi

Give it a web page, get back what the page is about. `websitecategorizationapi` is the Dart client for the [website category API](https://www.websitecategorizationapi.com), built for publishers, ad platforms and analytics teams who need topic labels without running their own classifier.

## Setup

```bash
dart pub add websitecategorizationapi
```

Create a client once and reuse it:

```dart
import 'package:websitecategorizationapi/websitecategorizationapi.dart';

final wca = WebsiteCategorizationAPIClient(apiKey: key);
```

## Classifying an article

```dart
final r = await wca.classify('https://example.com/article');
for (final c in (r['categories'] as List? ?? const [])) {
  print('${c['tier']}  ${c['name']}  ${c['confidence']}');
}
```

The documented response has a `categories` list. Each entry carries an `id`, a `name`, a `tier` and a `confidence`. A `meta` block holds the `request_id` and `processing_time_ms`, which help when you report a problem. See the API docs on the website for the full reference.

Pass a full article URL when the page matters, and a bare domain when you want the site as a whole. A sports section and a recipe page on the same news site deserve different labels, and the URL form gives you that.

## Tiers, briefly

The IAB content taxonomy is a tree. Tier 1 is broad, for example Sports. Deeper tiers narrow it, for example Soccer under Sports. Advertisers often target at tier 1 or 2, while brand safety teams care about specific deep nodes. Keep all tiers in storage and choose the depth at query time. You cannot recover detail you threw away.

## Worked example: contextual targeting

A publisher wants to send its ad server one or two topic keys per page, without cookies. At publish time:

```dart
Future<List<String>> topicKeys(String articleUrl) async {
  final r = await wca.classify(articleUrl);
  final cats = (r['categories'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .where((c) => (c['confidence'] as num? ?? 0) >= 0.5)
      .toList()
    ..sort((a, b) =>
        (b['confidence'] as num).compareTo(a['confidence'] as num));
  return cats.take(2).map((c) => c['id'].toString()).toList();
}
```

Store the keys with the article. The ad call then carries them as key-values, and campaigns target topics instead of people. Classify once per article and again only when the text changes, not on every page view.

## Worked example: auditing where links go

A content team wants to know what kinds of sites its outbound links point to. Collect the URLs, classify the unique domains, and count:

```dart
final counts = <String, int>{};
for (final domain in uniqueDomains) {
  final r = await wca.classify(domain);
  final cats = r['categories'] as List? ?? const [];
  final name = cats.isEmpty ? 'Unclassified' : cats.first['name'];
  counts[name] = (counts[name] ?? 0) + 1;
}
```

A few hundred calls give a clear picture of the link profile, and odd categories stand out quickly.

## Worked example: a Flutter reading app

Apps that save articles for later can group them by topic automatically. Do the classification on your server, not in the app, so the key stays private:

1. The app sends the saved URL to your backend.
2. The backend calls `classify` and stores the categories with the item.
3. The app shows shelves by tier 1 category.

The same client runs on the backend, since it depends only on `package:http`.

## Choosing a confidence threshold

Every category comes with a confidence value between 0 and 1. There is no single right cut-off:

- **Targeting** can use a moderate threshold, around 0.5. A slightly wrong topic costs little.
- **Brand safety** should look at sensitive categories even at lower confidence. Missing an unsafe page costs more than a false alarm.
- **Reporting** works best with the top category only, so every page counts once.

Log the full list anyway. When a campaign underperforms, the lower-ranked categories often explain why.

## Pages that are hard to classify

Some pages carry little text: image galleries, login walls, single-page apps that render everything in the browser, and parked domains. The classifier falls back on whatever it can read, and for thin pages that may be the site as a whole. If a URL returns weak or generic categories, try the bare domain, or classify a text-rich page on the same site and reuse its labels.

## Behaviour you should know about

- **One request per call.** The package has no batch method. Loop, or run a few calls in parallel with `Future.wait`.
- **No retries or caching.** Add them in your code where they make sense. Cache by URL, and expire entries when the page changes.
- **Key in the body.** The endpoint takes the key as a form field, and the client sends it that way over HTTPS.
- **Timeout.** 30 seconds by default, configurable in the constructor.

## Exceptions

| Type | Cause |
|---|---|
| `ArgumentError` | Empty key or empty URL |
| `AuthenticationException` | 401 or 403, which means a bad key or no quota left |
| `RateLimitException` | 429 |
| `ApiException` | Other HTTP errors or a non-object JSON reply |

`AuthenticationException` and `RateLimitException` are subclasses of `ApiException`, so a single `on ApiException` clause catches all three.

## Testing

```dart
final wca = WebsiteCategorizationAPIClient(
  apiKey: 'x',
  httpClient: MockClient((_) async => http.Response(
      '{"categories":[{"id":"483","name":"Sports","tier":1,"confidence":0.91}]}',
      200)),
);
```

## Related data

Topic labels answer "what is this page about". Other questions need other data:

- Is the site an AI product? [AI content filtering systems](https://www.aitoolsblocklist.com) rely on a register of AI tools, which catches what a topic taxonomy files under technology.
- Who in a company uses AI, and how much? Compliance teams run [shadow AI detection software](https://www.shadowaitools.com/for-compliance-officers.php) over existing network logs.
- If your own software agents browse the web, an [AI agent allow list API](https://www.aiagentallowlist.com/api-docs.php) stops them before sensitive pages.

## Other clients

- [websitecategorization on npm](https://www.npmjs.com/package/websitecategorization)
- [websitecategorizationapi crate](https://crates.io/crates/websitecategorizationapi)
- [websitecategorization/websitecategorizationapi on Packagist](https://packagist.org/packages/websitecategorization/websitecategorizationapi)

## License

MIT. IAB and the Content Taxonomy are trademarks of IAB Technology Laboratory, mentioned here only to describe compatibility.
