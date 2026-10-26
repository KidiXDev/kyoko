fn test_search_tables() {
    let row = `<table class="otable"><tr><td class="vithumb"><img data-original="/img/cover.jpg" src="/loading.gif"></td><td class="videsc"><a href="/anime/one-piece/"> One Piece Subtitle Indonesia </a></td></tr></table>`;
    let bad = `<table class="otable"><tr><td class="videsc"><a href="https://evil.test/anime/fake/">Fake</a></td></tr></table>`;
    assert_eq(parse_search(row + row + bad), [#{ name: "One Piece", url: global::BASE + "/anime/one-piece/", image: global::BASE + "/img/cover.jpg" }]);
    assert_eq(parse_search("No results"), []);
}

fn test_episode_numbers_and_duplicates() {
    let body = `<div class="ep"><a href="/one-piece-episode-001/">001</a><a href="/one-piece-episode-001/">Duplicate</a><a href="/one-piece-episode-1180/">1180</a><a href="/one-piece-episode-000/">0</a><a href="/batch/">Batch</a><a href="https://evil.test/fake-episode-2/">Fake</a></div><aside><a href="/other-episode-99/">Other</a></aside>`;
    let eps = parse_episodes(body, global::BASE + "/anime/one-piece/");
    assert_eq(eps.len(), 2);
    assert_eq(eps[0], #{ num: 1, url: global::BASE + "/one-piece-episode-001/", title: "Episode 1" });
    assert_eq(eps[1].num, 1180);
}

fn test_blogger_players() {
    let body = `<iframe id="tontonin" src="https://blogger.com/video.g?token=sample_token"></iframe><div class="servers"><a data-video="https://www.blogger.com/video.g?token=sample_token">B-TUBE</a><a data-video="https://www.mp4upload.com/embed-test.html">MP4</a><a data-video="https://blogger.com.evil.test/video.g?token=fake">Fake</a><a data-video="javascript:alert(1)">Invalid</a><a data-video="https://blogger.com/video.g">Empty</a></div>`;
    assert_eq(parse_players(body, global::BASE), [#{ url: "https://www.blogger.com/video.g?token=sample_token", height: 0 }]);
    assert_eq(parse_players("No player", global::BASE), []);
}

fn test_xtwap_wrapper_and_media() {
    let wrapper = "https://play.xtwap.top/btube3.php?url=encoded";
    assert_eq(parse_players(`<iframe id="tontonin" src="${wrapper}"></iframe>`, global::BASE), [#{ url: wrapper, height: 0 }]);
    assert_eq(parse_players(`<iframe id="tontonin" src="https://evil.test/btube3.php?url=encoded"></iframe>`, global::BASE), []);
    let body = `<video id="mediaplayer"><source src="https://media.test/video.mp4?a=1&amp;b=2"><source src="javascript:alert(1)"></video>`;
    assert_eq(parse_media(body, wrapper), ["https://media.test/video.mp4?a=1&b=2"]);
    assert_eq(parse_media(`sources:[{"file":"https://hls.xtwap.top/video/index.m3u8"}]`, wrapper), ["https://hls.xtwap.top/video/index.m3u8"]);
    assert_eq(parse_players(`<div class="servers"><a data-video="https://play.xtwap.top/cepat2.php?url=encoded">GDRIVE</a></div>`, global::BASE).len(), 1);
}
