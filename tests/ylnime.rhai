fn test_parses_search_and_streams() {
    let s = parse_search(`<div class="card"><img src="/img/a.jpg"><a href="/?series=frieren"><h5 class="card-title">Frieren</h5></a><a href="/?series=frieren">again</a></div>`);
    assert_eq(s.len(), 1);
    assert_eq([s[0].url, s[0].image], ["https://ylnime.com/?series=frieren", "https://ylnime.com/img/a.jpg"]);

    let streams = parse_streams(`<script>const streams = [{"reso":"720p","link":"https://cdn.x/a.mp4"},{"reso":"1080p","link":"javascript:x"}];</script>`);
    assert_eq(streams.len(), 1);
    let failed = false;
    try { parse_streams("<p>nothing</p>"); } catch (err) { failed = true; }
    assert(failed, "a page without streams is an error");
}
