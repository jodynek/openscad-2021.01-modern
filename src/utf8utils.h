#pragma once
// Minimal UTF-8 helpers. They replace the handful of GLib functions OpenSCAD used
// (g_utf8_validate, g_utf8_get_char, g_utf8_next_char, g_utf8_offset_to_pointer,
// g_utf8_strncpy, g_utf8_strlen, g_unichar_to_utf8, g_unichar_validate) so that
// GLib is no longer a build dependency. Semantics follow the GLib originals.

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace utf8 {

// Byte length of the sequence introduced by lead byte `lead`; 0 if `lead` is not a valid lead byte.
inline int sequence_length(unsigned char lead)
{
	if (lead < 0x80) return 1;
	if ((lead & 0xE0) == 0xC0) return 2;
	if ((lead & 0xF0) == 0xE0) return 3;
	if ((lead & 0xF8) == 0xF0) return 4;
	return 0;
}

// Pointer to the start of the next character (invalid bytes are skipped one at a time).
inline const char *next_char(const char *p)
{
	const int n = sequence_length(static_cast<unsigned char>(*p));
	return p + (n ? n : 1);
}

// Decode the code point at `p`. The input is assumed to be valid UTF-8 (like g_utf8_get_char).
inline std::uint32_t get_char(const char *p)
{
	const unsigned char *s = reinterpret_cast<const unsigned char *>(p);
	switch (sequence_length(s[0])) {
	case 1: return s[0];
	case 2: return ((s[0] & 0x1Fu) << 6) | (s[1] & 0x3Fu);
	case 3: return ((s[0] & 0x0Fu) << 12) | ((s[1] & 0x3Fu) << 6) | (s[2] & 0x3Fu);
	case 4: return ((s[0] & 0x07u) << 18) | ((s[1] & 0x3Fu) << 12) | ((s[2] & 0x3Fu) << 6) | (s[3] & 0x3Fu);
	default: return 0xFFFFFFFFu;
	}
}

// True if `c` is a valid Unicode scalar value: in range and not a surrogate.
// Same rules as GLib's g_unichar_validate (noncharacters such as U+FFFE are accepted).
inline bool unichar_validate(std::uint32_t c)
{
	return c < 0x110000u && (c & 0xFFFFF800u) != 0xD800u;
}

// Validate a NUL-terminated string (max_len < 0) or the first max_len bytes.
inline bool validate(const char *str, long max_len = -1)
{
	const unsigned char *s = reinterpret_cast<const unsigned char *>(str);
	const unsigned char *end = max_len < 0 ? nullptr : s + max_len;
	while (end ? s < end : *s != 0) {
		if (*s == 0) return false; // embedded NUL within max_len
		const int n = sequence_length(*s);
		if (n == 0) return false;
		if (end && s + n > end) return false;
		for (int i = 1; i < n; ++i) {
			if ((s[i] & 0xC0u) != 0x80u) return false; // also catches a premature NUL
		}
		const std::uint32_t c = get_char(reinterpret_cast<const char *>(s));
		// reject overlong encodings, surrogates and out-of-range values
		if ((n == 2 && c < 0x80u) || (n == 3 && c < 0x800u) || (n == 4 && c < 0x10000u)) return false;
		if (c > 0x10FFFFu || (c & 0xFFFFF800u) == 0xD800u) return false;
		s += n;
	}
	return true;
}

// Number of characters in the first max_bytes bytes (or up to NUL when max_bytes < 0).
inline long strlen(const char *str, long max_bytes = -1)
{
	long count = 0;
	const char *p = str;
	const char *end = max_bytes < 0 ? nullptr : str + max_bytes;
	while (end ? p < end : *p != 0) {
		const char *next = next_char(p);
		if (end && next > end) break;
		++count;
		p = next;
	}
	return count;
}

// Pointer to the character at character index `offset` (clamped to the terminating NUL).
inline const char *offset_to_pointer(const char *str, long offset)
{
	const char *p = str;
	for (long i = 0; i < offset && *p != 0; ++i) p = next_char(p);
	return p;
}

// Copy n characters (not bytes) from src to dest and NUL-terminate dest.
inline char *strncpy_chars(char *dest, const char *src, std::size_t n)
{
	const char *p = src;
	for (std::size_t i = 0; i < n && *p != 0; ++i) p = next_char(p);
	const std::size_t bytes = static_cast<std::size_t>(p - src);
	std::memcpy(dest, src, bytes);
	dest[bytes] = 0;
	return dest;
}

// Encode code point `c` into `out` (no NUL terminator); returns the number of bytes written.
inline int encode(std::uint32_t c, char *out)
{
	unsigned char *o = reinterpret_cast<unsigned char *>(out);
	if (c < 0x80u) { o[0] = static_cast<unsigned char>(c); return 1; }
	if (c < 0x800u) { o[0] = static_cast<unsigned char>(0xC0u | (c >> 6)); o[1] = static_cast<unsigned char>(0x80u | (c & 0x3Fu)); return 2; }
	if (c < 0x10000u) {
		o[0] = static_cast<unsigned char>(0xE0u | (c >> 12));
		o[1] = static_cast<unsigned char>(0x80u | ((c >> 6) & 0x3Fu));
		o[2] = static_cast<unsigned char>(0x80u | (c & 0x3Fu));
		return 3;
	}
	o[0] = static_cast<unsigned char>(0xF0u | (c >> 18));
	o[1] = static_cast<unsigned char>(0x80u | ((c >> 12) & 0x3Fu));
	o[2] = static_cast<unsigned char>(0x80u | ((c >> 6) & 0x3Fu));
	o[3] = static_cast<unsigned char>(0x80u | (c & 0x3Fu));
	return 4;
}

} // namespace utf8
