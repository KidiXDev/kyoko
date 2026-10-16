// Fixtures mirror the live markup of 2026-10 (toumei-na-yoru-ni-kakeru).

fn test_rest_search() {
    let body = `[{"link":"https:\/\/v2.samehadaku.how\/anime\/toumei-na-yoru-ni-kakeru\/","title":{"rendered":"Kimetsu no Yaiba &#8211; The Movie"},
        "_embedded":{"wp:featuredmedia":[{"source_url":"https://x/full.jpg","media_details":{"sizes":{"medium":{"source_url":"https://x/m.jpg"}}}}]}},
        {"link":"https:\/\/v2.samehadaku.how\/anime\/naruto\/","title":{"rendered":"Naruto"}}]`;
    let found = parse_rest(body);
    assert_eq(found.len(), 2);
    assert_eq([found[0].name, found[0].image], ["Kimetsu no Yaiba – The Movie", "https://x/m.jpg"]);
    assert_eq([found[1].url, found[1].image], ["https://v2.samehadaku.how/anime/naruto/", ""]);
    assert_eq(parse_rest("<html>blocked</html>"), ());
}

fn test_ranking() {
    let v = ["One Piece: Heroines", "Monsters", "One Piece Film: Red", "One Piece"].map(|n| #{ name: n, url: "" });
    assert_eq(rank(v, "one piece").map(|a| a.name), ["One Piece", "One Piece: Heroines", "One Piece Film: Red", "Monsters"]);
}

fn test_rest_episodes() {
    let eps = parse_rest_episodes(`[{"link":"https:\/\/v2.samehadaku.how\/one-piece-episode-1180\/","title":{"rendered":"One Piece Episode 1180"}},
        {"link":"https:\/\/v2.samehadaku.how\/batch\/x-episode-1-12-batch\/","title":{"rendered":"X Episode 1-12 [BATCH]"}},
        {"link":"https:\/\/v2.samehadaku.how\/toumei-na-yoru-ni-kakeru-episode-12-end\/","title":{"rendered":"Toumei &#8211; Episode 12 [END]"}}]`);
    assert_eq(eps.map(|e| [e.num, e.title]), [[1180, "One Piece Episode 1180"], [12, "Toumei – Episode 12 [END]"]]);
}

fn test_html_search_keeps_series_only() {
    let s = parse_search(`<article class="animepost"><div class="animposx"><a href="https://v2.samehadaku.how/toumei-na-yoru-ni-kakeru-episode-1/" title="Toumei na Yoru ni Kakeru Episode 1"></a></div></article>
<article class="animepost"><div class="animposx"><a href="https://v2.samehadaku.how/anime/toumei-na-yoru-ni-kakeru/" title="Toumei na Yoru ni Kakeru"><img src="t.jpg"></a></div></article>`);
    assert_eq(s.len(), 1);
    assert_eq([s[0].name, s[0].image], ["Toumei na Yoru ni Kakeru", "t.jpg"]);
}

fn test_episodes_both_layouts() {
    let current = parse_episodes(`<div class="max-h-[520px]"><div class="flex"><div><a href="https://v2.samehadaku.how/toumei-na-yoru-ni-kakeru-episode-12-end/">12</a></div>
<div><h4><a href="https://v2.samehadaku.how/toumei-na-yoru-ni-kakeru-episode-12-end/">Toumei na Yoru ni Kakeru Episode 12 [END]</a></h4></div></div>
<div class="flex"><div><h4><a href="https://v2.samehadaku.how/toumei-na-yoru-ni-kakeru-kimi-to-me-ni-mienai-koi-wo-shita-episode-6/">Toumei na Yoru ni Kakeru Episode 6</a></h4></div></div></div>`);
    assert_eq(current.map(|e| e.num), [12, 6]);
    assert_eq(current[0].title, "Toumei na Yoru ni Kakeru Episode 12 [END]");

    let old = parse_episodes(`<div class="lstepsiode"><ul><li><span class="eps"><a href="/one-piece-episode-1100/">1100</a></span><span class="lchx"><a>One Piece Episode 1100</a></span></li>
<li><span class="eps"><a href="/one-piece-episode-7/">x</a></span></li></ul></div>`);
    assert_eq(old.map(|e| e.num), [1100, 7]);
}

fn test_servers_from_data_embed_and_downloads() {
    let servers = parse_servers(`<div id="server"><ul>
<li><div class="east_player_option" data-post="52758" data-nume="1" data-type="schtml" data-embed="&lt;iframe src=&quot;https://www.blogger.com/video.g?token=AD6v5dz&quot; class=&quot;w-full&quot;&gt;&lt;/iframe&gt;"><span>Blogspot </span></div></li>
<li><div class="east_player_option" data-post="52758" data-nume="2" data-type="schtml" data-embed="&lt;iframe src=&quot;https://filedon.co/embed/x&quot;&gt;"><span>VIP STREAMING</span></div></li>
<li><div class="east_player_option" data-post="52758" data-nume="4" data-type="schtml" data-embed="&lt;iframe src=&quot;https://s0.wibufile.com/video01/TnYnK-12-END-MP4HD.mp4&quot;&gt;"><span>Wibufile  720p</span></div></li>
<li><div class="east_player_option" data-post="1" data-nume="3" data-type="schtml"><span>Wibufile 480p</span></div></li>
</ul></div>
<div class="download-eps"><ul><li><strong>360p</strong><div class="download-eps-links"><span><a href="https://gofile.io/d/x">Gofile</a></span><span><a href="https://pixeldrain.com/u/PDYSxwh5"> Pixeldrain</a></span></div></li></ul></div>`);
    assert_eq(servers.map(|s| [s.embed, s.height]), [
        ["https://www.blogger.com/video.g?token=AD6v5dz", 0],
        ["https://s0.wibufile.com/video01/TnYnK-12-END-MP4HD.mp4", 720],
        ["", 480], // no data-embed: resolved through admin-ajax
        ["https://pixeldrain.com/u/PDYSxwh5", 360],
    ]);
    assert_eq(resolve_embed(servers[0].embed), "https://www.blogger.com/video.g?token=AD6v5dz");
    assert_eq(resolve_embed(servers[3].embed), "https://pixeldrain.com/api/file/PDYSxwh5");
}

fn test_wibufile_host_check() {
    assert(is_wibufile("https://s0.wibufile.com/video01/episode.mp4"));
    assert(!is_wibufile("https://wibufile.com.evil.example/episode.mp4"));
}
