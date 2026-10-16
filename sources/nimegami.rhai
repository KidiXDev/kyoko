// nimegami.id — one page holds a whole season; each `li.select-eps[data]`
// carries base64 JSON [{format, url:[embeds]}]. Episode URLs are
// <page>#play_eps_<n>. The app keeps fetched pages for 10 minutes, so the
// ~230 KB season page is read once for the list, the qualities and the stream.

const BASE = "https://nimegami.id";
const LABEL = "Nimegami";
const FRAGMENT = "#play_eps_";
const EPISODE_ID = #"^play_eps_(\d+)$"#;

fn referer() { global::BASE + "/" }

fn clean_title(s) {
    let t = regex_replace(s, #"(?i)\s*(?:sub\s+indo|subtitle\s+indonesia)?\s*(?::\s*episode.*)?$"#, "");
    t.trim();
    t
}

fn search(q) { parse_search(page(`${global::BASE}/?s=${url_encode(q)}`, referer())) }

fn parse_search(body) {
    let out = [];
    for art in select(body, "article") {
        let a = select(art.html, "h2 a");
        if a.is_empty() { continue; }
        let href = attr(a[0], "href");
        let title = clean_title(a[0].text);
        if href == "" || title == "" { continue; }
        let img = select(art.html, "img");
        out.push(#{ name: title, url: href, image: if img.is_empty() { "" } else { attr(img[0], "src") } });
    }
    out
}

// Episode number (as text) → #{entries, title}.
fn payloads(body) {
    let out = #{};
    for li in select(body, "li.select-eps[data]") {
        let m = regex_match(attr(li, "id"), global::EPISODE_ID);
        if m == () { continue; }
        try {
            let entries = json_parse(base64_decode(attr(li, "data")));
            if type_of(entries) == "array" && !entries.is_empty() && entries.all(|e| type_of(e?.format) == "string" && type_of(e?.url) == "array") {
                out[`${parse_int(m[1])}`] = #{ entries: entries, title: clean_title(attr(li, "title")) };
            }
        } catch (err) {}
    }
    out
}

// <page>#play_eps_<n> → [page, n]; n is 0 without that fragment.
fn split_episode_url(u) {
    u.trim();
    let i = u.index_of("#");
    if i < 0 { return [u, 0]; }
    let m = regex_match(u.sub_string(i + 1), global::EPISODE_ID);
    [u.sub_string(0, i), if m == () { 0 } else { parse_int(m[1]) }]
}

fn episodes(url) {
    let page_url = split_episode_url(url)[0];
    let p = payloads(page(page_url, referer()));
    p.keys().map(|n| #{ num: parse_int(n), url: `${page_url}${global::FRAGMENT}${n}`, title: p[n].title })
}

fn episode_entries(url) {
    let parts = split_episode_url(url);
    if parts[1] <= 0 { throw `${global::LABEL}: not a nimegami episode URL: ${url}`; }
    let e = payloads(page(parts[0], referer()))[`${parts[1]}`];
    if e == () { throw `${global::LABEL}: episode ${parts[1]} is not on the page`; }
    e.entries
}

fn heights(url) { episode_entries(url).map(|e| height_of(e.format)) }

fn stream(url, quality) {
    let entries = sort_by_height(episode_entries(url).map(|e| #{ height: height_of(e.format), embeds: e.url }), quality);
    let last_err = "";
    for e in entries {
        for embed in e.embeds {
            try {
                return #{ url: resolve_embed(embed), referer: referer() };
            } catch (err) { last_err = err; }
        }
    }
    throw with_cause(`${global::LABEL}: no playable server for this episode`, last_err);
}

fn with_cause(msg, err) { if err == "" { msg } else { `${msg} (${err})` } }

fn resolve_embed(embed) {
    let body = fetch(embed, #{ referer: referer() }).body;
    let m = regex_match(body, #"STREAM_URL_API\s*=\s*["']([^"']+)["']"#);
    if m != () {
        let api = json_parse(fetch(url_join(embed, m[1]), #{ referer: referer() }).body);
        if api?.ok != true || type_of(api?.url) != "string" || api.url == "" { throw `${global::LABEL} stream API: no media URL in response`; }
        if !playable(api.url) { throw `${global::LABEL}: file not served from here`; }
        return api.url;
    }
    // Legacy layout: <source src="…mp4?filename=…">; the filename query has unescaped spaces.
    let s = regex_match(body, #"<source[^>]+src=["']([^"']+)["']"#);
    if s == () { throw `${global::LABEL}: no <source> in streaming page`; }
    let file = s[1].split("?")[0];
    if !playable(file) { throw `${global::LABEL}: file not served from here`; }
    file
}
