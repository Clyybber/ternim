import unicode, posix, termios

type
  Style* = enum   ## different styles for text output
    Bold = 1      ## bold text
    Dim           ## dim text
    Italic        ## italic (or reverse on terminals not supporting)
    Underlined    ## underlined text
    Blink         ## blinking/bold text
    BlinkRapid    ## rapid blinking/bold text (not widely supported)
    Reverse       ## reverse
    Hidden        ## hidden text
    Strikethrough ## strikethrough

  TermColor* = enum
    Black = 30       ## black
    Red              ## red
    Green            ## green
    Yellow           ## yellow
    Blue             ## blue
    Magenta          ## magenta
    Cyan             ## cyan
    White            ## white
    None = 39        ## default
    BrBlack = 90     ## bright black
    BrRed            ## bright red
    BrGreen          ## bright green
    BrYellow         ## bright yellow
    BrBlue           ## bright blue
    BrMagenta        ## bright magenta
    BrCyan           ## bright cyan
    BrWhite          ## bright white

  TermColorBg* = enum
    BlackBg = 30 + 10  ## black
    RedBg              ## red
    GreenBg            ## green
    YellowBg           ## yellow
    BlueBg             ## blue
    MagentaBg          ## magenta
    CyanBg             ## cyan
    WhiteBg            ## white
    NoneBg = 39 + 10   ## default
    BrBlackBg = 90 + 10## bright black
    BrRedBg            ## bright red
    BrGreenBg          ## bright green
    BrYellowBg         ## bright yellow
    BrBlueBg           ## bright blue
    BrMagentaBg        ## bright magenta
    BrCyanBg           ## bright cyan
    BrWhiteBg          ## bright white

  TermCell* = object   ## Represents a character in the terminal buffer, including color and style information.
    ch*: Rune # string is slower
    fg*: TermColor
    bg*: TermColorBg
    style*: set[Style]

  TermCells* = seq[TermCell]

  TermBuffer* = object
    width*, height*: uint16
    buf*: TermCells

var ttyf: File #Maybe each termbuffer should have its own file?

proc c_fflush(f: File): cint {.importc: "fflush", header: "<stdio.h>".}
proc c_fwrite(buf: pointer, size, n: csize_t, f: File): cint {.importc: "fwrite", header: "<stdio.h>".}
proc writeDelayed(s: string) =
  discard c_fwrite(s.cstring, cast[csize_t](s.len), 1, ttyf)

proc writeInstantly(s: string) =
  discard c_fwrite(s.cstring, cast[csize_t](s.len), 1, ttyf)
  discard c_fflush(ttyf)

#8bit RGB:
#fg = "\e[38;5;"#cm
#bg = "\e[48;5;"#cm
#Full RGB:
#fg = "\e[38;2;"#r;g;bm
#bg = "\e[48;2;"#r;g;bm

proc showCursor*(f: File = ttyf) = writeInstantly "\e[?25h"
proc hideCursor*(f: File = ttyf) = writeInstantly "\e[?25l"

proc resetAttributesInst() = writeInstantly "\e[m"

import os, parseutils
var L_ctermid {.importc, header: "<stdio.h>".}: cint

proc terminalWidth*(): int =
  proc terminalWidthIoctl(fds: openArray[int]): int {.nimcall.} =
    var win: IOctl_WinSize
    for fd in fds:
      if ioctl(cint(fd), TIOCGWINSZ, addr win) != -1:
        return int(win.ws_col)
  result = terminalWidthIoctl([0, 1, 2]) #Try standard file descriptors
  if result <= 0:
    var cterm = newString(L_ctermid) #Try controlling tty
    var fd = open(ctermid(cstring(cterm)), O_RDONLY)
    if fd != -1:
      result = terminalWidthIoctl([int(fd)])
    discard close(fd)
    if result <= 0: #Try standard env var
      if not(parseInt(getEnv("COLUMNS"), result) > 0 and result > 0):
        result = 80 #Default

proc terminalHeight*(): int =
  proc terminalHeightIoctl(fds: openArray[int]): int {.nimcall.} =
    var win: IOctl_WinSize
    for fd in fds:
      if ioctl(cint(fd), TIOCGWINSZ, addr win) != -1:
        return int(win.ws_row)
  result = terminalHeightIoctl([0, 1, 2]) # Try standard file descriptors
  if result <= 0:
    var cterm = newString(L_ctermid) # Try controlling tty
    var fd = open(ctermid(cstring(cterm)), O_RDONLY)
    if fd != -1:
      result = terminalHeightIoctl([int(fd)])
    discard close(fd)
    if result <= 0: #Try standard env var
      if not(parseInt(getEnv("LINES"), result) > 0 and result > 0):
        result = 24 #Default

var
  fullRedraw = false
  prevBuf: TermBuffer
  currBg: TermColorBg #Do we
  currFg: TermColor #really
  currStyle: set[Style] #need those?
  origTtyState: Termios

proc initConsole() =
  discard tcGetAttr(STDIN_FILENO, origTtyState.addr)
  var ttyState = origTtyState
  ttyState.c_iflag = ttyState.c_iflag and not ICRNL #To differentiate between Enter and CtrlI
  ttyState.c_lflag = ttyState.c_lflag and not (ICANON or ECHO) #turn off canonical mode & echo
  ttyState.c_cc[VMIN] = 0.cuchar #minimum of number input read
  discard tcSetAttr(STDIN_FILENO, TCSANOW, ttyState.addr)
  writeInstantly "\e[?1049h"

