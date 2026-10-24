echo("\u017e", "\U01F600", "\u0041\u00e9", "\uD800x", "\u0000y", "\uFFFEz", "\x41", len("\U01F600\u017e"));
echo(ord("\u017e"), ord("\U01F600"), chr(0xD800), chr(0xFFFE), chr(0xFDD0), chr(0x10FFFF), chr(0x110000));
