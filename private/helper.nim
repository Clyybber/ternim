import unicode
template toRune*(s: string): Rune = runeAt(s, 0)
template toRune*(s: char): Rune = runeAt($s, 0)