proc deinitConsole() =
  discard tcSetAttr(STDIN_FILENO, TCSANOW, origTtyState.addr)
  writeInstantly "\e[?1049l"

proc installSignalHandlers() =
  proc SIGTSTP_handler(sig: cint) {.noconv.} =
    signal(SIGTSTP, SIG_DFL)
    resetAttributesInst()
    showCursor(ttyf)
    deinitConsole()
    discard posix.raise(SIGTSTP)
  proc SIGCONT_handler(sig: cint) {.noconv.} =
    signal(SIGCONT, SIGCONT_handler)
    signal(SIGTSTP, SIGTSTP_handler)
    fullRedraw = true #Set the colors too???????
    initConsole()
    hideCursor(ttyf)
  signal(SIGTSTP, SIGTSTP_handler)
  signal(SIGCONT, SIGCONT_handler)

proc initTernim*() =
  ttyf = open("/dev/tty", fmWrite)
  ## Needs to be called before doing anything with the library.
  #eraseScreen() #Should still do that, since not all terms support alternate buffers (Or should we simply move the cursor to the bottom???
  prevBuf = TermBuffer()
  initConsole()
  hideCursor(ttyf)
  installSignalHandlers()
  resetAttributesInst()

proc deinitTernim*() =
  ## Resets the terminal to its previous state. Needs to be called before exiting the application.
  #eraseScreen()
  deinitConsole()
  resetAttributesInst()
  showCursor(ttyf)
  close(ttyf)

import private/[termcells, termface, termkeys]
export termcells, termface, termkeys

proc newTermBuffer*(height = terminalHeight().uint16, width = terminalWidth().uint16): TermBuffer =
  result = TermBuffer(height: height, width: width, buf: newSeq[TermCell](width * height))
  result.clear()

from strformat import `&`

func setAttribsAs(result: var string, c: TermCell, currBg: var TermColorBg,
  currFg: var TermColor, currStyle: var set[Style]) =
  #Combines all changes into one escape sequence
  #If there is no change this would generate \e[m which is problematic since that will reset everything
  #Luckily this is only called when there IS change
  result.add "\e["
  if c.bg != currBg:
    currBg = c.bg
    result.add $currBg.uint16
    result.add ';'
  if c.fg != currFg:
    currFg = c.fg
    result.add $currFg.uint16
    result.add ';'
  if c.style > currStyle:
    currStyle = c.style
    for s in currStyle:
      result.add $s.uint16
      result.add ';'
  elif c.style != currStyle: #XXX: Can turn off atribs with style + 20 i think (not widely supported?)
    currStyle = c.style
    result.add "0;" #resetAttributes
    result.add $currBg.uint16
    result.add ';'
    result.add $currFg.uint16
    result.add ';'
    for s in currStyle:
      result.add $s.uint16
      result.add ';'
  result[^1] = 'm'

func toString*(result: var string, cells: openArray[TermCell]) =
  var
    currBg = NoneBg
    currFg = None
    currStyle: set[Style]

  for cell in cells:
    if cell.bg != currBg or cell.fg != currFg or cell.style != currStyle:
      result.setAttribsAs(cell, currBg, currFg, currStyle)
    result.add cell.ch

func toString*(cells: openArray[TermCell]): string =
  result.toString cells

proc displayFull(tb: TermBuffer) =
  var cellBuf = ""
  for y in 0'u16..<tb.height:
    writeInstantly &"\e[{y+1};1f" #Seems to be faster that way than a writeDelayed
    for x in 0'u16..<tb.width:
      let c = tb.buf[tb.width * y + x]
      if c.bg != currBg or c.fg != currFg or c.style != currStyle:
        cellBuf.setAttribsAs(c, currBg, currFg, currStyle)
        writeDelayed cellBuf
        cellBuf.setLen 0
      writeDelayed $c.ch

proc displayDiff(tb: TermBuffer) =
  var buf = ""
  var setPosNexTim = false
  for y in 0'u16..<tb.height:
    writeDelayed &"\e[{y+1};1H"
    setPosNexTim = false
    for x in 0'u16..<tb.width:
      let c = tb.buf[tb.width * y + x]
      if c != prevBuf.buf[prevBuf.width * y + x]:
        if setPosNexTim:
          buf.add &"\e[{x+1}G"
          setPosNexTim = false
        if c.bg != currBg or c.fg != currFg or c.style != currStyle:
          buf.setAttribsAs(c, currBg, currFg, currStyle)
        buf.add $c.ch
      else:
        setPosNexTim = true
    if buf.len > 0:
      writeDelayed buf
      buf.setLen(0)

proc display*(tb: TermBuffer) =
  if unlikely(fullRedraw):
    fullRedraw = false
    resetAttributesInst()
    currBg = NoneBg
    currFg = None
    currStyle = {}
    displayFull tb
  elif unlikely(tb.width != prevBuf.width or tb.height != prevBuf.height):
    displayFull tb
    prevBuf.width = tb.width
    prevBuf.height = tb.height
    prevBuf.buf = tb.buf
  else:
    displayDiff tb
    prevBuf.buf = tb.buf #Only need to update the buf since dimensions didn't change, yay!
  discard c_fflush ttyf
