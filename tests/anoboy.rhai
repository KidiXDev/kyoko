fn test_both_search_layouts() {
    let a = parse_search(`<article class="bs"><div class="bsx"><a href="/anime/one-piece/" title="One Piece Subtitle Indonesia"><img src="/cover.jpg"></a></div></article><article class="bs"><div class="bsx"><a href="/one-piece-episode-1/" title="Episode">Episode</a></div></article>`, "https://anoboy.be");
    assert_eq(a, [#{ name: "One Piece", url: "https://anoboy.be/anime/one-piece/", image: "https://anoboy.be/cover.jpg" }]);
    let b = parse_search(`<div class="column-content"><a rel="bookmark" href="/2026/10/dragon-ball/" title="Dragon Ball"><img src="/cover.jpg"></a><a rel="bookmark" href="/download/" title="Naruto [Download]">Download</a></div>`, "https://anoboy.quest");
    assert_eq(b, [#{ name: "Dragon Ball", url: "https://anoboy.quest/2026/10/dragon-ball/", image: "https://anoboy.quest/cover.jpg" }]);
}

fn test_both_episode_lists() {
    let b = `<div class="eplister"><a href="/one-piece-episode-1180-subtitle-indonesia/">1180</a><a href="/one-piece-episode-1180-subtitle-indonesia/">Duplicate</a><a href="/one-piece-batch-1/">Batch</a></div><ul class="lcp_catlist"><li><a href="/2026/10/dragon-ball-episode-2/">Dragon Ball Episode 2</a></li></ul><aside><a href="/unrelated-episode-99/">Unrelated</a></aside>`;
    let eps = parse_episodes(b, "https://anoboy.quest/");
    assert_eq(eps.len(), 2);
    assert_eq(eps[0].num, 1180);
    assert_eq(eps[1].url, "https://anoboy.quest/2026/10/dragon-ball-episode-2/");
}

fn test_blogger_players_and_wrappers() {
    let token = "AD6v5dwOWQGFMAs8qNHMrYk5cbJVS4M1";
    let direct = "https://www.blogger.com/video.g?token=" + token;
    let b = `<iframe id="mediaplayer" src="/uploads/adsbatch720.php?url=${token}&amp;origin=example.blogspot.com"></iframe><a data-video="/uploads/adsbatch720.php?url=${token}">360</a><a data-video="/uploads/adsbatch720.php?url=none">720</a>`;
    assert_eq(parse_players(b, "https://anoboy.quest/"), [#{ url: direct, height: 0 }]);
    assert_eq(parse_players(`<div id="pembed"><iframe src="${direct}"></iframe></div>`, "https://anoboy.be/")[0].url, direct);
    assert_eq(blogger_url("javascript:alert(1)", "https://anoboy.be/"), "");
    assert_eq(blogger_url("https://evil.test/uploads/adsbatch720.php?url=" + token, "https://anoboy.quest/"), "");
    assert_eq(blogger_url("https://www.blogger.com.evil.test/video.g?token=" + token, "https://anoboy.quest/"), "");
}
