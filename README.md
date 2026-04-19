# LiquidNews

A Hacker News client built around iOS 26's Liquid Glass design language. Every element uses the system's glass material — no opaque fills, no fake blurs.

## Features

### Feed
The main screen pulls from the HN Firebase API and organises stories into switchable categories: Top, New, Ask HN, Show HN, Jobs, and more. A pill-shaped chip picker sits below the nav bar and slides away as you scroll, collapsing with a spring animation into a compact menu in the title area. When more than five categories are enabled, the last slot becomes an overflow chip that exposes the rest via a menu. Tap, swipe left, and swipe right actions are all independently configurable.

### Story detail
Opening a story loads the comment thread as a lazy-rendered list (so 500-comment threads don't freeze on open). The header card shows score, comment count, author, and a "Read Article" button that opens with whichever mode you've set as your default. A "Also Discussed on HN" section surfaces other threads about the same URL. From the overflow menu you can upvote, reply, flag, save, share, or open the article in a different mode without changing your default. Logged-in users can post replies inline.

### Article reading
Three modes are available: **Reader** extracts article content using Mozilla's Readability.js (the same engine Firefox uses), **Browser** opens a full in-app WKWebView, and **Safari** hands off to Safari. The default is set once in Settings; any individual article can be opened differently via long-press or the overflow menu.

### Curated
A separate tab that aggregates articles from curated sources — the Hacker Newsletter and any custom JSON feeds you add — into a single chronological list. When multiple sources are enabled, a source filter chip row appears so you can narrow the view to one source. Entries that have an HN thread open in the full story detail view; those without one fall back to your default article open mode.

### Catch-up
Browse top or recent HN stories from any past date range using the Algolia HN Search API. Useful for catching up after time away without wading through the live feed.

### Saved, Favourites, History
- **Saved** — bookmark stories to read later
- **Favourites** — long-term collection, separate from the read-later list
- **History** — automatic read history; configurable behaviour on opening a story (hide it, dim it, or do nothing)

### Search
Full-text search against the Algolia HN index, accessible from the main feed toolbar.

### Account
Sign in with your HN credentials to upvote, reply, and flag from within the app. No third-party auth — credentials go directly to news.ycombinator.com.

### Share Extension
A system share extension lets you pipe URLs from Safari or other apps into LiquidNews.

## Customisation

Most behaviour is configurable from Settings:

| Setting | Options |
|---|---|
| Default tap action | Open comments, reader, browser, or Safari |
| Swipe left / right | Favourite, save, hide, open comments, open reader, open browser, open Safari, or none |
| Default link open | Reader, in-app browser, or Safari |
| Comment auto-load depth | How many reply levels expand automatically |
| Comment rendering | Rich (parsed HTML) or plain text |
| Read behaviour | Hide, dim, or no change after opening a story |
| Hidden posts expiry | 7 days, 30 days, 90 days, or never |
| Feed categories | Toggle and reorder which category chips appear |
| Tab bar | Toggle and reorder which tabs are shown |
| Curated sources | Enable/disable built-in sources; add custom JSON feeds |

## Requirements

- iOS 26 (Liquid Glass APIs are not available on earlier versions)
- Xcode 26+

## Building

Clone the repo and open `LiquidNews.xcodeproj`. Readability.js needs to be added manually to the target — download it from the [mozilla/readability](https://github.com/mozilla/readability) repo and drag it into the project. Without it the in-app reader falls back to the browser view with a logged warning.
