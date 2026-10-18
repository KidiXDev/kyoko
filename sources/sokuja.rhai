// Next.js pages carry the episode ID; the video-mirrors API supplies media URLs.
const BASE = "https://x6.sokuja.uk";

fn referer() { global::BASE + "/" }

fn is_web(url) {
    let p = url_parse(url);
    p != () && (p.scheme == "https" || p.scheme == "http") && p.host != ""
}

fn search(q) {
    parse_search(fetch(`${global::BASE}/api/search/?q=${url_encode(q)}&limit=20`, #{ referer: referer() }).body)
}

fn parse_search(body) {
    let data = json_parse(body);
    if type_of(data?.results) != "array" { throw "Sokuja: invalid search response"; }
    let out = [];
    for a in data.results {
        if type_of(a?.slug) != "string" || type_of(a?.title) != "string" { continue; }
        let name = clean_sub_indo(a.title);
        if name == "" || a.slug == "" { continue; }
        let image = a?.thumbnailUrl ?? a?.coverUrl ?? "";
        out.push(#{ name: name, url: `${global::BASE}/anime/${a.slug}/`, image: if image == "" { "" } else { url_join(referer(), image) } });
    }
    out
}

fn episodes(url) { parse_episodes(page(url, referer())) }

fn parse_episodes(body) {
    let seen = #{};
    let out = [];
    for a in select(body, `#main-content a[href*="-episode-"]`) {
        let url = url_join(referer(), attr(a, "href"));
        let p = url_parse(url);
        if p == () || p.origin != global::BASE || seen.contains(url) { continue; }
        let m = regex_match(p.path, #"-episode-(\d+)(?:-|/)"#);
        if m == () { continue; }
        let spans = select(a.html, "span");
        let title = if spans.is_empty() { a.text } else { spans[0].text };
        seen[url] = true;
        out.push(#{ num: parse_int(m[1]), url: url, title: title });
    }
    out
}

fn episode_id(body) {
    // Flight embeds JSON inside a JavaScript string, with escaped quotes.
    let m = regex_match(body, #"\\?"episodeId\\?"\s*:\s*(\d+)"#);
    if m == () { throw "Sokuja: no episode ID on player page (layout changed?)"; }
    m[1]
}

fn parse_mirrors(body) {
    let data = json_parse(body);
    if type_of(data?.mirrors) != "array" { throw "Sokuja: invalid player response"; }
    let out = [];
    for m in data.mirrors {
        if !["mp4", "raw", "hls"].contains(m?.embedType) || type_of(m?.embedUrl) != "string" || !is_web(m.embedUrl) { continue; }
        out.push(#{ url: m.embedUrl, height: height_of(m?.quality ?? "") });
    }
    out
}

fn mirrors(url) {
    let cached = cache_get(url);
    if cached != () { return cached; }
    let id = episode_id(page(url, referer()));
    let out = parse_mirrors(fetch(`${global::BASE}/api/video-mirrors/?e=${id}`, #{ referer: url }).body);
    cache_set(url, out, 600);
    out
}

fn heights(url) { mirrors(url).map(|m| m.height) }

fn stream(url, quality) {
    for m in sort_by_height(mirrors(url), quality) {
        if playable(m.url, referer()) { return #{ url: m.url, referer: referer() }; }
    }
    throw "Sokuja: no playable server for this episode";
}
