// kuramalink.vip redirects to the current Kuramanime domain.
const BASE = "https://kuramanime.ing";
// shortcut: public loader key from leviathan.js v1448; refresh when Kuramanime rotates it.
const LOAD_AUTH = "kJuHHkaqcBFXiGMHQf6bJw8YAyDcwGD8Ur";

fn search(q) {
    let body = "";
    try { body = page(`${global::BASE}/anime?search=${url_encode(q)}&order_by=latest`); }
    catch (err) { body = page(`https://kuramalink.vip/anime?search=${url_encode(q)}&order_by=latest`); }
    parse_search(body)
}

fn parse_search(body) {
    let out = [];
    for a in select(body, "#animeList .product__item, #animeList .filter__gallery > a[href]") {
        let title = select(a.html, "h5");
        let image = select(a.html, "[data-setbg]");
        let link = select(a.html, "h5 a[href]");
        let href = if link.is_empty() { attr(a, "href") } else { attr(link[0], "href") };
        let url = url_join(global::BASE, href);
        if title.is_empty() || title[0].text == "" || regex_match(url, #"/anime/\d+/[^/?]+/?$"#) == () { continue; }
        out.push(#{ name: title[0].text, url: url, image: if image.is_empty() { "" } else { url_join(global::BASE, attr(image[0], "data-setbg")) } });
    }
    out
}

// The series page stores its paginated list as popover HTML in an attribute.
fn episode_list(body) {
    let list = select(body, "#episodeLists[data-content]");
    if list.is_empty() { body } else { attr(list[0], "data-content") }
}

fn parse_episodes(body, base) {
    let out = [];
    let seen = #{};
    for a in select(episode_list(body), "a.btn-danger[href], #animeEpisodes a[href]") {
        let url = url_join(base, attr(a, "href"));
        let m = regex_match(url, #"/episode/(\d+)/?(?:\?|$)"#);
        if m == () || seen.contains(url) { continue; }
        seen[url] = true;
        let num = parse_int(m[1]);
        if num > 0 { out.push(#{ num: num, url: url, title: `Episode ${num}` }); }
    }
    out
}

fn next_page(body, url) {
    let current = parse_int(url_parse(url).query.page ?? "1");
    for a in select(episode_list(body), "a.page__link__episode[href]") {
        let next = url_join(url, attr(a, "href"));
        let p = url_parse(next);
        if p != () && p.origin == url_parse(url).origin && p.path == url_parse(url).path && parse_int(p.query.page ?? "1") > current { return next; }
    }
    ""
}

fn episodes(url) {
    let out = [];
    let seen = #{};
    let next = url;
    while next != "" && !seen.contains(next) {
        seen[next] = true;
        let r = fetch(next, #{ referer: url });
        out += parse_episodes(r.body, r.url);
        next = next_page(r.body, r.url);
    }
    out
}

fn js_value(body, key) {
    let m = regex_match(body, key + #"\s*:\s*['"]([^'"]+)['"]"#);
    if m == () { throw `Kuramanime: missing player setting ${key}`; }
    m[1]
}

fn parse_sources(body, base) {
    let out = [];
    for s in select(body, "#player source[src]") {
        if attr(s, "src") == "" { continue; }
        let url = url_join(base, attr(s, "src"));
        let p = url_parse(url);
        if p == () || !["https", "http"].contains(p.scheme) { continue; }
        out.push(#{ url: url, height: height_of(attr(s, "size") + "p") });
    }
    for v in select(body, "#player[data-hls-src]") {
        let url = url_join(base, attr(v, "data-hls-src"));
        if attr(v, "data-hls-src") != "" && ["https", "http"].contains(url_parse(url)?.scheme) {
            out.push(#{ url: url, height: 0 });
        }
    }
    out
}

fn sources(url) {
    let cached = cache_get(url);
    if cached != () { return cached; }
    let r = fetch(url);
    let files = parse_sources(r.body, r.url);
    if files.is_empty() {
        let marker = select(r.body, "[data-kk]");
        if marker.is_empty() { throw "Kuramanime: player settings not found (layout changed?)"; }
        let origin = url_parse(r.url).origin;
        let script = url_join(origin, "/assets/js/" + attr(marker[0], "data-kk") + ".js");
        let vars = page(script, r.url);
        let route = js_value(vars, "MIX_PREFIX_AUTH_ROUTE_PARAM") + js_value(vars, "MIX_AUTH_ROUTE_PARAM");
        let token = fetch(url_join(origin + "/", route), #{ referer: r.url, headers: #{
            "X-Fuck-ID": js_value(vars, "MIX_AUTH_KEY") + ":" + js_value(vars, "MIX_AUTH_TOKEN"),
            "X-Request-ID": "kyokaa", "X-Request-Index": "0"
        } }).body;
        token.trim();
        if regex_match(token, #"^[A-Za-z0-9]+$"#) == () { throw "Kuramanime: invalid player token"; }
        let player = url_set_param(r.url, js_value(vars, "MIX_PAGE_TOKEN_KEY"), token);
        player = url_set_param(player, js_value(vars, "MIX_STREAM_SERVER_KEY"), "kuramadrive");
        player = url_set_param(player, "page", "1");
        let body = fetch(player, #{ referer: r.url, form: #{ authorization: global::LOAD_AUTH }, headers: #{ "X-Requested-With": "XMLHttpRequest" } }).body;
        files = parse_sources(body, r.url);
    }
    if files.is_empty() { throw "Kuramanime: no media files (player key changed or episode unavailable)"; }
    let result = #{ files: files, referer: r.url };
    cache_set(url, result, 120);
    result
}

fn heights(url) { sources(url).files.map(|f| f.height) }

fn stream(url, quality) {
    let s = sources(url);
    for f in sort_by_height(s.files, quality) {
        if playable(f.url, s.referer) { return #{ url: f.url, referer: s.referer }; }
    }
    throw "Kuramanime: no playable media file";
}
