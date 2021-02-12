import ternim, unicode, helper

func `$`*(ch: TermCell): string = ch.ch.toUTF8

func toCellCT(ch: string): TermCell {.compileTime.} =
  assert ch.runeLen == 1
  TermCell(ch: toRune(ch), fg: None, bg: NoneBg, style: {})
func toCellRT(ch: string): TermCell =
  assert ch.runeLen == 1
  TermCell(ch: toRune(ch), fg: None, bg: NoneBg, style: {})

func cell*(ch: static string): TermCell = toCellCT(ch)
func cell*(ch: string): TermCell = toCellRT(ch)
func cell*(ch: static char): TermCell = TermCell(ch: toRune(ch), fg: None, bg: NoneBg, style: {})
func cell*(ch: char): TermCell = TermCell(ch: toRune(ch), fg: None, bg: NoneBg, style: {})

func toCellsCT(s: string, fg = None, bg = NoneBg, style: set[Style] = {}): TermCells {.compileTime.} =
  for ch in s.runes: result.add TermCell(ch: ch, fg: fg, bg: bg, style: style)
func toCellsRT(s: string, fg = None, bg = NoneBg, style: set[Style] = {}): TermCells =
  for ch in s.runes: result.add TermCell(ch: ch, fg: fg, bg: bg, style: style)

func cells*(s: static string): TermCells = toCellsCT(s)
func cells*(s: string): TermCells = toCellsRT(s)

func setFgColorCT(s: TermCells, fg: TermColor): TermCells {.used, compileTime.} =
  result = s
  for c in result.mitems: c.fg = fg
func setFgColorRT(s: TermCells, fg: TermColor): TermCells =
  result = s
  for c in result.mitems: c.fg = fg

func setBgColorCT(s: TermCells, bg: TermColorBg): TermCells {.used, compileTime.} =
  result = s
  for c in result.mitems: c.bg = bg
func setBgColorRT(s: TermCells, bg: TermColorBg): TermCells =
  result = s
  for c in result.mitems: c.bg = bg

func setStyleCT(s: TermCells, style: Style): TermCells {.used, compileTime.} =
  result = s
  for c in result.mitems: c.style.incl style
func setStyleRT(s: TermCells, style: Style): TermCells =
  result = s
  for c in result.mitems: c.style.incl style

template genFg(name, enumName: untyped) =
  func name*(s: TermCell): TermCell {.inline.} = result = s; result.fg = enumName
  template name*(c: char): TermCell = TermCell(ch: toRune(c), fg: enumName, bg: NoneBg, style: {})
  template name*(s: string{lit}): TermCell or TermCells =
    when s.len == 1: TermCell(ch: toRune(s), fg: enumName, bg: NoneBg, style: {})
    else: toCellsCT(s, fg = enumName)
  template name*(s: TermCells): TermCells = setFgColorRT(s, enumName)
  template name*(s: string): TermCells = setFgColorRT(toCellsRT(s), enumName)

template genBg(name, enumName: untyped) =
  func name*(s: TermCell): TermCell {.inline.} = result = s; result.bg = enumName
  template name*(c: char): TermCell = TermCell(ch: toRune(c), fg: None, bg: enumName, style: {})
  template name*(s: string{lit}): TermCell or TermCells =
    when s.len == 1: TermCell(ch: toRune(s), fg: None, bg: enumName, style: {})
    else: toCellsCT(s, bg = enumName)
  template name*(s: TermCells): TermCells = setBgColorRT(s, enumName)
  template name*(s: string): TermCells = setBgColorRT(toCellsRT(s), enumName)

template genStyle(name, enumName: untyped) =
  func name*(s: TermCell): TermCell {.inline.} = result = s; result.style.incl enumName
  template name*(c: char): TermCell = TermCell(ch: toRune(c), fg: None, bg: NoneBg, style: enumName)
  template name*(s: string{lit}): TermCell or TermCells =
    when s.len == 1: TermCell(ch: toRune(s), fg: None, bg: NoneBg, style: enumName)
    else: toCellsCT(s, style = enumName)
  template name*(s: TermCells): TermCells = setStyleRT(s, enumName)
  template name*(s: string): TermCells = setStyleRT(toCellsRT(s), enumName)

genFg(none, None)
genFg(black, Black)
genFg(red, Red)
genFg(green, Green)
genFg(yellow, Yellow)
genFg(blue, Blue)
genFg(magenta, Magenta)
genFg(cyan, Cyan)
genFg(white, White)
genFg(brBlack, BrBlack)
genFg(brRed, BrRed)
genFg(brGreen, BrGreen)
genFg(brYellow, BrYellow)
genFg(brBlue, BrBlue)
genFg(brMagenta, BrMagenta)
genFg(brCyan, BrCyan)
genFg(brWhite, BrWhite)

genBg(noneBg, NoneBg)
genBg(blackBg, BlackBg)
genBg(redBg, RedBg)
genBg(greenBg, GreenBg)
genBg(yellowBg, YellowBg)
genBg(blueBg, BlueBg)
genBg(magentaBg, MagentaBg)
genBg(cyanBg, CyanBg)
genBg(whiteBg, WhiteBg)
genBg(brBlackBg, BrBlackBg)
genBg(brRedBg, BrRedBg)
genBg(brGreenBg, BrGreenBg)
genBg(brYellowBg, BrYellowBg)
genBg(brBlueBg, BrBlueBg)
genBg(brMagentaBg, BrMagentaBg)
genBg(brCyanBg, BrCyanBg)
genBg(brWhiteBg, BrWhiteBg)

genStyle(bold, Bold)
genStyle(dim, Dim)
genStyle(italic, Italic)
genStyle(underlined, Underlined)
genStyle(blink, Blink)
genStyle(blinkFast, BlinkRapid)
genStyle(reversed, Reverse)
genStyle(hidden, Hidden)
genStyle(strikethrough, Strikethrough)

template paint*(fgX: TermColor, bgX: TermColorBg, styleX: set[Style]): untyped =
  (func (s: TermCells): TermCells =
     result = s
     for c in result.mitems:
       c.fg = fgX
       c.bg = bgX
       c.style = styleX) #Incl?
template paint*(fgX: TermColor, bgX: TermColorBg): untyped =
  (func (s: TermCells): TermCells =
     result = s
     for c in result.mitems:
       c.fg = fgX
       c.bg = bgX)
template paint*(fgX: TermColor, styleX: set[Style]): untyped =
  (func (s: TermCells): TermCells =
     result = s
     for c in result.mitems:
       c.fg = fgX
       c.style = styleX) #Incl?
template paint*(bgX: TermColorBg, styleX: set[Style]): untyped =
  (func (s: TermCells): TermCells =
     result = s
     for c in result.mitems:
       c.bg = bgX
       c.style = styleX) #Incl?
