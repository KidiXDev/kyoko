// v2.samehadaku.how — WordPress. Series search via the WP REST API (the HTML
// search mixes episode/batch posts, newest first, so series often fall off
// page 1). Players carry their iframe in `data-embed` (admin-ajax
// `player_ajax` for older pages); Wibufile plays through the app's HTTP/3
// proxy, Pixeldrain downloads and Blogspot are fallbacks.

const BASE = "https://v2.samehadaku.how";
const LABEL = "Samehadaku";
const EPISODE_NUM = #"(?i)episode[- ]*(\d+)"#;
const BLOGGER = #"https://www\.blogger\.com/video\.g\?token=[A-Za-z0-9_-]+"#;

fn referer() { global::BASE + "/" }

fn search(q) {
    let found = ();
    try {
        let api = `${global::BASE}/wp-json/wp/v2/anime?search=${url_encode(q)}&per_page=20&_embed=wp:featuredmedia`;
        found = parse_rest(fetch(api, #{ referer: referer() }).body);
    } catch (err) {}
    if found == () {
        debug(`${global::LABEL}: REST search unavailable, falling back to the HTML search`);
        return parse_search(page(`${global::BASE}/?s=${url_encode(q)}`, referer()));
    }
    rank(found, q)
}

// WP relevance puts "One Piece: Heroines" above "One Piece": exact title
// first, then titles starting with the query, then the rest (shortest first).
fn rank(found, q) {
    let q = q.to_lower();
    let keyed = found.map(|a| {
        let name = a.name.to_lower();
        let group = if name == q { 0 } else if name.starts_with(q) { 1 } else { 2 };
        #{ anime: a, key: group * 1000000 + name.len() }
    });
    keyed.sort(|x, y| x.key - y.key);
    keyed.map(|x| x.anime)
}

// `/wp-json/wp/v2/anime` results; () when the body isn't the expected JSON.
fn parse_rest(body) {
    let items = ();
    try { items = json_parse(body); } catch (err) { return (); }
    if type_of(items) != "array" { return (); }
    let out = [];
    for a in items {
        let url = a?.link;
        let rendered = a?.title?.rendered;
        if type_of(url) != "string" || type_of(rendered) != "string" || !url.contains("/anime/") { continue; }
        let name = clean_sub_indo(html_decode(rendered));
        if name == "" { continue; }
        let media = a?._embedded?["wp:featuredmedia"]?[0];
        let image = media?.media_details?.sizes?.medium?.source_url ?? media?.source_url ?? "";
        out.push(#{ name: name, url: url, image: image });
    }
    out
}

fn parse_search(body) {
    let out = [];
    for a in select(body, "article.animepost div.animposx > a[href], article.animpost div.animposx > a[href]") {
        let href = attr(a, "href");
        let title = clean_sub_indo(attr(a, "title"));
        if title == "" {
            for t in select(a.html, ".title") { title += t.text; }
            title = clean_sub_indo(title);
        }
        if !href.contains("/anime/") || title == "" { continue; }
        let img = select(a.html, "img");
        out.push(#{ name: title, url: href, image: if img.is_empty() { "" } else { attr(img[0], "src") } });
    }
    out
}

fn episodes(url) {
    try {
        let eps = rest_episodes(url);
        if !eps.is_empty() { return eps; }
    } catch (err) {
        debug(`${global::LABEL}: REST episode list failed (${err}); parsing the page`);
    }
    // The series page itself only lists the newest 100 episodes.
    parse_episodes(page(url, referer()))
}

// Every episode post shares the series' category:
// /anime?slug=<slug> → category → /posts?categories=<c> (100 per page, 4 pages at a time).
fn rest_episodes(anime_url) {
    let parsed = url_parse(anime_url);
    if parsed == () { throw `${global::LABEL}: not a link: ${anime_url}`; }
    let segments = parsed.path.split("/").filter(|s| s != "");
    let slug = segments.pop() ?? "";
    let series = json_parse(fetch(`${global::BASE}/wp-json/wp/v2/anime?slug=${slug}&_fields=id,categories`, #{ referer: referer() }).body);
    let category = series?[0]?.categories?[0];
    if type_of(category) != "i64" { throw `${global::LABEL}: no category for ${slug}`; }

    let first = fetch(posts_page(category, 1), #{ referer: referer() });
    let pages = 1;
    try { pages = parse_int(first.headers["x-wp-totalpages"] ?? "1"); } catch (err) {}
    if pages > 50 { pages = 50; }
    let urls = [];
    for n in 2..=pages { urls.push(posts_page(category, n)); }
    let bodies = [first.body] + fetch_all(urls, #{ referer: referer() }).map(|r| r.body);

    let seen = #{};
    let out = [];
    for body in bodies {
        for ep in parse_rest_episodes(body) {
            let k = `${ep.num}`;
            if !seen.contains(k) {
                seen[k] = true;
                out.push(ep);
            }
        }
    }
    out
}

fn posts_page(category, n) {
    `${global::BASE}/wp-json/wp/v2/posts?categories=${category}&per_page=100&page=${n}&_fields=link,title`
}

fn parse_rest_episodes(body) {
    let posts = json_parse(body);
    if type_of(posts) != "array" { throw `${global::LABEL}: unexpected REST posts response`; }
    let out = [];
    for p in posts {
        let url = p?.link;
        let rendered = p?.title?.rendered;
        if type_of(url) != "string" || type_of(rendered) != "string" { continue; }
        let title = html_decode(rendered);
        title.trim();
        if url.contains("/batch/") || title.to_lower().contains("batch") { continue; }
        let num = episode_num(title) ?? episode_num(url);
        if num == () || num <= 0 { continue; }
        out.push(#{ num: num, url: url, title: title });
    }
    out
}

fn episode_num(s) {
    let m = regex_match(s, global::EPISODE_NUM);
    if m == () { () } else { parse_int(m[1]) }
}

fn parse_episodes(body) {
    // Current Tailwind layout: each row's title is an `h4 > a` ("… Episode 12 [END]").
    let seen = #{};
    let current = [];
    for a in select(body, "h4 > a[href]") {
        let href = attr(a, "href");
        let num = episode_num(a.text) ?? episode_num(href);
        if num == () || num <= 0 || seen.contains(href) { continue; }
        seen[href] = true;
        current.push(#{ num: num, url: href, title: a.text });
    }
    if !current.is_empty() { return current; }

    // Older "eastplay" layout.
    let out = [];
    for li in select(body, "div.lstepsiode ul li") {
        let a = select(li.html, "span.eps a");
        if a.is_empty() { continue; }
        let href = attr(a[0], "href");
        let num = ();
        try { num = parse_int(a[0].text); } catch (err) {}
        num = num ?? episode_num(href);
        if num == () || num <= 0 || href == "" { continue; }
        let t = select(li.html, "span.lchx a");
        out.push(#{ num: num, url: href, title: if t.is_empty() { "" } else { t[0].text } });
    }
    out
}

// One player entry each. `embed` is the iframe/file URL when the page carries
// it (`data-embed`, or a download-list Pixeldrain link); otherwise it comes
// from admin-ajax with post/nume/type. Keeps only the hosts this plugin understands.
fn parse_servers(body) {
    let out = [];
    for d in select(body, "#server .east_player_option") {
        let lower = d.text.to_lower();
        if !["pixel", "blogspot", "wibufile"].some(|h| lower.contains(h)) { continue; }
        let s = #{
            post: attr(d, "data-post"),
            nume: attr(d, "data-nume"),
            kind: attr(d, "data-type"),
            embed: iframe_src(attr(d, "data-embed")),
            height: height_of(d.text),
        };
        if s.embed != "" || (s.post != "" && s.nume != "") { out.push(s); }
    }
    // Direct per-resolution Pixeldrain files live in the download list.
    let seen = #{};
    for li in select(body, ".download-eps li") {
        let strong = select(li.html, "strong");
        let height = if strong.is_empty() { 0 } else { height_of(strong[0].text) };
        let a = select(li.html, `a[href*="pixeldrain.com/"]`);
        let href = if a.is_empty() { "" } else { attr(a[0], "href") };
        if height > 0 && href != "" && !seen.contains(`${height}`) {
            seen[`${height}`] = true;
            out.push(#{ post: "", nume: "", kind: "", embed: href, height: height });
        }
    }
    out
}

fn heights(url) { parse_servers(page(url, referer())).map(|s| s.height) }

fn stream(url, quality) {
    let servers = sort_by_height(parse_servers(page(url, referer())), quality);
    if servers.is_empty() { throw `${global::LABEL}: no player servers on episode page (layout changed?)`; }

    let last_err = "";
    let dead_hosts = #{};
    for s in servers {
        let embed = s.embed;
        if embed == "" {
            try {
                let form = #{ action: "player_ajax", post: s.post, nume: s.nume, "type": s.kind };
                let r = fetch(`${global::BASE}/wp-admin/admin-ajax.php`, #{ form: form, referer: referer(), headers: #{ "X-Requested-With": "XMLHttpRequest" } });
                embed = iframe_src(r.body);
            } catch (err) {
                last_err = err;
                continue;
            }
        }
        let u = resolve_embed(embed);
        if u == "" {
            try { u = resolve_wibufile(embed); } catch (err) {
                last_err = err;
                continue;
            }
        }
        // Unknown host, or a removed file: try the next server. A host that
        // failed once is skipped for its other resolutions (dead CDNs time out).
        let host = url_parse(u)?.host ?? "";
        if u == "" || dead_hosts.contains(host) { continue; }
        if !u.contains("blogger.com") && !playable(u) {
            dead_hosts[host] = true;
            continue;
        }
        return #{ url: u, referer: referer() };
    }
    throw with_cause(`${global::LABEL}: no resolvable server for this episode`, last_err);
}

fn with_cause(msg, err) { if err == "" { msg } else { `${msg} (${err})` } }

fn iframe_src(markup) {
    let m = regex_match(markup, #"<iframe[^>]+src="([^"]+)""#);
    if m == () { "" } else { m[1] }
}

fn resolve_embed(src) {
    let m = regex_match(src, #"pixeldrain\.com/(?:u|api/file)/([A-Za-z0-9]+)"#);
    if m != () { return `https://pixeldrain.com/api/file/${m[1]}`; }
    let b = regex_match(src, global::BLOGGER);
    if b == () { "" } else { b[0] }
}

fn is_wibufile(u) {
    let p = url_parse(u);
    p != () && (p.scheme == "http" || p.scheme == "https") && (p.host == "wibufile.com" || p.host.ends_with(".wibufile.com"))
}

fn fetch_wibufile(url, from) {
    let r = fetch(url, #{ client: "plain", referer: from });
    if r.status != 200 { throw `${global::LABEL} wibufile: HTTP ${r.status}`; }
    r.body
}

// Embed page → `url:"…"` API → JSON {sources:[{file}]}, restricted to *.wibufile.com.
fn resolve_wibufile(src) {
    if !is_wibufile(src) { return ""; }
    if url_parse(src).path.to_lower().ends_with(".mp4") { return src; }
    let body = fetch_wibufile(src, referer());
    let m = regex_match(body, #"(?i)\burl\s*:\s*["']([^"']+)["']"#);
    if m == () { return ""; }
    let api = url_join(src, html_decode(m[1]));
    if !is_wibufile(api) { return ""; }
    let resp = json_parse(fetch_wibufile(api, src));
    for f in resp?.sources ?? [] {
        let u = url_join(api, f?.file ?? "");
        if is_wibufile(u) { return u; }
    }
    ""
}
