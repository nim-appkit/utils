###############################################################################
##                                                                           ##
##                           nim-utils                                       ##
##                                                                           ##
##   (c) Christoph Herzog <chris@theduke.at> 2015                            ##
##                                                                           ##
##   This project is under the MIT license.                                  ##
##   Check LICENSE.txt for details.                                          ##
##                                                                           ##
###############################################################################

import strutils, strtabs

#############
# ParseError. #
#############

type ParseError = object of Exception
  discard

proc newParseError(msg: string): ref ParseError =
  newException(ParseError, msg)

##############
# Parser. #
##############

type Parser* = ref object of RootObj
  stringVal: string
  lastPos: int
  currentPos: int
  lastIndex: int
  currentLine: int
  
  token: string
  tokens: StringTableRef

proc init*(p: Parser, str: string) =
  p.stringVal = str
  p.lastIndex = high(str)
  p.currentLine = 1
  p.tokens = newStringTable(modeCaseSensitive)

proc newParser*(s: string): Parser =
  new(result)
  result.init(s)


proc pos*(p: Parser): int =
  p.currentPos

proc lastPos*(p: Parser): int =
  p.lastIndex

proc len*(p: Parser): int =
  p.stringVal.len()

proc line*(p: Parser): int =
  p.currentLine

proc endReached*(p: Parser): bool =
  p.pos > p.lastIndex

proc prev*(p: Parser): char =
  if p.pos() == 0:
    result = '\0'
  else:
    result = p.stringVal[p.pos() - 1]

proc cur*(p: Parser): char =
  if p.endReached():
    raise newParseError("Reached end of string")
  p.stringVal[p.pos]

proc charsRemaining*(p: Parser): int =
  if p.endReached(): 0 else: p.lastIndex - p.currentPos + 1

proc getRemaining*(p: Parser): string = 
  if p.endReached:
    result = ""
  else:
    result = p.stringVal[p.pos()..p.lastIndex]

proc next*(p: Parser): char =
  if p.charsRemaining() >= 2: p.stringVal[p.currentPos + 1] else: '\0'

proc next*(p: Parser, n: int): string =
  if p.endReached():
    return ""
  return p.stringVal[p.currentPos..min(p.lastIndex, p.currentPos + n - 1)]

proc continuesWith*(p: Parser, s: string): bool =
  if p.currentPos + s.len() - 1 > p.lastIndex:
    return false
  return p.stringVal[p.currentPos..p.currentPos + s.len() - 1] == s

proc continuesWithNewline*(p: Parser): bool =
  result = false
  if p.endReached():
    return

  if p.cur() == '\x0A':
    result = true
  elif p.cur() == '\x0D':
    if p.charsRemaining() > 1 and p.next == '\x0A':
      result = true

proc shift*(p: Parser): char =
  if p.endReached():
    raise newParseError("Reached end of string")
  result = p.cur()
  if result == '\x0A':
    p.currentLine.inc()
  p.currentPos += 1

###################
# Skipping procs. #
###################

proc skip*(p: Parser, chars: set[char], min, max: int = 0): int =
  var count = 0
  while not p.endReached() and p.cur() in chars and (max == 0 or count < max):
    discard p.shift()
    count.inc()
  if count < min:
    raise newParseError("Skipped $1 chars, but $2 were required".format(count, min))
  return count

proc skip*(p: Parser, c: char, min, max: int = 0): int =
  p.skip({c}, min, max)

proc skip*(p: Parser, s: string, mustSkip: bool = true): int =
  # Skip a string.
  # If the text does not continue with the string, 0 is returned, 
  # and the length of the string otherwise.

  result = 0 # Just to be verbose.
  if p.continuesWith(s):
    for i in 1..s.len():
      discard p.shift()
    result = s.len()
  elif mustSkip:
    raise newParseError("Could not skip string '$1' since it was not found.".format(s))

