fn test_parses_episodes_and_player() {
    let e = parse_episodes(`<table><tr><td id="3"><a class="moe-stream-a" href="https://moeclip.com/x/3/">S</a></td></tr>
<tr><td><a class="moe-stream-a" href="https://moeclip.com/x/12/">S</a></td></tr>
<tr><td id="3"><a class="moe-stream-a" href="https://moeclip.com/x/3/">dup</a></td></tr></table>`);
    assert_eq(e.map(|e| e.num), [3, 12]);

    let p = parse_player(`<button class="mirrorlist aktif" meta-src="abc">M</button><span id="down-title">991</span>
<select id="source"><option value="480p">480p</option><option value="720p">720p</option></select>`, "https://moeclip.com");
    assert_eq([p.media_id, p.post_id], ["abc", "991"]);
    assert_eq(p.qualities, ["720p", "480p"]);
}
