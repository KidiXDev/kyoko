// moenime.com + moeclip.com — signed, short-lived MP4s from
// <origin>/v/<media>_<quality>_<post>.html players.

const BASE = "https://moenime.com";
const MOECLIP = "https://moeclip.com";
const LABEL = "Moenime";

fn referer() { global::BASE + "/" }

fn search(q) {
    let out = [];
    for art in select(page(`${global::BASE}/?s=${url_encode(q)}`, referer()), "article") {
        let a = select(art.html, "h1.entry-title a");
        if a.is_empty() { continue; }
        let title = regex_replace(a[0].text, #"(?i)\s*(?:\(episode\s*\d+\)\s*)?sub\s+indo\s*$"#, "");
        title.trim();
        let href = url_join(referer(), attr(a[0], "href"));
        if title == "" || href == "" { continue; }
        let img = select(art.html, ".featured-thumb img");
        out.push(#{ name: title, url: href, image: if img.is_empty() { "" } else { url_join(referer(), attr(img[0], "src")) } });
    }
    out
}

fn episodes(url) { parse_episodes(page(url, referer())) }

fn parse_episodes(body) {
    // The episode number is the id of the link's row (<td id="3">), else the end of its path.
    let rows = #{};
    for td in select(body, "td[id]") {
        for a in select(td.html, "a.moe-stream-a") {
            let href = attr(a, "href");
            if !rows.contains(href) { rows[href] = attr(td, "id"); }
        }
    }
    let seen = #{};
    let out = [];
    for a in select(body, "a.moe-stream-a") {
        let href = attr(a, "href");
        let row = rows[href] ?? "";
        if row == "" {
            let m = regex_match(href, #"/(\d+?)/?$"#);
            if m != () { row = m[1]; }
        }
        let num = 0;
        try { num = parse_int(row); } catch (err) {}
        if num < 1 || href == "" || seen.contains(href) { continue; }
        seen[href] = true;
        out.push(#{ num: num, url: href, title: `Episode ${num}` });
    }
    out
}

fn player_info(url) {
    let p = url_parse(url);
    parse_player(page(url, referer()), if p == () { "" } else { p.origin })
}

fn parse_player(body, origin) {
    let button = select(body, "button.mirrorlist.aktif");
    let media_id = if button.is_empty() { "" } else { attr(button[0], "meta-src") };
    let post = select(body, "#down-title");
    let post_id = if post.is_empty() { "" } else { post[0].text };
    let heights = [];
    for o in select(body, "#source option") {
        let m = regex_match(o.attrs.value ?? o.text, #"(?i)(\d{3,4})p"#);
        if m != () { heights.push(parse_int(m[1])); }
    }
    heights.sort();
    heights.reverse();
    heights.dedup();
    let qualities = heights.map(|h| `${h}p`);
    if media_id == "" || post_id == "" || origin == "" || origin == "null" || qualities.is_empty() {
        throw `${global::LABEL}: incomplete Moeclip player data (layout changed?)`;
    }
    #{ media_id: media_id, post_id: post_id, origin: origin, qualities: qualities }
}

fn heights(url) { player_info(url).qualities.map(|q| height_of(q)) }

fn stream(url, quality) {
    let info = player_info(url);
    let selected = sort_by_height(info.qualities, quality)[0];
    let player = `${info.origin}/v/${info.media_id}_${selected}_${info.post_id}.html`;
    let m = regex_match(fetch(player, #{ referer: referer() }).body, #"\bfile\s*:\s*['"]([^'"]+)['"]"#);
    if m == () { throw `${global::LABEL}: no media file in Moeclip player`; }
    if !playable(m[1], global::MOECLIP + "/") { throw `${global::LABEL}: Moeclip media file is not playable`; }
    #{ url: m[1], referer: `${info.origin}/` }
}
