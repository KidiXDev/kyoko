const PLAYER = #"<script>self.__next_f.push([0]);</script><script>self.__next_f.push([1, "1e:[\"$\",\"$L22\",null,{\"children\":[\"$\",\"section\",null,{\"children\":[[\"$\",\"$L28\",\"kimi\",{\"links\":[{\"url\":\"https://vsys-srv.berkasdrive.com/hal/download/id?name=kimi.mp4\",\"playUrl\":\"https://vsys-srv.berkasdrive.com/hal/download/id?name=kimi.mp4\",\"quality\":\"360p\",\"ki"]);</script><script>self.__next_f.push([1, "nd\":\"episode\",\"episode\":2,\"mode\":\"external\",\"provider\":\"BerkasDrive\"},{\"playUrl\":\"https://workers-anime.berkasdrive.com/https://desustream.net/dstream/arcg/?id=x\",\"quality\":\"720p\",\"kind\":\"episode\",\"episode\":2,\"mode\":\"embed\",\"idAliases\":[\"old-id\"],\"noteTitle\":\"Kimi \\\"Title\\\"\"},{\"playUrl\":\"https://cdn.example/kimi.mp4?token=a&expires=1\",\"quality\":\"720p\",\"kind\":\"episode\",\"episode\":2,\"mode\":\"video\"},{\"playUrl\":\"/kimi/streaming/2/1080p/id/\",\"quality\":\"1080p\",\"kind\":\"episode\",\"episode\":2,\"episodeType\":\"episode\",\"mode\":\"embed\"},{\"playUrl\":\"https://e/special\",\"quality\":\"480p\",\"kind\":\"episode\",\"episode\":2,\"episodeType\":\"special\",\"mode\":\"embed\"},{\"playUrl\":\"https://e/batch.rar\",\"quality\":\"1080p\",\"kind\":\"batch\",\"episode\":2,\"mode\":\"embed\"},{\"playUrl\":\"https://e/other\",\"quality\":\"1080p\",\"kind\":\"episode\",\"episode\":3,\"mode\":\"embed\"},{\"playUrl\":\"https://mega.nz/embed/x\",\"quality\":\"1080p\",\"kind\":\"episode\",\"episode\":2,\"mode\":\"external\"},{\"playUrl\":\"javascript:alert(1)\",\"quality\":\"1080p\",\"kind\":\"episode\",\"episode\":2,\"mode\":\"embed\"},{\"playUrl\":\"https://e/bad\",\"quality\":null,\"kind\":\"episode\",\"episode\":2,\"mode\":\"embed\"},{\"playUrl\":\"https://e/bad\",\"quality\":\"1080p\",\"kind\":\"episode\",\"episode\":\"2\",\"mode\":\"embed\"}],\"title\":\"Kimi\",\"episodeInfo\":[{\"number\":2,\"title\":\"Episode 2\"}]}]]}]}]\n"])</script>"#;

fn test_search_json() {
    let s = parse_search(#"{"suggestions":[{"slug":"sousou-no-frieren-sub-indo","title":"Sousou no Frieren","poster":"/assets/anime-data/images/posters/frieren.jpg"},{"slug":"bad/path","title":"bad"},{"slug":"missing-title"},{"slug":"no-poster","title":"No poster"},{"slug":"bad-image","title":"Bad image","poster":"javascript:alert(1)"}]}"#);
    assert_eq(s.len(), 3);
    assert_eq(s[0].name, "Sousou no Frieren");
    assert_eq(s[0].url, "https://nimegami.id/sousou-no-frieren-sub-indo/");
    assert_eq(s[0].image, "https://nimegami.id/assets/anime-data/images/posters/frieren.jpg");
    assert_eq([s[1].image, s[2].image], ["", ""]);
    assert_eq(parse_search(#"{"suggestions":[]}"#), []);
    let failed = false;
    try { parse_search("{}"); } catch (err) { failed = true; }
    assert(failed, "invalid search data must fail");
}

fn test_episode_anchors_and_saved_urls() {
    let url = "https://nimegami.id/kimi/";
    let episodes = parse_episodes(`<div class="episode-grid"><a href="#episode_2" title="Episode 2">2</a><a href="#episode_1" title="Episode 1">1</a><a href="#episode_special_2" title="Special 2">2</a><a href="#episode_2">duplicate</a><a href="#episode_x">bad</a><a href="javascript:x">bad</a></div><a href="#episode_99">unrelated</a>`, url);
    assert_eq(episodes.len(), 3);
    assert_eq(episodes[0], #{ num: 2, url: url + "#episode_2", title: "Episode 2" });
    assert_eq(episodes[2].url, url + "#episode_special_2");
    assert_eq(split_episode_url(url + "#play_eps_12"), [url, "12"]);
    assert_eq(split_episode_url(url + "#episode_12"), [url, "12"]);
    assert_eq(split_episode_url(url + "#episode_special_2"), [url, "special_2"]);
    assert_eq(split_episode_url(url)[1], "");
    assert_eq(split_episode_url(url + "#episode_x")[1], "");
}

fn test_streamed_player_data_and_servers() {
    let data = player_data(global::PLAYER);
    assert_eq(data.title, "Kimi");
    assert_eq(data.links.len(), 11);
    let entries = parse_entries(global::PLAYER, "2");
    assert_eq(entries.len(), 4);
    assert_eq(entries[0], #{ height: 360, url: "https://vsys-srv.berkasdrive.com/hal/streaming/id?name=kimi.mp4", direct: false });
    assert_eq(entries[1].height, 720);
    assert_eq(entries[2].direct, true);
    assert_eq(entries[2].url, "https://cdn.example/kimi.mp4?token=a&expires=1");
    assert_eq(entries[3], #{ height: 1080, url: "https://nimegami.id/kimi/streaming/2/1080p/id/", direct: false });
    assert_eq(parse_entries(global::PLAYER, "special_2")[0].url, "https://e/special");
    assert_eq(parse_entries(global::PLAYER, "99"), []);
    let failed = false;
    try { player_data("<p>no player</p>"); } catch (err) { failed = true; }
    assert(failed, "a changed or missing player must fail clearly");
}

fn test_current_media_players() {
    assert_eq(media_url(`<main id="player" data-src="https://cdn.example/video.mp4?token=a&amp;expires=1"></main>`), "https://cdn.example/video.mp4?token=a&expires=1");
    assert_eq(media_url(`<video src="https://workers-anime.berkasdrive.com/https://cdn.example/a.mp4?token=x&amp;expires=1"></video>`), "https://workers-anime.berkasdrive.com/https://cdn.example/a.mp4?token=x&expires=1");
    assert_eq(media_url(`<video><source src="https://cdn.example/legacy.mp4?token=x"></video>`), "https://cdn.example/legacy.mp4?token=x");
    let failed = false;
    try { media_url(`<video src="javascript:alert(1)"></video>`); } catch (err) { failed = true; }
    assert(failed, "non-web media URLs must be rejected");
}
