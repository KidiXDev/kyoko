const BASE = "https://anime-indo.lol";

fn search(q) {
    parse_search(page(`${global::BASE}/search.php?q=${url_encode(q)}`))
}

fn parse_search(body) {
    let out = [];
    let seen = #{};
    for table in select(body, "table.otable") {
        let row = "<table>" + table.html + "</table>";
        let links = select(row, ".videsc a[href]");
        if links.is_empty() { continue; }
        let a = links[0];
        let url = url_join(global::BASE, attr(a, "href"));
        if !url.starts_with(global::BASE + "/anime/") || a.text == "" || seen.contains(url) { continue; }
        let images = select(row, ".vithumb img");
        let src = if images.is_empty() { "" } else { images[0].attrs["data-original"] ?? images[0].attrs.src ?? "" };
        seen[url] = true;
        out.push(#{ name: clean_sub_indo(a.text), url: url, image: if src == "" { "" } else { url_join(global::BASE, src) } });
    }
    out
}

fn parse_episodes(body, base) {
    let out = [];
    let seen = #{};
    for a in select(body, ".ep a[href]") {
        let url = url_join(base, attr(a, "href"));
        let m = regex_match(url, #"/[^/]+-episode-(\d+)/?$"#);
        if !url.starts_with(global::BASE + "/") || m == () || seen.contains(url) { continue; }
        let num = parse_int(m[1]);
        if num < 1 { continue; }
        seen[url] = true;
        out.push(#{ num: num, url: url, title: `Episode ${num}` });
    }
    out
}

fn episodes(url) {
    let out = parse_episodes(page(url, global::BASE + "/"), url);
    if out.is_empty() { throw "AnimeIndo: no episodes found (layout changed?)"; }
    out
}

// shortcut: only Blogger and XtWap mirrors are supported; extend when another host is needed.
fn parse_players(body, base) {
    let out = [];
    let seen = #{};
    for a in select(body, "iframe#tontonin[src], .servers a[data-video]") {
        let url = url_join(base, a.attrs["data-video"] ?? a.attrs.src ?? "");
        let p = url_parse(url);
        if p == () || !["https", "http"].contains(p.scheme) { continue; }
        if p.host == "play.xtwap.top" && ["/btube3.php", "/cepat2.php"].contains(p.path) && (p.query.url ?? "") != "" {
            if !seen.contains(url) { seen[url] = true; out.push(#{ url: url, height: 0 }); }
            continue;
        }
        if !["blogger.com", "www.blogger.com"].contains(p.host) || p.path != "/video.g" || (p.query.token ?? "") == "" { continue; }
        let player = "https://www.blogger.com/video.g?token=" + url_encode(p.query.token);
        if seen.contains(player) { continue; }
        seen[player] = true;
        out.push(#{ url: player, height: 0 });
    }
    out
}

fn heights(url) { parse_players(page(url, global::BASE + "/"), url).map(|p| p.height) }

fn parse_media(body, base) {
    let out = [];
    for source in select(body, "video#mediaplayer source[src]") {
        let url = url_join(base, attr(source, "src"));
        let p = url_parse(url);
        if p != () && ["https", "http"].contains(p.scheme) { out.push(url); }
    }
    let file = regex_match(body, #""file"\s*:\s*"(https?://[^"\s]+)""#);
    if file != () { out.push(file[1]); }
    out
}

fn stream(url, quality) {
    let players = parse_players(page(url, global::BASE + "/"), url);
    for player in players {
        // Aikatsu resolves direct Blogger embeds and their available qualities.
        if url_parse(player.url).host == "www.blogger.com" { return #{ url: player.url, referer: url }; }
        try {
            for media in parse_media(page(player.url, url), player.url) {
                if playable(media) { return #{ url: media, referer: "" }; }
            }
        } catch (err) { debug(`AnimeIndo: mirror failed: ${err}`); }
    }
    throw "AnimeIndo: no playable supported mirror for this episode";
}