proc skipWhitespace*(p: Parser, min, max: int = 0): int =
  p.skip({' ', '\t'}, min, max)

proc skipNewline*(p: Parser): int =
  discard p.skip('\r')
  result = p.skip('\x0A', max=1)

proc skipNewlines*(p: Parser, min, max: int = 0): int =
  # Skip all consecutive (\r)\n characters.
  # Returns the number of lines skipped.
  
  while not p.endReached() and (max == 0 or result < max) and p.skipNewline() > 0:
    result.inc()

proc skipUntil*(p: Parser, chars: set[char], min: int = 0): int =
  var count = 0
  while not p.endReached() and p.cur() notin chars:
    discard p.shift()
    count.inc()

  if count < min:
    raise newParseError("Skipped until $1 $2 times, but $3 times were required.".format(chars, count, min))
  return count

proc skipUntil*(p: Parser, c: char, min: int): int =
  p.skipUntil({c}, min)

proc skipUntilAfter*(p: Parser, chars: set[char]): int =
  p.skipUntil(chars) + p.skip(chars)

proc skipUntilAfter*(p: Parser, c: char): int =
  p.skipUntilAfter({c})

proc skipUntilAfter*(p: Parser, str: string): int =
  result = 0
  while not p.endReached() and not p.continuesWith(str):
    result.inc()
    discard p.shift()
  if not p.endReached():
    result += p.skip(str)

proc skipToNextLine*(p: Parser): int =
  p.skipUntilAfter('\x0A')

proc skipBlankLine*(p: Parser): int =
  # Skip a blank line (lines that contains only whitespaces).
  # If the line is not blank, the number of whitespaces skipped is returned.
  # If the line is blank, -1 is returned.
  
  result = p.skipWhitespace()
  echo("continues with: ", p.getRemaining())
  if p.continuesWithNewline():
    discard p.skipToNextLine()
    result = -1

proc skipBlankLines*(p: Parser): int =
  # Skips all following blank lines, until a non-blank line is found or end of file is reached.
  # Returns -1 if end of file was reached, or, if a non blank line is found, the number of whitespaces skipped
  # in the current line.

  while not p.endReached():
    result = p.skipBlankLine()
    if result != -1:
      break



##################
# Parsing procs. #
##################

proc parseToken*(p: Parser, chars: set[char], min, max: int = 0): string =
  p.lastPos = p.currentPos
  var token = ""
  while not p.endReached() and p.cur() in chars and (max == 0 or token.len() < max):
    token &= p.shift().`$`

  if min > 0 and token.len() < min:
    raise newParseError("Expected token with len of at least $1, but only got $2 chars" % [$min, token.len().`$`])
  return token

proc parseNamedToken*(p: Parser, name: string, chars: set[char], min: int = 0, max: int = 0): Parser =
  p.tokens[name] = p.parseToken(chars, min, max)
  return p

proc parseWord*(p: Parser, min, max: int = 0): string =
  p.parseToken(Letters, min, max)

proc parseNamedWord*(p: Parser, name: string, min: int = 0, max: int = 0): Parser =
  p.tokens[name] = p.parseWord(min, max)
  return p

proc parseIdentifier*(p: Parser, min, max: int = 0): string =
  var token = ""

  if p.cur() notin IdentStartChars:
    if min > 0:
      raise newParseError("Expected identifier with len of at least $1, but only got 0 chars." % [$min])
  else:
    token &= p.shift().`$`

    if max == 0 or max > 1:
      var min = min
      var max = max
      if min > 0:
        min -= 1
      if max > 0:
        max -= 1
      token &= p.parseToken(IdentChars, min, max)
  return token

proc parseNamedIdentifier*(p: Parser, name: string, min: int = 0, max: int = 0): Parser =
  p.tokens[name] = p.parseIdentifier(min, max)
  return p

