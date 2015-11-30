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

import alpha, omega

import parser

Suite "Parser":
  
  Describe "Base procs":

    It "Should initialize and run base procs properly":
      var parser = newParser("abcdef")
      parser.pos().should equal 0
      parser.lastPos().should equal 5
      parser.len().should equal 6
      parser.line().should equal 1
      parser.endReached().should beFalse()
      parser.cur().should equal 'a'
      parser.prev().should equal '\0'
      parser.charsRemaining().should equal 6
      parser.getRemaining().should equal "abcdef"
      parser.next().should equal 'b'
      parser.next(3).should equal "abc"
      parser.continuesWith("abc").should beTrue()
      parser.continuesWith("abd").should beFalse()
      parser.continuesWithNewline().should beFalse()

    It "Should report continuesWith() and end of string":
      var parser = newParser("alpha")
      parser.continuesWith("alpha").should beTrue()

    It "Should shift":
      var parser = newParser("abcdef")
      parser.shift().should equal 'a'
      parser.pos().should equal 1
      parser.endReached().should beFalse()
      parser.cur().should equal 'b'
      parser.prev().should equal 'a'
      parser.charsRemaining().should equal 5
      parser.getRemaining().should equal "bcdef"
      parser.next().should equal 'c'
      parser.next(3).should equal "bcd"
      parser.continuesWith("abc").should beFalse()
      parser.continuesWith("bcd").should beTrue()
      parser.continuesWithNewline().should beFalse()

    It "Should shift over end of string":
      var parser = newParser("ab")
      discard parser.shift()
      discard parser.shift()
      parser.endReached().should beTrue()
      parser.next.should equal '\0'
      parser.next(2).should equal ""
      parser.continuesWith("xxx").should beFalse()
      parser.continuesWithNewline().should beFalse()

    It "Should detect newlines when shifting":
      var parser = newParser("\na\r\nc\rn")
      parser.line().should equal 1
      discard parser.shift() # \n
      parser.line().should equal 2
      discard parser.shift() # a
      discard parser.shift() # \r
      parser.line().should equal 2
      discard parser.shift() # \n
      parser.line().should equal 3
      discard parser.shift() # c
      discard parser.shift()
      parser.line().should equal 3

    It "Should detect \n with continuesWithNewline":
      var parser = newParser("a\n")
      parser.continuesWithNewline().should beFalse()
      discard parser.shift()
      parser.continuesWithNewline().should beTrue()

    It "Should detect \r\n with continuesWithNewline":
      var parser = newParser("a\r\n")
      parser.continuesWithNewline().should beFalse()
      discard parser.shift()
      parser.continuesWithNewline().should beTrue()

    It "Should not detect newline  \r with continuesWithNewline":
      var parser = newParser("\rx")
      parser.continuesWithNewline().should beFalse()

  Describe "Skipping":

    It "Should skip single char":
      var parser = newParser("abc")
      parser.skip('a').should equal 1
      parser.pos().should equal 1
      parser.skip('c').should equal 0

    It "Should skip single char multiple times":
      var parser = newParser("aabc")
      parser.skip('a').should equal 2

    It "Should skip char set":
      var parser = newParser("aabc")
      parser.skip({'a', 'b'}).should equal 3

    It "Should skip char set while respecting max":
      var parser = newParser("aabbc")
      parser.skip({'a', 'b'}, max = 3).should equal 3
      parser.cur().should equal 'b'

    It "Should not skip when next char not in set":
      var parser = newParser("aabbc")
      parser.skip({'x'}).should equal 0
      parser.pos().should equal 0

    It "Should not skip whitespaces when next char not whitespace":
      var parser = newParser("aabbc")
      parser.skipWhitespace().should equal 0
      parser.pos().should equal 0

    It "Should skip whitespaces":
      var parser = newParser("  \t  aabbc")
      parser.skipWhitespace().should equal 5
      parser.cur().should equal 'a'

    It "Should skip whitespaces while respecting max":
      var parser = newParser("  \t aabbc")
      parser.skipWhitespace(max=3).should equal 3
      parser.cur().should equal ' '
      parser.next().should equal 'a'

    It "Should skip single \\n newline":
      var parser = newParser("\nx")
      parser.skipNewline().should equal 1
      parser.cur().should equal 'x'

    It "Should skip single \\r\\n newline":
      var parser = newParser("\r\nx")
      parser.skipNewline().should equal 1
      parser.cur().should equal 'x'

    It "Should skip newlines":
      var parser = newParser("\n\r\n\r\r\na")
      parser.skipNewlines().should equal 3
      parser.cur().should equal 'a'

    It "Should skip newlines while respecting max":
      var parser = newParser("\n\r\n\r\r\na")
      parser.skipNewlines(max=2).should equal 2
      parser.cur().should equal '\r'

    
    It "Should skipUntil":
      var parser = newParser("a b cd ef")
      parser.skipUntil({'c', 'd'}).should equal 4
      parser.pos().should equal 4
      parser.cur().should equal 'c'

    It "Should skipUntilAfter with chars":
      var parser = newParser("a b cd ef")
      parser.skipUntilAfter({'c'}).should equal 5
      parser.cur().should equal 'd'

    It "Should skipUntilAfter with string":
      var parser = newParser("this is a long sentence")
      parser.skipUntilAfter("long ").should equal 15
      parser.continuesWith("sentence").should beTrue()

    It "Should skipToNextLine":
      var parser = newParser("a line\r\nnew line")
      parser.skipToNextLine().should equal 8
      parser.continuesWith("new line").should beTrue()

    It "Should single blank line":
      var parser = newParser("    \r\nnew line")
      parser.skipBlankLine().should equal(-1)
      parser.continuesWith("new line").should beTrue()

    It "Should multiple blank lines and report proper position":
      var parser = newParser("  \t\r\n  \t \n new line")
      parser.skipBlankLines().should equal 1
      parser.continuesWith("new line").should beTrue()

  Describe "Parsing":

    It "Should parseTokenUntil":
      var parser = newParser("\"alibaba\" sdf")
      discard parser.shift()
      parser.parseTokenUntil('"').should equal "alibaba"

    It "Should parseTokenUntil with token containing escaped end character":
      var parser = newParser("\"ali\\\"baba\" sdf")
      discard parser.shift()
      parser.parseTokenUntil('"').should equal "ali\\\"baba"

    It "Should parseTokenUntilAfter":
      var parser = newParser("\"alibaba\" sdf")
      discard parser.shift()
      parser.parseTokenUntilAfter('"').should equal "alibaba\""

    It "Should parseTokenUntilAfter with token containing escaped end character":
      var parser = newParser("\"ali\\\"baba\" sdf")
      discard parser.shift()
      parser.parseTokenUntil('"').should equal "ali\\\"baba\""


    It "Should parse integer":
      var parser = newParser("12345.  ")
      parser.parseInteger().should equal "12345"
