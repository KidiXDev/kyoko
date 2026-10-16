fn test_parses_search_and_decrypted() {
    let s = parse_search(`<article class="animpost"><div class="animposx"><a href="/anime/x/" title="Sakamoto Days"><img data-src="/i.jpg" src="lazy.gif"></a></div></article>`);
    assert_eq([s[0].name, s[0].url, s[0].image], ["Sakamoto Days", "https://astronime.id/anime/x/", "https://astronime.id/i.jpg"]);

    let d = parse_decrypted(`{"status":200,"result":{"sources":[{"url":"https://a/720.mp4","type":"720p","status":true},{"url":"https://a/x","type":"auto","status":true},{"url":"https://a/1080.mp4","type":"1080p","status":false}]}}`);
    assert_eq(d.len(), 1);
    let failed = false;
    try { parse_decrypted(`{"status":500,"result":{"sources":[]}}`); } catch (err) { failed = true; }
    assert(failed, "a rejected decode is an error");
}