proc parseTokenUntil*(
  p: Parser, 
  chars: set[char], 
  min, max: int = 0, 
  ignoreEscaped: bool = true, 
  allowEOF: bool = true, 
  allowNewline: bool = false
): string =
  var token = ""

  while true:
    if p.endReached():
      if allowEOF:
        break
      else:
        raise newParseError("End reached but token not finished")

    if p.cur() in chars:
      if not ignoreEscaped or (p.pos() == 0 or p.prev() != '\\'):
        break

    # Check if a newline occurs. 
    if p.cur() in {'\r', '\x0A'} and not allowNewline:
      # Newline occured before end char, and allowNewline is false, so char 
      # must be found before a newline. Raise an error!
      raise newParseError("Missing $1 character before newline at line $2".format(chars, p.currentLine))

    if max > 0 and token.len() >= max:
      raise newParseError("Expected token with maximum length of $1, but already reached that length and parsing not finished yet." % [$max])
    token &= p.shift().`$`
  if min > 0 and token.len() < min:
    raise newParseError("Expected token with len of at least $1, but only got $2 chars" % [$min, token.len().`$`])
  return token

proc parseTokenUntil*(p: Parser, c: char, min, max: int = 0): string =
  p.parseTokenUntil({c}, min, max)

proc parseNamedTokenUntil*(p: Parser, name: string, chars: set[char], min, max: int = 0): Parser =
  p.tokens[name] = p.parseTokenUntil(chars, min, max)
  return p

proc parseTokenUntilAfter*(p: Parser, chars: set[char], min, maxCount: int = 0): string =
  var token = p.parseTokenUntil(chars, 0, 0)
  if maxCount > 0 and token.len() >= maxCount:
    raise newParseError("Expected token with maximum length of $1, but already reached that length and parsing not finished yet." % [$maxCount])
  var newMin = if min == 0: 0 else: max(0, min - token.len())
  var newMax = if maxCount == 0: 0 else: maxCount - token.len()
  var rest = p.parseToken(chars, newMin, newMax)
  if maxCount > 0 and token.len() > maxCount:
    raise newParseError("Expected token with max len of $1, but got len $2" % [$maxCount, token.len().`$`])
  if min > 0 and token.len() < min:
    raise newParseError("Expected token with len of at least $1, but only got $2 chars" % [$min, token.len().`$`])
  return token & rest

proc parseTokenUntilAfter*(p: Parser, c: char, min, max: int = 0): string =
  p.parseTokenUntilAfter({c}, min, max)

proc parseNamedTokenUntilAfter*(p: Parser, name: string, chars: set[char], min, max: int = 0): Parser =
  p.tokens[name] = p.parseTokenUntilAfter(chars, min, max)

###################
# Number parsing. #
###################

proc parseInteger*(p: Parser, min, max: int = 0): string =
  p.parseToken(Digits, min, max)

proc parseNamedInteger*(p: Parser, name: string, min, max: int = 0): Parser =
  p.tokens[name] = p.parseInteger(min, max)
  return p

proc parseFloat*(p: Parser, min, max: int = 0): string =
  p.parseToken(Digits + {'.'}, min, max)

proc parseNamedFloat*(p: Parser, name: string, min, max: int = 0): Parser =
  p.tokens[name] = p.parseFloat(min, max)
  return p


####################
# Key/value pairs. #
####################

var KeyChars = Letters + Digits + {'-', '_', '.'}
var SeparatorChars = WhiteSpace + {'=', ':'}
var ValueEndChars = WhiteSpace + NewLines

proc parseKeyValuePair*(p: Parser, keyChars: set[char] = KeyChars, sepChars: set[char] = SeparatorChars, endChars: set[char] = ValueEndChars): tuple[key, value: string] =
  var key = p.parseToken(keyChars)
  if key.len() < 1:
    return (nil, nil)
  discard p.skipUntilAfter(sepChars)
  var value = p.parseTokenUntil(endChars)
  if value.len() < 1:
    return (nil, nil)
  return (key, value)
