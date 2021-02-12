import ternim, unicode, helper

template guarded(x, y): untyped =
  assert x.int in 0..<tb.width.int and y.int in 0..<tb.height.int
  tb.buf[tb.width * y.uint16 + x.uint16]

#Single cell:
template checkDim: bool = x in 0..<tb.width.int and y in 0..<tb.height.int

func `[]`*(tb: TermBuffer, x, y: int): TermCell =
  guarded(x, y)

func `[]=`*(tb: var TermBuffer, x, y: int, ch: TermCell) =
  if checkDim: guarded(x, y) = ch

func `[]=`*(tb: var TermBuffer, x, y: int, ch: Rune) =
  if checkDim: guarded(x, y).ch = ch

func `[]=`*(tb: var TermBuffer, x, y: int, ch: char) =
  if checkDim: guarded(x, y).ch = toRune(ch)

func `[]=`*(tb: var TermBuffer, x, y: int, ch: string) =
  assert ch.runeLen == 1
  if checkDim: guarded(x, y).ch = toRune(ch)

#Horizontal slices:
template hcheckY: bool = y >= 0 and y < tb.height.int
template hcheckX(body) =
  if currX >= tb.width.int or currX > x.b: return
  elif currX >= 0: body

template makeCulledX =
  let xCulled {.inject.} = max(x.a, 0)..min(x.b, tb.width.int - 1)

func `[]`*(tb: TermBuffer, x: Slice[int], y: int): TermCells =
  for ix in x:
    result.add guarded(ix, y)

func `[]=`*(tb: var TermBuffer, x: Slice[int], y: int, ch: TermCell) =
  if hcheckY:
    makeCulledX
    for ix in xCulled: guarded(ix, y) = ch

func `[]=`*(tb: var TermBuffer, x: Slice[int], y: int, ch: Rune) =
  if hcheckY:
    makeCulledX
    for ix in xCulled: guarded(ix, y).ch = ch

func `[]=`*(tb: var TermBuffer, x: Slice[int], y: int, ch: char) =
  if hcheckY:
    makeCulledX
    for ix in xCulled: guarded(ix, y).ch = toRune(ch)


func `[]=`*(tb: var TermBuffer, x: Slice[int], y: int, s: TermCells) =
  if hcheckY:
    var currX = x.a
    for ch in s:
      hcheckX: guarded(currX, y) = ch
      inc(currX)

func `[]=`*(tb: var TermBuffer, x: Slice[int], y: int, s: string) =
  if hcheckY:
    var currX = x.a
    for ch in s.runes:
      hcheckX: guarded(currX, y).ch = ch
      inc(currX)

#Vertical slices:
template vcheckX: bool = x >= 0 and x < tb.width.int
template vcheckY(body) =
  if currY >= tb.height.int or currY > y.b: return
  elif currY >= 0: body

template makeCulledY =
  let yCulled {.inject.} = max(y.a, 0)..min(y.b, tb.height.int - 1)

func `[]`*(tb: TermBuffer, x: int, y: Slice[int]): TermCells =
  for iy in y:
    result.add guarded(x, iy)

func `[]=`*(tb: var TermBuffer, x: int, y: Slice[int], ch: TermCell) =
  if vcheckX:
    makeCulledY
    for iy in yCulled: guarded(x, iy) = ch

func `[]=`*(tb: var TermBuffer, x: int, y: Slice[int], ch: Rune) =
  if vcheckX:
    makeCulledY
    for iy in yCulled: guarded(x, iy).ch = ch

func `[]=`*(tb: var TermBuffer, x: int, y: Slice[int], ch: char) =
  if vcheckX:
    makeCulledY
    for iy in yCulled: guarded(x, iy).ch = toRune(ch)

func `[]=`*(tb: var TermBuffer, x: int, y: Slice[int], s: TermCells) =
  if vcheckX:
    var currY = y.a
    for ch in s:
      vcheckY: guarded(x, currY) = ch
      inc currY

func `[]=`*(tb: var TermBuffer, x: int, y: Slice[int], s: string) =
  if vcheckX:
    var currY = y.a
    for ch in s.runes:
      vcheckY: guarded(x, currY).ch = ch
      inc currY

#Area slices:
template makeCulled =
  let yCulled {.inject.} = max(y.a, 0)..min(y.b, tb.height.int - 1)
  let xCulled {.inject.} = max(x.a, 0)..min(x.b, tb.width.int - 1)

func `[]`*(tb: TermBuffer, x, y: Slice[int]): seq[TermCells] =
  result.setLen y.len
  for iy in y:
    result[iy].setLen x.len
    for ix in x:
      result[iy][ix] = guarded(ix, iy)

func `[]=`*(tb: var TermBuffer, x, y: Slice[int], ch: TermCell) =
  makeCulled
  for iy in yCulled:
    for ix in xCulled: guarded(ix, iy) = ch

func `[]=`*(tb: var TermBuffer, x, y: Slice[int], ch: Rune) =
  makeCulled
  for iy in yCulled:
    for ix in xCulled: guarded(ix, iy).ch = ch

func `[]=`*(tb: var TermBuffer, x, y: Slice[int], ch: char) =
  makeCulled
  for iy in yCulled:
    for ix in xCulled: guarded(ix, iy).ch = toRune(ch)

func `[]=`*(tb: var TermBuffer, x, y: Slice[int], s: seq[TermCells]) =
  for iy in max(0, -y.a)..<min(y.len, s.len):
    for ix in max(0, -x.a)..<min(x.len, s[0].len):
      guarded(x.a + ix, y.a + iy) = s[iy][ix]

func `[]=`*(tb: var TermBuffer, x, y: Slice[int], s: string) =
  makeCulled
  var iy = y.a
  var ix = x.a
  for c in s.runes:
    if c == toRune('\n'):
      inc iy
      ix = x.a
    else:
      if iy in yCulled and ix in xCulled: # Allow windowing
        guarded(ix, iy).ch = c
      inc ix

#Convenience:
func clear*(tb: var TermBuffer) =
  for i in 0..<tb.buf.len:
    tb.buf[i] = TermCell(ch: toRune(' '), fg: None, bg: NoneBg, style: {})

