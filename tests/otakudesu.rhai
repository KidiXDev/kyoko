// Fixtures mirror the live markup of 2026-09-18.

const SEARCH = `<ul class="chivsrc"><li><img src="/p.jpg"/><h2><a href="https://otakudesu.blog/anime/borot-sub-indo/">Boruto: Naruto Next Generations Subtitle Indonesia</a></h2></li>
<li><h2><a href="https://otakudesu.blog/genres/action/">Not an anime</a></h2></li></ul>`;

const ANIME = `<div class="episodelist"><ul><li><span><a href="/batch/btr-batch-sub-indo/">Boruto [BATCH] Subtitle Indonesia</a></span></li></ul></div>
<div class="episodelist"><ul>
<li><span><a href="/episode/btr-ng-episode-293-sub-indo/">Boruto Episode 293 Subtitle Indonesia</a></span></li>
<li><span><a href="/episode/btr-ng-episode-1-sub-indo/">Boruto Episode 1 Subtitle Indonesia</a></span></li>
<li><span><a href="/lengkap/btr-part-6/">Boruto Part 6</a></span></li>
<li><span><a href="/episode/pembatas-episode-episode-1-900-dalam-proses/">Pembatas Episode 1-900</a></span></li>
</ul></div>`;

// data-content is base64 of {"id":138366,"i":1,"q":"720p"}.
const EPISODE = `<div class="download"><ul><li><strong>Mp4 720p</strong> <a href="/go?a">Filedon</a> <a href="/go?b">Pdrain</a></li>
<li><strong>MKV 1080p</strong> <a href="/go?c">Pdrain</a></li></ul></div>
<div class="mirrorstream"><a href="#" data-content="eyJpZCI6MTM4MzY2LCJpIjoxLCJxIjoiNzIwcCJ9">desudrive</a><a data-content="!!">bad</a></div>
<script>$.ajax(u,{data:{...e,nonce:window.__x__nonce,action:"2a3505c93b0035d3f455df82bf976b84"}});$.ajax(u,{data:{action:"aa1208d27f29ca340c92c66d1926f13f"}});</script>`;

fn test_search_skips_non_anime_and_strips_suffix() {
    let got = parse_search(global::SEARCH);
    assert_eq(got.len(), 1);
    assert_eq(got[0].name, "Boruto: Naruto Next Generations");
    assert_eq(got[0].image, "/p.jpg");
}

fn test_episodes_skip_batch_and_separators() {
    assert_eq(parse_episodes(global::ANIME).map(|e| e.num), [293, 1]);
}

fn test_downloads_and_mirrors() {
    assert_eq(parse_downloads(global::EPISODE), [#{ height: 720, url: "/go?b" }, #{ height: 1080, url: "/go?c" }]);
    assert_eq(parse_mirrors(global::EPISODE), [#{ id: 138366, i: 1, q: "720p", height: 720 }]);
    assert_eq(regex_match(global::EPISODE, #"data:\{action:"([0-9a-f]{32})"\}"#)[1], "aa1208d27f29ca340c92c66d1926f13f");
    assert_eq(regex_match(global::EPISODE, #"nonce:[^,]+,action:"([0-9a-f]{32})""#)[1], "2a3505c93b0035d3f455df82bf976b84");
}

fn test_pixeldrain_mapping() {
    assert_eq(pixeldrain_file("https://pixeldrain.com/u/AbC123"), "https://pixeldrain.com/api/file/AbC123");
    assert_eq(pixeldrain_file("https://mega.nz/file/x"), "");
}
