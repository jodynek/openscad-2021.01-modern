s = "Příliš žluťoučký kůň 😀 end";
echo(len(s), s[0], s[1], s[2], s[6], s[20], s[21], s[22], s[len(s)-1], s[len(s)]);
echo(ord("ž"), ord("😀"), ord("a"), ord(""), chr(382), chr(128512), chr(65), chr(0), chr(-1), chr(1114112), chr(55296), chr([380, 382, 128512]));
echo(search("ž", s), search("ň", s, 0), search("žk", s, 0), search("x", s), search("😀", s));
echo(search("ž", [["ž", 1], ["k", 2], ["😀", 3]]), search("😀k", [["ž", 1], ["k", 2], ["😀", 3]], 0));
echo(str("a", "ž", "😀"), concat(["ž"], ["😀"]), [for (c = s) c]);
linear_extrude(1) text("ž😀Ab", size=10);
