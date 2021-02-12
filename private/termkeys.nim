import posix

type Key* = distinct int16
func `<=`(x, y: Key): bool {.borrow.}
func `==`*(x, y: Key): bool {.borrow.}
const
  specialOffSet = 128
  altOffset = specialOffset + 23
template Alt*(k: typed): Key = Key altOffset + k.int
template Ctrl*(k: typed): Key =
  if k.int16 >= 96'i16: #lowercase
    Key k.int16 - 96
  else:
    Key k.int16 - 64
template Shift*(k: typed): Key =
  if k.int16 < 96'i64: #upeercase
    Key k
  else:
    Key k.int16 - 32
  #TODO: 0123456789 -16 = !@#$%^&&? No, at least not for @
const
  KeyNone*   = Key -1
  CtrlSpace* = Key 0
  Tab*       = Ctrl 'i'
  Enter*     = Ctrl 'm'
  Escape*    = Key 27 #not Ctrl '[' because this is '[' - 64..

  CtrlBackslash*    = Key 28
  CtrlRightBracket* = Key 29

  Backspace*   = Key 127

  #* CSI
  Up*        = Key specialOffset + 01
  Down*      = Key specialOffset + 02
  Right*     = Key specialOffset + 03
  Left*      = Key specialOffset + 04
  Home*      = Key specialOffset + 05
  Insert*    = Key specialOffset + 06
  Delete*    = Key specialOffset + 07
  End*       = Key specialOffset + 08
  PageUp*    = Key specialOffset + 09
  PageDown*  = Key specialOffset + 10

  F1*   = Key specialOffset + 11
  F2*   = Key specialOffset + 12
  F3*   = Key specialOffset + 13
  F4*   = Key specialOffset + 14
  F5*   = Key specialOffset + 15
  F6*   = Key specialOffset + 16
  F7*   = Key specialOffset + 17
  F8*   = Key specialOffset + 18
  F9*   = Key specialOffset + 19
  F10*  = Key specialOffset + 20
  F11*  = Key specialOffset + 21
  F12*  = Key specialOffset + 22

  # CSI, NYI
  #AltUp*       = Alt 1001
  #AltDown*     = Alt 1002
  #AltRight*    = Alt 1003
  #AltLeft*     = Alt 1004
  #AltHome*     = Alt 1005
  #AltInsert*   = Alt 1006
  #AltDelete*   = Alt 1007
  #AltEnd*      = Alt 1008
  #AltPageUp*   = Alt 1009
  #AltPageDown* = Alt 1010

  #AltF1*  = Alt 1011
  #AltF2*  = Alt 1012
  #AltF3*  = Alt 1013
  #AltF4*  = Alt 1014
  #AltF5*  = Alt 1015
  #AltF6*  = Alt 1016
  #AltF7*  = Alt 1017
  #AltF8*  = Alt 1018
  #AltF9*  = Alt 1019
  #AltF10* = Alt 1020
  #AltF11* = Alt 1021
  #AltF12* = Alt 1022

  #CtrlKeys* = {CtrlA..CtrlRightBracket, AltCtrlA..AltCtrlRightBracket}
  #ShiftKeys* = {ShiftA..ShiftZ, AltShiftA..AltShiftZ} #, ExclamationMark..Slash, Colon..At, Caret, Underscore, LeftBrace..Tilde
  #AltKeys* = {AltCtrlA..AltBackspace}

const keySequences = [ #Stripped of the leading '\e'
  Up:       @["OA", "[A"],
  Down:     @["OB", "[B"],
  Right:    @["OC", "[C"],
  Left:     @["OD", "[D"],
  Home:     @["[1~", "[7~", "OH", "[H"],
  Insert:   @["[2~"],
  Delete:   @["[3~"],
  End:      @["[4~", "[8~", "OF", "[F"],
  PageUp:   @["[5~"],
  PageDown: @["[6~"],
  F1:       @["[11~", "OP"],
  F2:       @["[12~", "OQ"],
  F3:       @["[13~", "OR"],
  F4:       @["[14~", "OS"],
  F5:       @["[15~"],
  F6:       @["[17~"],
  F7:       @["[18~"],
  F8:       @["[19~"],
  F9:       @["[20~"],
  F10:      @["[21~"],
  F11:      @["[23~"],
  F12:      @["[24~"]]

proc getRaw*(): string = #Here for debugging purposes :)
  var c: char
  while read(STDIN_FILENO, c.addr, 1) > 0: result.add c

var keyBuf*: array[32, char] #Here for better performance
proc getKeys*(): seq[Key] =
  let charsRead = read(STDIN_FILENO, keyBuf[0].addr, keyBuf.len)
  var i = 0
  while i < charsRead:
    block parsed:
      if keyBuf[i] == '\e' and i+1 < charsRead:
        inc i
        if keyBuf[i] in {'O', '['} and i+1 < charsRead: #Exploit the fact that all sequences start with 'O' or '['
          for keyCode, sequences in keySequences:
            for s in sequences:
              if i+s.len <= charsRead and keyBuf[i..<i+s.len] == s:
                result.add keyCode
                i += s.len
                break parsed
        else: #Alt modifier
          result.add Alt keyBuf[i]
          inc i
          break parsed
      result.add Key keyBuf[i]
      inc i
  if unlikely(not charsRead < keyBuf.len):
    while read(STDIN_FILENO, keyBuf[0].addr, 1) > 0: discard

proc getKey*(): Key =
  let charsRead = read(STDIN_FILENO, keyBuf[0].addr, keyBuf.len)
  block preReturn:
    if charsRead > 0:
      if keyBuf[0] == '\e' and charsRead > 1:
        if keyBuf[1] in {'O', '['}:
          for keyCode, sequences in keySequences:
            for s in sequences:
              if s.len <= charsRead and keyBuf[1..s.len] == s:
                result = keyCode
                break preReturn
        else:
          result = Alt keyBuf[1]
          break preReturn
      result = Key keyBuf[0]
      break preReturn
    else:
      result = KeyNone
      break preReturn
  if unlikely(not charsRead < keyBuf.len):
    while read(STDIN_FILENO, keyBuf[0].addr, 1) > 0: discard

