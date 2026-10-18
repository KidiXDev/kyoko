fn test_search() {
    let out = parse_search(`{"results":[{"slug":"toumei-subtitle-indonesia","title":"Toumei Subtitle Indonesia ","thumbnailUrl":"/uploads/toumei.webp"},{"slug":"other","title":"Other","thumbnailUrl":"https://gbr.sokuja.uk/other.jpg"},{"title":"Missing slug"}]}`);
    assert_eq(out.len(), 2);
    assert_eq(out[0], #{ name: "Toumei", url: "https://x6.sokuja.uk/anime/toumei-subtitle-indonesia/", image: "https://x6.sokuja.uk/uploads/toumei.webp" });
    assert_eq(out[1].image, "https://gbr.sokuja.uk/other.jpg");
    assert_eq(parse_search(`{"results":[]}`), []);
}

fn test_episode_list() {
    let out = parse_episodes(`<main id="main-content"><a href="/toumei-episode-12-subtitle-indonesia/"><span>Toumei Episode 12</span><span>3 minggu lalu</span></a>
        <a href="/toumei-episode-1-subtitle-indonesia/"><span>Toumei Episode 1</span></a>
        <a href="/toumei-episode-1-subtitle-indonesia/">Duplicate</a>
        <a href="https://ads.example/toumei-episode-2-subtitle-indonesia/">Ad</a><a href="/anime/toumei/">Series</a></main>
        <aside><a href="/other-episode-3-subtitle-indonesia/">Recent comment</a></aside>`);
    assert_eq(out.len(), 2);
    assert_eq(out[0].num, 12);
    assert_eq(out[0].title, "Toumei Episode 12");
    assert_eq(out[1].url, "https://x6.sokuja.uk/toumei-episode-1-subtitle-indonesia/");
}

fn test_player_id_and_mirrors() {
    assert_eq(episode_id(#"<script>self.__next_f.push([1,"4c:[\"$\",\"$L55\",null,{\"episodeId\":10361,\"qualityOptions\":[\"480p\"]}]"])</script>"#), "10361");
    let out = parse_mirrors(`{"mirrors":[{"embedType":"mp4","embedUrl":"https://storages.sokuja.uk/episode.480p.mp4","quality":"480p"},{"embedType":"mp4","embedUrl":"https://storages.sokuja.uk/episode.1080p.mp4","quality":"1080p"},{"embedType":"iframe","embedUrl":"https://embed.example/player","quality":"720p"},{"embedType":"mp4","embedUrl":"javascript:bad","quality":"720p"}]}`);
    assert_eq(out.len(), 2);
    assert_eq(out.map(|m| m.height), [480, 1080]);
    assert_eq(sort_by_height(out, "best")[0].height, 1080);
    assert_eq(sort_by_height(out, "480p")[0].height, 480);
    assert_eq(parse_mirrors(`{"mirrors":[]}`), []);
    for body in ["<html>Challenge</html>", "{}"] {
        let failed = false;
        try { parse_mirrors(body); } catch (err) { failed = true; }
        assert(failed, "invalid player responses must fail");
    }
    let failed = false;
    try { episode_id("<html>No player</html>"); } catch (err) { failed = true; }
    assert(failed, "a missing episode ID must fail");
}
