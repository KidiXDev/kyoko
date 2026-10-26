fn test_search_cards() {
    let card = `<div class="listupd"><div class="bsx"><a href="/anime/frieren/"><img src="/cover.jpg"><div class="tt">Sousou no Frieren</div></a></div></div>`;
    assert_eq(parse_search(card + card), [#{ name: "Sousou no Frieren", url: global::BASE + "/anime/frieren/", image: global::BASE + "/cover.jpg" }]);
    assert_eq(parse_search(`<div class="listupd"><div class="bsx"><a href="https://evil.test/anime/fake/"><div class="tt">Fake</div></a></div></div>`), []);
}

fn test_episode_list() {
    let body = `<ul id="daftarepisode"><li class="lchx"><a href="/nonton-frieren-episode-28/">Episode 28</a><a href="/nonton-frieren-episode-28/">Episode 28</a><a href="/nonton-batch/">Batch</a><a href="https://evil.test/nonton-fake/">Episode 2</a></li></ul>`;
    assert_eq(parse_episodes(body, global::BASE), [#{ num: 28, url: global::BASE + "/nonton-frieren-episode-28/", title: "Episode 28" }]);
    assert_eq(parse_episodes(`<ul id="daftarepisode"><li class="lchx"><a href="/nonton-one-piece-heroines-episode-special/">Episode Special</a></li></ul>`, global::BASE)[0].num, 1);
}

fn test_blogger_and_encoded_mirrors() {
    let url = "https://www.blogger.com/video.g?token=sample";
    let body = `<div id="pembed"><iframe src="${url}"></iframe><iframe src="https://blogger.com.evil.test/video.g?token=fake"></iframe></div><select class="mirror"><option value="PGlmcmFtZSBzcmM9Imh0dHBzOi8vd3d3LmJsb2dnZXIuY29tL3ZpZGVvLmc/dG9rZW49b3RoZXIiPjwvaWZyYW1lPg==">Blogger</option><option value="!">Broken</option></select>`;
    assert_eq(parse_players(body), [#{ url: url, height: 0 }, #{ url: "https://www.blogger.com/video.g?token=other", height: 0 }]);
    assert_eq(parse_players(`<div id="pembed"><iframe src="javascript:alert(1)"></iframe></div>`), []);
}
