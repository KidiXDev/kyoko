const BASE = "https://animasu.love";

fn search(q) { parse_search(page(`${global::BASE}/?s=${url_encode(q)}`)) }

fn parse_search(body) {
    let out = [];
    let seen = #{};
    for a in select(body, ".listupd .bsx > a[href]") {
        let url = url_join(global::BASE, attr(a, "href"));
        let title = select(a.html, ".tt");
        if !url.starts_with(global::BASE + "/anime/") || title.is_empty() || title[0].text == "" || seen.contains(url) { continue; }
        let images = select(a.html, "img");
        let src = if images.is_empty() { "" } else { images[0].attrs["data-src"] ?? images[0].attrs.src ?? "" };
        seen[url] = true;
        out.push(#{ name: title[0].text, url: url, image: if src == "" { "" } else { url_join(global::BASE, src) } });
    }
    out
}

fn parse_episodes(body, base) {
    let out = [];
    let seen = #{};
    for a in select(body, "#daftarepisode .lchx a[href]") {
        let url = url_join(base, attr(a, "href"));
        let m = regex_match(a.text, #"(?i)^Episode\s+(\d+)\s*$"#);
        let single = ["episode movie", "episode special", "movie"].contains(a.text.to_lower());
        if !url.starts_with(global::BASE + "/nonton-") || (m == () && !single) || seen.contains(url) { continue; }
        let num = if single { 1 } else { parse_int(m[1]) };
        if num < 1 { continue; }
        seen[url] = true;
        out.push(#{ num: num, url: url, title: if single { a.text } else { `Episode ${num}` } });
    }
    out
}

fn episodes(url) {
    let out = parse_episodes(page(url), url);
    if out.is_empty() { throw "Animasu: no episodes found (layout changed?)"; }
    out
}

// shortcut: only Blogger mirrors are supported; extend when another host is needed.
fn parse_players(body) {
    let embeds = select(body, "#pembed iframe[src]");
    for option in select(body, "select.mirror option[value]") {
        let value = attr(option, "value");
        if value == "" { continue; }
        try { embeds += select(base64_decode(value), "iframe[src]"); }
        catch (err) { debug(`Animasu: invalid mirror: ${err}`); }
    }
    let out = [];
    let seen = #{};
    for iframe in embeds {
        let p = url_parse(attr(iframe, "src"));
        if p == () || !["https", "http"].contains(p.scheme) || !["blogger.com", "www.blogger.com"].contains(p.host) || p.path != "/video.g" || (p.query.token ?? "") == "" { continue; }
        let url = "https://www.blogger.com/video.g?token=" + url_encode(p.query.token);
        if seen.contains(url) { continue; }
        seen[url] = true;
        out.push(#{ url: url, height: 0 });
    }
    out
}

fn heights(url) { parse_players(page(url)).map(|p| p.height) }

fn stream(url, quality) {
    let players = parse_players(page(url));
    if players.is_empty() { throw "Animasu: no supported Blogger player for this episode"; }
    #{ url: players[0].url, referer: url }
}
