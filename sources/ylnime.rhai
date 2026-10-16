// ylnime.com — the episode page embeds `const streams = [{reso, link}]`;
// `reso=<quality>` on the episode URL picks the resolution.

const BASE = "https://ylnime.com";
const LABEL = "YLnime";

fn referer() { global::BASE + "/" }

fn abs(raw) { url_join(referer(), raw) }

fn search(q) { parse_search(page(`${global::BASE}/?search=${url_encode(q)}`, referer())) }

fn parse_search(body) {
    let seen = #{};
    let out = [];
    for card in select(body, ".card") {
        let t = select(card.html, ".card-title");
        let title = if t.is_empty() { "" } else { t[0].text };
        let img = select(card.html, "img");
        for a in select(card.html, `a[href*="series="]`) {
            let href = abs(attr(a, "href"));
            if title == "" || href == "" || seen.contains(href) { continue; }
            seen[href] = true;
            out.push(#{ name: title, url: href, image: if img.is_empty() { "" } else { abs(attr(img[0], "src")) } });
        }
    }
    out
}

fn episodes(url) {
    let out = [];
    for a in select(page(url, referer()), `a.list-group-item[href*="episode="]`) {
        let span = select(a.html, "span");
        let label = if span.is_empty() { "" } else { span[0].text };
        let m = regex_match(label, #"(?i)episode\s*(\d+)"#);
        if m == () { continue; }
        out.push(#{ num: parse_int(m[1]), url: abs(attr(a, "href")), title: label });
    }
    out
}

fn heights(url) {
    let out = [];
    for a in select(page(url, referer()), `a[href*="reso="]`) {
        let m = regex_match(a.text, #"(?i)(\d{3,4})p"#);
        if m != () { out.push(parse_int(m[1])); }
    }
    out
}

fn is_web(u) {
    let p = url_parse(u);
    p != () && (p.scheme == "http" || p.scheme == "https") && p.host != ""
}

fn parse_streams(body) {
    let raw = regex_match(body, #"(?s)\bconst\s+streams\s*=\s*(\[[^;]*\])\s*;"#);
    if raw == () { throw `${global::LABEL}: no player streams on episode page`; }
    let streams = ();
    try { streams = json_parse(raw[1]); } catch (err) { throw `${global::LABEL}: invalid stream data: ${err}`; }
    if type_of(streams) != "array" { throw `${global::LABEL}: invalid stream data`; }
    let ok = streams.filter(|c| type_of(c?.reso) == "string" && type_of(c?.link) == "string" && is_web(c.link));
    if ok.is_empty() { throw `${global::LABEL}: player stream list is empty`; }
    ok
}

fn stream(url, quality) {
    let u = if quality != "" && quality != "best" { url_set_param(url, "reso", quality) } else { url };
    let streams = parse_streams(fetch(u, #{ referer: referer() }).body).map(|c| #{ height: height_of(c.reso), link: c.link });
    for c in sort_by_height(streams, quality) {
        if playable(c.link, referer()) { return #{ url: c.link, referer: referer() }; }
    }
    throw `${global::LABEL}: no playable server for this episode`;
}
