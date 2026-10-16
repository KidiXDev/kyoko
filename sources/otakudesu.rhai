// otakudesu.blog — WordPress. Pixeldrain downloads first (up to 1080p, plain
// seekable files), then the streaming mirrors via a two-step admin-ajax nonce.

const BASE = "https://otakudesu.blog";
const LABEL = "Otakudesu";
const EPISODE_NUM = #"(?i)episode[- ](\d+)"#;
const BLOGGER = #"https://www\.blogger\.com/video\.g\?token=[A-Za-z0-9_-]+"#;

fn referer() { global::BASE + "/" }

fn search(q) {
    parse_search(page(`${global::BASE}/?s=${url_encode(q)}&post_type=anime`, referer()))
}

fn parse_search(body) {
    let out = [];
    for li in select(body, "ul.chivsrc li") {
        let a = select(li.html, "h2 a");
        if a.is_empty() { continue; }
        let href = attr(a[0], "href");
        let title = clean_sub_indo(a[0].text);
        if !href.contains("/anime/") || title == "" { continue; }
        let img = select(li.html, "img");
        out.push(#{ name: title, url: href, image: if img.is_empty() { "" } else { attr(img[0], "src") } });
    }
    out
}

fn episodes(url) { parse_episodes(page(url, referer())) }

fn parse_episodes(body) {
    let out = [];
    for a in select(body, "div.episodelist ul li a[href]") {
        let href = attr(a, "href");
        // "pembatas" rows are separators ("episodes 1-900 in progress"), not episodes.
        if !href.contains("/episode/") || href.contains("pembatas") { continue; }
        let num = episode_num(href) ?? episode_num(a.text);
        if num == () { continue; }
        out.push(#{ num: num, url: href, title: clean_sub_indo(a.text) });
    }
    out
}

fn episode_num(s) {
    let m = regex_match(s, global::EPISODE_NUM);
    if m == () { () } else { parse_int(m[1]) }
}

// One Pixeldrain row of the download section: "<strong>MKV 1080p</strong> … <a>Pdrain</a>".
// `url` is a link.desustream.com redirector.
fn parse_downloads(body) {
    let out = [];
    for li in select(body, "div.download li") {
        let strong = select(li.html, "strong");
        let height = if strong.is_empty() { 0 } else { height_of(strong[0].text) };
        if height == 0 { continue; }
        for a in select(li.html, "a[href]") {
            let name = a.text.to_lower();
            if name.contains("pdrain") || name.contains("pixeldrain") {
                out.push(#{ height: height, url: attr(a, "href") });
            }
        }
    }
    out
}

// Streaming mirrors: base64 JSON {id, i, q} per link.
fn parse_mirrors(body) {
    let out = [];
    for a in select(body, "div.mirrorstream a[data-content]") {
        try {
            let m = json_parse(base64_decode(attr(a, "data-content")));
            if type_of(m?.id) == "i64" && m.id != 0 && type_of(m?.i) == "i64" && type_of(m?.q) == "string" {
                out.push(#{ id: m.id, i: m.i, q: m.q, height: height_of(m.q) });
            }
        } catch (err) {}
    }
    out
}

fn heights(url) {
    let body = page(url, referer());
    parse_downloads(body).map(|d| d.height) + parse_mirrors(body).map(|m| m.height)
}

fn stream(url, quality) {
    let body = page(url, referer()); // cached since heights()
    for d in sort_by_height(parse_downloads(body), quality) {
        let u = resolve_pixeldrain(d.url);
        if u != "" { return #{ url: u, referer: referer() }; }
    }

    // The two ajax action hashes live in the page's inline script and may rotate per deploy.
    let nonce_action = regex_match(body, #"data:\{action:"([0-9a-f]{32})"\}"#);
    let embed_action = regex_match(body, #"nonce:[^,]+,action:"([0-9a-f]{32})""#);
    let mirrors = sort_by_height(parse_mirrors(body), quality);
    let last_err = "";
    if !mirrors.is_empty() && nonce_action != () && embed_action != () {
        try {
            let nonce = ajax_data(#{ action: nonce_action[1] });
            for m in mirrors {
                try {
                    let src = ajax_data(#{ id: m.id, i: m.i, q: m.q, nonce: nonce, action: embed_action[1] });
                    let u = resolve_embed(iframe_src(base64_decode(src)));
                    if u != "" { return #{ url: u, referer: referer() }; }
                } catch (err) { last_err = err; }
            }
        } catch (err) { last_err = err; }
    }
    // Last resort: the embed the page itself loads by default.
    let u = resolve_embed(iframe_src(body));
    if u != "" { return #{ url: u, referer: referer() }; }
    throw with_cause(`${global::LABEL}: no resolvable mirror for this episode`, last_err);
}

fn with_cause(msg, err) { if err == "" { msg } else { `${msg} (${err})` } }

fn ajax_data(form) {
    let r = fetch(`${global::BASE}/wp-admin/admin-ajax.php`, #{ form: form, referer: referer(), headers: #{ "X-Requested-With": "XMLHttpRequest" } });
    let data = json_parse(r.body)?.data;
    if type_of(data) != "string" || data == "" { throw `${global::LABEL}: empty admin-ajax data`; }
    data
}

fn iframe_src(markup) {
    let m = regex_match(markup, #"<iframe[^>]+src="([^"]+)""#);
    if m == () { "" } else { m[1] }
}

// Blogger iframes are returned as-is (the player unwraps them); desustream
// embeds are fetched and their file/Blogger URL extracted. A direct file is
// probed first: some embeds carry googlevideo URLs pinned to the embed server's IP.
fn resolve_embed(embed) {
    let b = regex_match(embed, global::BLOGGER);
    if b != () { return b[0]; }
    if !embed.contains("desustream") { return ""; }
    let body = "";
    try { body = fetch(embed, #{ referer: referer() }).body; } catch (err) { return ""; }
    for re in [#"<source[^>]+src=["']([^"']+)["']"#, #""?file"?\s*:\s*["']([^"']+)["']"#] {
        let m = regex_match(body, re);
        if m != () && m[1].starts_with("http") {
            let u = html_decode(m[1]);
            return if playable(u) { u } else { "" };
        }
    }
    let b = regex_match(body, global::BLOGGER);
    if b == () { "" } else { b[0] }
}

// Follows the redirector one hop, maps pixeldrain.com/u/<id> to its direct
// file, and probes it.
fn resolve_pixeldrain(redirect_url) {
    let location = "";
    try {
        location = fetch(redirect_url, #{ client: "plain", referer: referer(), redirect: false }).headers.location ?? "";
    } catch (err) { return ""; }
    let u = pixeldrain_file(location);
    if u != "" && playable(u) { u } else { "" }
}

// pixeldrain.com/u/<id> → pixeldrain.com/api/file/<id>; "" for other hosts.
fn pixeldrain_file(location) {
    let m = regex_match(location, #"^https://pixeldrain\.com/(?:u|api/file)/([A-Za-z0-9]+)"#);
    if m == () { "" } else { `https://pixeldrain.com/api/file/${m[1]}` }
}
