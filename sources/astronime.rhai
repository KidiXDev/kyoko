// astronime.id — Hydrax/Abyss player. The embed's `const datas` blob is
// decrypted by the third-party enc-dec.app service.

const BASE = "https://astronime.id";
const DECRYPT = "https://enc-dec.app/api/dec-abyss";
const LABEL = "Astronime";

fn referer() { global::BASE + "/" }

fn search(q) { parse_search(page(`${global::BASE}/?s=${url_encode(q)}`, referer())) }

fn parse_search(body) {
    let out = [];
    for card in select(body, "article.animpost") {
        let a = select(card.html, ".animposx > a, a[title]");
        if a.is_empty() { continue; }
        let title = a[0].attrs.title ?? a[0].text;
        let href = url_join(referer(), attr(a[0], "href"));
        if title == "" || href == "" { continue; }
        let img = select(card.html, "img");
        let src = if img.is_empty() { "" } else { img[0].attrs["data-src"] ?? img[0].attrs.src ?? "" };
        out.push(#{ name: title, url: href, image: url_join(referer(), src) });
    }
    out
}

fn episodes(url) {
    let seen = #{};
    let out = [];
    for a in select(page(url, referer()), `a[href*="-episode-"]`) {
        let href = url_join(referer(), attr(a, "href"));
        let m = regex_match(`${href} ${a.text}`, #"(?i)episode[-\s]+(\d+)"#);
        if m == () { continue; }
        let num = parse_int(m[1]);
        if num < 1 || href == "" || seen.contains(href) { continue; }
        seen[href] = true;
        out.push(#{ num: num, url: href, title: `Episode ${num}` });
    }
    out
}

// Episode page → Hydrax server → admin-ajax iframe → embed `datas` → decrypt.
// Kept 2 minutes: the qualities and then the stream both need it.
fn sources(url) {
    let cached = cache_get(url);
    if cached != () { return cached; }
    let body = page(url, referer());
    let hydrax = select(body, ".east_player_option").filter(|o| o.text.to_lower().contains("hydrax"));
    let post = if hydrax.is_empty() { "" } else { attr(hydrax[0], "data-post") };
    let nume = if hydrax.is_empty() { "" } else { attr(hydrax[0], "data-nume") };
    if post == "" || nume == "" { throw `${global::LABEL}: Hydrax server not found (page layout changed?)`; }

    let form = #{ action: "player_ajax", post: post, nume: nume, "type": "urliframe" };
    let player = fetch(`${global::BASE}/wp-admin/admin-ajax.php`, #{ form: form, referer: url, headers: #{ Origin: global::BASE } }).body;
    let iframe = select(player, "iframe[src]");
    let embed_url = if iframe.is_empty() { "" } else { url_join(referer(), attr(iframe[0], "src")) };
    if embed_url == "" { throw `${global::LABEL}: Hydrax iframe not found`; }

    let blob = regex_match(fetch(embed_url, #{ referer: url }).body, #"const\s+datas\s*=\s*"([^"]+)""#);
    if blob == () { throw `${global::LABEL}: encrypted player data not found`; }
    let decrypted = fetch(global::DECRYPT, #{ json: #{ text: blob[1] }, referer: "https://playhydrax.com/", headers: #{ Origin: "https://playhydrax.com" } }).body;
    let result = #{ files: parse_decrypted(decrypted), referer: embed_url };
    cache_set(url, result, 120);
    result
}

fn is_web(u) {
    let p = url_parse(u);
    p != () && (p.scheme == "http" || p.scheme == "https")
}

fn parse_decrypted(body) {
    let r = ();
    try { r = json_parse(body); } catch (err) { throw `${global::LABEL} Hydrax decode: invalid decoder response: ${err}`; }
    if r?.status != 200 { throw `${global::LABEL} Hydrax decode: decoder rejected player data`; }
    let out = [];
    for s in r?.result?.sources ?? [] {
        let label = s?["type"];
        if s?.status == true && type_of(label) == "string" && height_of(label) > 0 && type_of(s?.url) == "string" && is_web(s.url) {
            out.push(#{ file: s.url, height: height_of(label) });
        }
    }
    if out.is_empty() { throw `${global::LABEL} Hydrax decode: no media sources found`; }
    out
}

fn heights(url) { sources(url).files.map(|f| f.height) }

fn stream(url, quality) {
    let s = sources(url);
    for f in sort_by_height(s.files, quality) {
        if playable(f.file, s.referer) { return #{ url: f.file, referer: s.referer }; }
    }
    throw `${global::LABEL}: no playable Hydrax media file`;
}
