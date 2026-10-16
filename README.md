# Kyoko 🌸

The official source plugins for [Aikatsu](https://github.com/KidiXDev/aikatsu). Aikatsu adds this repo on first launch and checks it for updates every time it starts, so a site that changed its layout is fixed here, without a new app release.

## How a repo works

A repo is a folder served over HTTPS (here: GitHub raw files):

```
index.json          the list Aikatsu reads
sources/<key>.rhai  one script per site
tests/<key>.rhai    fixture tests for that script (not downloaded by the app)
```

```json
{
  "id": "kyoko",
  "name": "Kyoko",
  "plugins": [
    {
      "key": "example",
      "name": "Example",
      "version": 1,
      "api": 1,
      "file": "sources/example.rhai",
      "sha256": "…"
    }
  ]
}
```

- `id` and `key`: lowercase letters, digits, `-` or `_`. Aikatsu stores a source as `<id>/<key>` in watch history and downloads, so **never rename them**.
- `version`: shown in Settings. Bump it when you change a script.
- `api`: the host API version the script needs (see below). Older apps skip plugins that need more.
- `sha256`: the script's checksum. Aikatsu refuses a download that doesn't match, so a half-updated repo never breaks a working plugin. Don't edit it by hand: run `aikatsu-plugin index .`.

Anyone can host a repo like this one. Users add it from Settings → Sources → Add repo, after a warning to only add repos they trust.

## Writing a plugin

Scripts are [Rhai](https://rhai.rs/book/), which reads like a mix of Rust and JavaScript. A plugin defines four functions:

| Function               | Returns                                                                             |
| ---------------------- | ----------------------------------------------------------------------------------- |
| `search(query)`        | `[#{ name, url, image }]` (`image` may be `""`)                                     |
| `episodes(url)`        | `[#{ num, url, title }]` for the series page `url`; any order                       |
| `heights(url)`         | `[1080, 720, …]`: the resolutions an episode offers                                 |
| `stream(url, quality)` | `#{ url, referer }`: a playable http(s) URL. `quality` is `"best"` or e.g. `"720p"` |

Throw a string to fail (`throw "Example: no mirror for this episode";`). Start messages with the site's name: the app shows them to users. `print(…)` and `debug(…)` go to the app's log.

Rhai notes: functions can't see variables outside them, but they can read top-level constants as `global::NAME`. `trim()`, `sort()` and `replace()` change the string or array in place and return nothing. `#"…"#` is a raw string, which suits regexes.

### Host API (api 1)

Everything a script can reach. There is no file, history or settings access.

**Network**

| Function                                   |                                                                                                                                                                                                                                                                                         |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `page(url)`, `page(url, referer)`          | GET an HTML page through a Chrome-like connection. Cached for 10 minutes, and Cloudflare-style challenge pages are rejected.                                                                                                                                                            |
| `fetch(url)`, `fetch(url, opts)`           | Any request → `#{ status, headers, body, url }`. Statuses from 400 throw. `opts`: `method`, `referer`, `headers: #{}`, `form: #{}`, `json`, `client` (`"chrome"`, or `"plain"` for file hosts), `redirect: false` (get the 3xx and its `headers.location`). Header names are lowercase. |
| `fetch_all(urls)`, `fetch_all(urls, opts)` | The same request to several URLs, 4 at a time; responses in order.                                                                                                                                                                                                                      |
| `playable(url)`, `playable(url, referer)`  | `true` when the host serves the file (asks for one byte).                                                                                                                                                                                                                               |

**Parsing**

| Function                                   |                                                                                                                                                                                                                                                                 |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `select(html, css)`                        | Each match as `#{ text, html, attrs }` (`html` is the inner HTML, `text` and attribute values are trimmed). Select again inside a match with `select(m.html, …)`. Table rows or cells (`tr`, `td`) selected alone lose their tags, so select the table instead. |
| `attr(match, name)`                        | An attribute, `""` when missing.                                                                                                                                                                                                                                |
| `regex_match(text, pattern)`               | `[whole, group1, …]` for the first match, or `()`.                                                                                                                                                                                                              |
| `regex_replace(text, pattern, with)`       | Replaces every match; `$1` refers to groups.                                                                                                                                                                                                                    |
| `json_parse(text)`                         | Maps, arrays, numbers, strings; `null` becomes `()`.                                                                                                                                                                                                            |
| `base64_decode(text)`, `html_decode(text)` |                                                                                                                                                                                                                                                                 |
| `url_encode(text)`                         | For query strings.                                                                                                                                                                                                                                              |
| `url_join(base, relative)`                 | `""` when either is invalid.                                                                                                                                                                                                                                    |
| `url_parse(url)`                           | `#{ scheme, host, origin, path, query: #{} }`, or `()`.                                                                                                                                                                                                         |
| `url_set_param(url, key, value)`           |                                                                                                                                                                                                                                                                 |

**Helpers**

| Function                                           |                                                                                                                         |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `height_of(label)`                                 | `"MKV 1080p"` → `1080`; `"best"` → `0`.                                                                                 |
| `sort_by_height(list, quality)`                    | Strings by their height, or maps by their `height` field: the requested one first, then the nearest higher, then lower. |
| `clean_sub_indo(title)`                            | Drops a trailing "Subtitle Indonesia" / "Sub Indo".                                                                     |
| `cache_get(key)`, `cache_set(key, value, seconds)` | A small in-memory cache per plugin (at most an hour), for data that both `heights` and `stream` need.                   |

A search may take 12 seconds, and anything else 60, before the app stops the script.

## Testing

The `aikatsu-plugin` tool is part of the Aikatsu source. Build it from a checkout next to this one:

```sh
cargo build -p aikatsu-core --bin aikatsu-plugin --manifest-path ../aikatsu/Cargo.toml
alias aikatsu-plugin=../aikatsu/target/debug/aikatsu-plugin

aikatsu-plugin test .                          # every test_* in tests/, offline
aikatsu-plugin live sources/example.rhai frieren   # search → episodes → qualities → stream on the real site
aikatsu-plugin call sources/example.rhai search "one piece"   # one function's result as JSON
aikatsu-plugin index .                         # refresh the checksums in index.json
```

Tests are Rhai functions named `test_*`. They call the plugin's own functions on saved HTML, using `assert(ok)`, `assert(ok, message)` and `assert_eq(got, want)`.

To try a repo in the app before publishing it, add it in Settings with a `file://` link to its `index.json` (desktop).

## Publishing a fix

1. Change the script, then `aikatsu-plugin test .` and `aikatsu-plugin live sources/<key>.rhai`.
2. Bump its `version` and run `aikatsu-plugin index .`.
3. Commit and push. Apps pick it up on their next start, or from Settings → Check for updates. GitHub can take a few minutes to serve the new files.

## License

[GPL-3.0](LICENSE)
