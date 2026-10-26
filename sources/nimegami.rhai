// nimegami.id — search JSON, #episode_N links, and server data in streamed page props.

const BASE = "https://nimegami.id";
const LABEL = "Nimegami";
const EPISODE_ID = #"^(?:play_eps_|episode_)((?:(?:special|ova|ona|movie)_)?\d+)$"#;

fn referer() { global::BASE + "/" }

fn is_web(u) {
    let p = url_parse(u);
    p != () && (p.scheme == "http" || p.scheme == "https") && p.host != ""
}

fn search(q) { parse_search(fetch(`${global::BASE}/api/anime-search/?q=${url_encode(q)}`, #{ referer: referer() }).body) }

fn parse_search(body) {
    let items = json_parse(body)?.suggestions;
    if type_of(items) != "array" { throw `${global::LABEL}: invalid search response`; }
    let out = [];
    for item in items {
        if type_of(item?.slug) != "string" || type_of(item?.title) != "string" || item.title == "" { continue; }
        if regex_match(item.slug, #"^[a-z0-9][a-z0-9-]*$"#) == () { continue; }
        let image = if type_of(item?.poster) == "string" { url_join(referer(), item.poster) } else { "" };
        out.push(#{ name: item.title, url: `${global::BASE}/${item.slug}/`, image: if is_web(image) { image } else { "" } });
    }
    out
}

// Decode and join streamed chunks before parsing: a JSON record can span scripts.
fn player_data(body) {
    let flight = "";
    for script in select(body, "script") {
        let m = regex_match(html_decode(script.html), #"(?s)^\s*self\.__next_f\.push\((\[.*\])\)\s*;?\s*$"#);
        if m == () { continue; }
        let chunk = json_parse(m[1]);
        if chunk.len() == 2 && chunk[0] == 1 && type_of(chunk[1]) == "string" { flight += chunk[1]; }
    }
    for row in flight.split("\n") {
        if !row.contains(#""links":["#) { continue; }
        let pending = [json_parse(row.sub_string(row.index_of(":") + 1))];
        while !pending.is_empty() {
            let value = pending.pop();
            if type_of(value) == "array" { pending += value; }
            else if type_of(value) == "map" {
                if type_of(value?.links) == "array" { return value; }
                pending += value.values();
            }
        }
    }
    throw `${global::LABEL}: no player data on the page`;
}

// Accept old saved #play_eps_N URLs as well as the current #episode_N anchors.
fn split_episode_url(u) {
    u.trim();
    let i = u.index_of("#");
    if i < 0 { return [u, ""]; }
    let m = regex_match(u.sub_string(i + 1), global::EPISODE_ID);
    [u.sub_string(0, i), if m == () { "" } else { m[1] }]
}

fn episodes(url) {
    let page_url = split_episode_url(url)[0];
    parse_episodes(page(page_url, referer()), page_url)
}

fn parse_episodes(body, page_url) {
    let out = [];
    let seen = #{};
    for a in select(body, ".episode-grid a[href]") {
        let id = split_episode_url(attr(a, "href"))[1];
        if id == "" || seen.contains(id) { continue; }
        seen[id] = true;
        let n = regex_match(id, #"(\d+)$"#);
        out.push(#{ num: parse_int(n[1]), url: `${page_url}#episode_${id}`, title: attr(a, "title") });
    }
    out
}

fn parse_entries(body, episode) {
    let out = [];
    for e in player_data(body).links {
        if e?.kind == "batch" || type_of(e?.episode) != "i64" || type_of(e?.quality) != "string" { continue; }
        let kind = e?.episodeType ?? "episode";
        let id = if kind == "episode" { `${e.episode}` } else { `${kind}_${e.episode}` };
        if id != episode { continue; }
        if type_of(e?.playUrl) != "string" { continue; }
        let u = url_join(referer(), e.playUrl);
        if !is_web(u) { continue; }
        let p = url_parse(u);
        if ["vsys-srv.berkasdrive.com", "vsys-meledak.dlgan.my.id"].contains(p.host) {
            u.replace("/hal/download/", "/hal/streaming/");
        } else if e?.mode != "embed" && e?.mode != "video" { continue; }
        out.push(#{ height: height_of(e.quality), url: u, direct: e?.mode == "video" });
    }
    out
}

fn episode_entries(url) {
    let parts = split_episode_url(url);
    if parts[1] == "" { throw `${global::LABEL}: not a nimegami episode URL: ${url}`; }
    let entries = parse_entries(page(parts[0], referer()), parts[1]);
    if entries.is_empty() { throw `${global::LABEL}: no streaming servers for episode ${parts[1]}`; }
    entries
}

fn heights(url) {
    let out = episode_entries(url).map(|e| e.height).filter(|h| h > 0);
    out.sort();
    out.dedup();
    out
}

fn stream(url, quality) {
    let last_err = "";
    for e in sort_by_height(episode_entries(url), quality) {
        try {
            let file = if e.direct { e.url } else { resolve_embed(e.url) };
            if is_web(file) && playable(file, referer()) { return #{ url: file, referer: referer() }; }
        } catch (err) { last_err = err; }
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
        return api.url;
    }
    media_url(body)
}

fn media_url(body) {
    let sources = select(body, "#player[data-src], video[src], source[src]");
    for s in sources {
        let u = if attr(s, "data-src") != "" { attr(s, "data-src") } else { attr(s, "src") };
        if is_web(u) { return u; }
    }
    throw `${global::LABEL}: no media URL in streaming page`;
}
