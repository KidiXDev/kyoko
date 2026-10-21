// The two Anoboy domains use different WordPress layouts.
// shortcut: only Blogger players are resolved; add a resolver when another host is needed.
const BASE = "https://anoboy.be";
const ALT = "https://anoboy.quest";

fn search(q) {
    try {
        let out = parse_search(page(`${global::BASE}/?s=${url_encode(q)}`, global::BASE + "/"), global::BASE);
        if !out.is_empty() { return out; }
    } catch (err) { debug(`Anoboy: primary search failed: ${err}`); }
    parse_search(page(`${global::ALT}/?s=${url_encode(q)}`, global::ALT + "/"), global::ALT)
}

fn parse_search(body, base) {
    let out = [];
    let seen = #{};
    for a in select(body, "article.bs .bsx > a[href], .column-content > a[rel=bookmark]") {
        let url = url_join(base, attr(a, "href"));
        let title = clean_sub_indo(attr(a, "title"));
        if url == "" || title == "" || seen.contains(url) { continue; }
        // .be search is series-only; .quest also exposes playable episode posts.
        if url_parse(base).host == "anoboy.be" && !url.contains("/anime/") { continue; }
        if title.to_lower().contains("download") || title.to_lower().contains("filler list") { continue; }
        let img = select(a.html, "img");
        let src = if img.is_empty() { "" } else { img[0].attrs["data-src"] ?? img[0].attrs.src ?? "" };
        seen[url] = true;
        out.push(#{ name: title, url: url, image: if src == "" { "" } else { url_join(base, src) } });
    }
    out
}

fn parse_episodes(body, base) {
    let out = [];
    let seen = #{};
    for a in select(body, ".eplister a[href], .lcp_catlist a[href]") {
        let url = url_join(base, attr(a, "href"));
        let m = regex_match(url, #"(?i)episode-(\d+)(?:-|/|$)"#);
        if m == () || seen.contains(url) { continue; }
        let num = parse_int(m[1]);
        if num < 1 { continue; }
        seen[url] = true;
        out.push(#{ num: num, url: url, title: `Episode ${num}` });
    }
    out
}

fn episodes(url) {
    let body = page(url, url_parse(url).origin + "/");
    let out = parse_episodes(body, url);
    if !out.is_empty() { return out; }
    // Movies and individual .quest episode posts can be search results themselves.
    let player = select(body, "#mediaplayer, #pembed iframe");
    if !player.is_empty() {
        let m = regex_match(url, #"(?i)episode-(\d+)(?:-|/|$)"#);
        let num = if m == () { 1 } else { parse_int(m[1]) };
        return [#{ num: num, url: url, title: `Episode ${num}` }];
    }
    throw "Anoboy: no episodes found (layout changed?)";
}

fn blogger_url(src, base) {
    let u = url_join(base, src);
    let p = url_parse(u);
    if p == () || !["https", "http"].contains(p.scheme) { return ""; }
    if p.host == "www.blogger.com" && p.path == "/video.g" && (p.query.token ?? "") != "" { return u; }
    // .quest's local wrapper forwards a Blogger token as `url`.
    if p.host == "anoboy.quest" && p.path == "/uploads/adsbatch720.php" {
        let token = p.query.url ?? "";
        if regex_match(token, #"^[A-Za-z0-9_-]{20,}$"#) != () { return "https://www.blogger.com/video.g?token=" + token; }
    }
    ""
}

fn parse_players(body, base) {
    let out = [];
    let seen = #{};
    for a in select(body, "#pembed iframe[src], #mediaplayer[src], a[data-video]") {
        let u = blogger_url(a.attrs["data-video"] ?? a.attrs.src ?? "", base);
        if u == "" || seen.contains(u) { continue; }
        seen[u] = true;
        out.push(#{ url: u, height: height_of(a.text + "p") });
    }
    out
}

fn heights(url) { parse_players(page(url, url_parse(url).origin + "/"), url).map(|p| p.height) }

fn stream(url, quality) {
    let players = sort_by_height(parse_players(page(url, url_parse(url).origin + "/"), url), quality);
    if players.is_empty() { throw "Anoboy: no supported Blogger player for this episode"; }
    // The app resolves Blogger embeds and their available qualities.
    #{ url: players[0].url, referer: url }
}
