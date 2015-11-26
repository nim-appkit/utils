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
# ParseErr. #
#############

type ParseErr = object of Exception
  discard

proc newParseErr(msg: string): ref ParseErr =
  newException(ParseErr, msg)

##############
# StrParser. #
##############

type StrParser = ref object
  stringVal: string
  lastPos: int
  currentPos: int
  lastIndex: int
  
  token: string
  tokens: StringTableRef

proc newStrParser*(s: string): StrParser =
  StrParser(
    stringVal: s,
    lastIndex: high(s),
    tokens: newStringTable(modeCaseSensitive)
  )

proc pos*(p: StrParser): int =
  p.currentPos

proc high*(p: StrParser): int =
  p.lastIndex

proc endReached*(p: StrParser): bool =
  p.pos > p.high

proc cur*(p: StrParser): char =
  if p.endReached():
    raise newParseErr("Reached end of string")
  p.stringVal[p.pos]

proc getNext*(p: StrParser, n: int): string =
  if p.endReached():
    return ""
  return p.stringVal[p.currentPos..min(p.high(), p.currentPos + n)]

proc getRemaining*(p: StrParser): string = 
  if p.endReached:
    result = ""
  else:
    result = p.stringVal[p.pos()..p.high()]

proc inc*(p: StrParser) =
  if p.endReached():
    raise newParseErr("Reached end of string")
  p.currentPos += 1

proc shift*(p: StrParser): char =
  if p.endReached():
    raise newParseErr("Reached end of string")
  result = p.cur()
  p.inc()

###################
# Skipping procs. #
###################

proc skip*(p: StrParser, chars: set[char], min, max: int = 0): StrParser =
  # Save current pos.
  p.lastPos = p.currentPos
  var count = 0
  while not p.endReached() and p.cur() in chars and (max == 0 or count < max):
    discard p.shift()
    count += 1
  if count < min:
    raise newParseErr("Skipped $1 chars, but $2 were required" % [$count, $min])

  return p

proc skip*(p: StrParser, s: string, mustSkip: bool = true): StrParser =
  if p.stringVal[p.currentPos..p.high()].startsWith(s):
    p.currentPos += s.len()
  else:
    if mustSkip:
      raise newParseErr("Could not skip string '$1' since it was not found." % [s])
  return p


proc skipWhitespace*(p: StrParser, min, max: int = 0): StrParser =
  p.skip(WhiteSpace, min, max)

proc skipUntil*(p: StrParser, chars: set[char], min: int = 0, max: int = 1): StrParser =
  p.lastPos = p.currentPos
  var count = 0
  while not p.endReached():
    if not (p.cur() in chars):
      discard p.shift()
    else:
      # Found a match!
      count += 1
      if count >= max:
        break
      discard p.shift() 

  if count < min:
    raise newParseErr("Skipped until $1 $2 times, but $3 times were required." % [$chars, $count, $min])

  return p

proc skipUntilAfter*(p: StrParser, chars: set[char], min: int = 0, max: int = 1): StrParser =
  discard p.skipUntil(chars, min, max)
  if not p.endReached():
    discard p.skip(chars)

  return p

proc skipToNextLine*(p: StrParser): StrParser =
  p.skipUntilAfter({'\x0A'}, min = 1, max = 1)

##################
# Parsing procs. #
##################

proc parseToken*(p: StrParser, chars: set[char], min, max: int = 0): string =
  p.lastPos = p.currentPos
  var token = ""
  while not p.endReached() and p.cur() in chars and (max == 0 or token.len() < max):
    token &= p.shift().`$`

  if token.len() < min:
    raise newParseErr("Expected token with len of at least $1, but only got $2 chars" % [$min, token.len().`$`])
  return token

proc parseNamedToken*(p: StrParser, name: string, chars: set[char], min: int = 0, max: int = 0): StrParser =
  p.tokens[name] = p.parseToken(chars, min, max)
  return p

proc parseWord*(p: StrParser, min, max: int = 0): string =
  p.parseToken(Letters, min, max)

proc parseNamedWord*(p: StrParser, name: string, min: int = 0, max: int = 0): StrParser =
  p.tokens[name] = p.parseWord(min, max)
  return p

proc parseIdentifier*(p: StrParser, min, max: int = 0): string =
  var token = ""

  if p.cur() notin IdentStartChars:
    if min > 0:
      raise newParseErr("Expected identifier with len of at least $1, but only got 0 chars." % [$min])
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

proc parseNamedIdentifier*(p: StrParser, name: string, min: int = 0, max: int = 0): StrParser =
  p.tokens[name] = p.parseIdentifier(min, max)
  return p

proc parseTokenUntil*(p: StrParser, chars: set[char], min, max: int = 0): string =
  p.lastPos = p.currentPos
  var token = ""
  while true:
    if p.endReached():
      raise newParseErr("End reached but token not finished")
    if p.cur() in chars:
      break
    if max > 0 and token.len() >= max:
      raise newParseErr("Expected token with maximum length of $1, but already reached that length and parsing not finished yet." % [$max])
    token &= p.shift().`$`
  if token.len() < min:
    raise newParseErr("Expected token with len of at least $1, but only got $2 chars" % [$min, token.len().`$`])
  return token

proc parseNamedTokenUntil*(p: StrParser, name: string, chars: set[char], min, max: int = 0): StrParser =
  p.tokens[name] = p.parseTokenUntil(chars, min, max)
  return p

proc parseTokenUntilAfter*(p: StrParser, chars: set[char], min, maxCount: int = 0): string =
  var token = p.parseTokenUntil(chars, 0, 0)
  if token.len() >= maxCount:
    raise newParseErr("Expected token with maximum length of $1, but already reached that length and parsing not finished yet." % [$maxCount])
  var rest = p.parseToken(chars, max(0, token.len() - min), max(0, maxCount - token.len()))
  if token.len() > maxCount:
    raise newParseErr("Expected token with max len of $1, but got len $2" % [$maxCount, token.len().`$`])
  if token.len() < min:
    raise newParseErr("Expected token with len of at least $1, but only got $2 chars" % [$min, token.len().`$`])
  return token
  
proc parseNamedTokenUntilAfter*(p: StrParser, name: string, chars: set[char], min, max: int = 0): StrParser =
  p.tokens[name] = p.parseTokenUntilAfter(chars, min, max)

###################
# Number parsing. #
###################

proc parseInteger*(p: StrParser, min, max: int = 0): string =
  p.parseToken(Digits, min, max)

proc parseNamedInteger*(p: StrParser, name: string, min, max: int = 0): StrParser =
  p.tokens[name] = p.parseInteger(min, max)
  return p

proc parseFloat*(p: StrParser, min, max: int = 0): string =
  p.parseToken(Digits + {'.'}, min, max)

proc parseNamedFloat*(p: StrParser, name: string, min, max: int = 0): StrParser =
  p.tokens[name] = p.parseFloat(min, max)
  return p


####################
# Key/value pairs. #
####################

var KeyChars = Letters + Digits + {'-', '_', '.'}
var SeparatorChars = WhiteSpace + {'=', ':'}
var ValueEndChars = WhiteSpace + NewLines

proc parseKeyValuePair*(p: StrParser, keyChars: set[char] = KeyChars, sepChars: set[char] = SeparatorChars, endChars: set[char] = ValueEndChars): tuple[key, value: string] =
  var key = p.parseToken(keyChars)
  if key.len() < 1:
    return (nil, nil)
  discard p.skipUntilAfter(sepChars, min = 1)
  var value = p.parseTokenUntil(endChars)
  if value.len() < 1:
    return (nil, nil)
  return (key, value)
