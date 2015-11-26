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

from strutils import find, rfind, toLower, `%`, splitLines, join
import tables
import typeinfo, typetraits

####################
# Basic operators. #
####################

proc `or`*(a, b: string): string =
  # `or` operator for strings.
  # Returns a if a is neither nil nor empty.
  # Otherwise, it returns either b, or an empty string if b is nil.
  var a = if a == nil: "" else: a
  var b = if b == nil: "" else: b
  
  return if a != "": a else: b

proc `not`*(str: string): bool =
  # Not operator for strings.
  # Returns true if the string is either nil or empty.

  return str == nil or str == ""


#####################
# String splitting. #
#####################

proc lsplit*(str, sep: string): tuple[left, right: string] =
  # Splits a string in two at the first occurrence of the separator.

  # Prevent null strings.
  var str = str or ""
  var sep = sep or ""

  var pos = find(str, sep)
  if pos == -1: return ("", str)
  return (str[0..pos-1], str[pos+1..high(str)])

proc rsplit*(str, sep: string): tuple[left, right: string] =
  # Splits a string in two at the last occurence of the separator.

  # Prevent null strings.
  var str = str or ""
  var sep = sep or ""

  var pos = rfind(str, sep)
  if pos == -1: return(str, "")
  return (str[0..pos-1], str[pos+1..high(str)])

################
# Conversions. #
################

proc prefixLines*(str, prefix: string): string =
  result = ""
  for line in str.splitLines():
    result &= prefix & line & "\n"

############################
# String case conversions. #
############################

proc lowerCaseStart*(str: string): string =
  # Converts the beginning of a string to lower case, until the 
  # first non-uppercase character is found.
  
  result = ""
  for i, c in str:
    if c in {'A'..'Z'}:
      result = result & toLower(c)
    else:
      result = result & str[i..high(str)]
      break

proc toSnakeCase*(str: string): string =
  # Converts a string to snake case.

  if not str: return ""
  result = ""

  const upperCase = {'A'..'Z'}
  const lowerCase = {'a'..'z', '0'..'9'}

  var shouldConvert = false
  let max = high(str)
  for index, c in str:
    case c
    of upperCase:
      if shouldConvert:
        result = result & '_'
        shouldConvert = false
      result = result & toLower(c)

    of lowerCase:
      shouldConvert = true
      result = result & c

    of '_', '-':
      # Prevent double _. 
      if result.len() < 1:
        continue

      if index < max and str[index+1] in {'_', '-'}:
        continue
      elif index == max:
        continue
      else:
        result = result & '_'
        shouldConvert = false

    else:
      discard

proc toKebapCase*(str: string): string =
    # Converts a string to kebap case.

  if not str: return ""
  result = ""

  const upperCase = {'A'..'Z'}
  const lowerCase = {'a'..'z', '0'..'9'}

  var shouldConvert = false
  let max = high(str)
  for index, c in str:
    case c
    of upperCase:
      if shouldConvert:
        result = result & '-'
        shouldConvert = false
      result = result & toLower(c)

    of lowerCase:
      shouldConvert = true
      result = result & c

    of '_', '-':
      # Prevent double _. 
      if result.len() < 1:
        continue

      if index < max and str[index+1] in {'_', '-'}:
        continue
      elif index == max:
        continue
      else:
        result = result & '-'
        shouldConvert = false

    else:
      discard

proc pluralize*(str: string): string =
  if not str: return ""

  result = str
  if str[high(str)] == 'y':
    result = str[0..high(str) - 1] & "ie"
  if str[high(str)] != 's':
    result &= "s"

#############################
# Better $ / repr / format. #
#############################

proc format(s: string, args varargs[string, `$`]): string =
  # A save version of format, which does not error out on nil strings.
  var args = args
  for index, arg in args:
    if arg is string and arg == nil:
      args[index] = "nil!"

  return strutils.format(s, args)

proc repr*(s: string): string =
  if s == nil:
    result = "nil!"
  else:
    result = "\"" & s & "\""

proc repr*(s: openArray[string]): string =
  result = "["
  var parts: seq[string] = @[]
  for s in s:
    parts.add("\"$1\"" % [s])
  result &= parts.join(", ")
  result &= "]"

proc repr*[A, B](t: Table[A, B]): string =
  # Better repr for tables.

  result = "Table[$1: $2] ($3)" % [name(A), name(B), t.len().`$`]
  if t.len() < 1:
    return

  result &= " => \n"
  for key, val in t.pairs:
    var valRepr = repr(val)
    if valRepr.splitLines().len() > 1:
      result &= "  " & $key & ":\n" & valRepr.prefixLines("    ") 
    else:
      result &= "  $1: $2\n" % [$key, valRepr]

proc reprObject*[T](val: T): string =
  var a = toAny()
  if a.kind != akObject:
    return repr(val)

  result = "[" & name(T) & "] => \n"
  for name, fieldVal in a.fields:
    discard

discard """
proc repr*[T](val: T): string =
  # Generic repr for objects.
  when val is object:
    result = reprObject(val)
  else:
    result = system.repr(val)
"""