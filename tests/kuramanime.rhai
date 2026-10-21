fn test_search_cards() {
    let s = parse_search(`<div id="animeList"><div class="filter__gallery"><a href="https://v20.kuramanime.ing/anime/3/boruto"><div data-setbg="/cover.jpg"><h5>Boruto</h5></div></a><a href="/anime/3/boruto/episode/1"><h5>Episode</h5></a><a href="/anime?page=2">Next</a></div></div>`);
    assert_eq(s, [#{ name: "Boruto", url: "https://v20.kuramanime.ing/anime/3/boruto", image: "https://kuramanime.ing/cover.jpg" }]);
    let desktop = parse_search(`<div id="animeList"><div class="product__item"><a href="/anime/3/boruto"><div data-setbg="/cover.jpg"></div></a><div class="product__item__text"><h5><a href="/anime/3/boruto">Boruto</a></h5></div></div></div>`);
    assert_eq(desktop[0].name, "Boruto");
    assert_eq(desktop[0].image, "https://kuramanime.ing/cover.jpg");
}

fn test_popover_episodes_and_pagination() {
    let base = "https://v20.kuramanime.ing/anime/3/boruto";
    let body = `<a id="episodeLists" data-content="<a class='btn-secondary' href='/anime/3/boruto/episode/293'>Latest</a><a class='btn-danger' href='/anime/3/boruto/episode/1'>Ep 1</a><a class='btn-danger' href='/anime/3/boruto/episode/1'>Duplicate</a><a class='btn-danger' href='/anime/3/boruto/episode/2'>Ep 2</a><a class='page__link__episode' href='?page=2'>Next</a><a href='/anime/3/boruto/batch/1-25'>Batch</a>"></a>`;
    let eps = parse_episodes(body, base);
    assert_eq(eps.len(), 2);
    assert_eq(eps[0], #{ num: 1, url: base + "/episode/1", title: "Episode 1" });
    assert_eq(next_page(body, base), base + "?page=2");
    assert_eq(next_page(body, base + "?page=2"), "");
    assert_eq(next_page(`<a class="page__link__episode" href="https://other.test/anime/3/boruto?page=3">Next</a>`, base), "");
    assert_eq(parse_episodes(`<div id="animeEpisodes"><a href="/anime/3/boruto/episode/7">Ep 7</a></div>`, base)[0].num, 7);
}

fn test_player_settings_and_media() {
    assert_eq(js_value(`MIX_AUTH_KEY: 'test-key', MIX_PAGE_TOKEN_KEY: "page-key"`, "MIX_PAGE_TOKEN_KEY"), "page-key");
    let failed = false;
    try { js_value("", "MIX_AUTH_KEY"); } catch (err) { failed = true; }
    assert(failed, "missing settings must fail clearly");
    let s = parse_sources(`<video id="player" data-hls-src=""><source src="https://media.test/a.mp4?x=1&amp;y=2" size="720"><source src="/b.mp4" size="360"><source src="javascript:alert(1)" size="1080"></video>`, "https://v20.kuramanime.ing/");
    assert_eq(s, [#{ url: "https://media.test/a.mp4?x=1&y=2", height: 720 }, #{ url: "https://v20.kuramanime.ing/b.mp4", height: 360 }]);
    assert_eq(parse_sources(`<video id="player" data-hls-src="https://media.test/master.m3u8"></video>`, "https://v20.kuramanime.ing/")[0].height, 0);
    assert_eq(parse_sources(`<iframe src="https://ads.test/"></iframe>`, "https://v20.kuramanime.ing/"), []);
}
