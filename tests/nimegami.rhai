// data is base64 of [{"format":"720p","url":["https://e/1"]},{"format":"480p","url":["https://e/2"]}].
const DATA = "W3siZm9ybWF0IjoiNzIwcCIsInVybCI6WyJodHRwczovL2UvMSJdfSx7ImZvcm1hdCI6IjQ4MHAiLCJ1cmwiOlsiaHR0cHM6Ly9lLzIiXX1d";

fn test_payloads_and_urls() {
    let html = `<ul><li class="select-eps" id="play_eps_2" data="${global::DATA}" title="Kimi Sub Indo: Episode 2">2</li>
<li class="select-eps" id="play_eps_x" data="${global::DATA}">x</li><li class="select-eps" id="play_eps_3" data="bad">3</li></ul>`;
    let p = payloads(html);
    assert_eq(p.keys(), ["2"]);
    assert_eq(p["2"].entries.len(), 2);
    assert_eq(p["2"].title, "Kimi");
    assert_eq(split_episode_url("https://nimegami.id/kimi/#play_eps_12"), ["https://nimegami.id/kimi/", 12]);
    assert_eq(split_episode_url("https://nimegami.id/kimi/")[1], 0);
}
