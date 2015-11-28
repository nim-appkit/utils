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

include strings

import alpha, omega

Suite "Strings":

  Describe "Operators":

    Describe "`or`":
      It "Should return second if first is nil":
        var s: string
        (s or "x").should(equal("x"))

      It "Should return second if first is empty":
        ("" or "x").should(equal("x"))

      It "Should return first if non-emtpy":
        ("a" or "b").should(equal("a"))

    Describe "`not`":
      It "Should return true for nil string":
        var s: string
        (not s).should(beTrue())

      It "Should return true for empty string":
        (not "").should(beTrue())

      It "Should return false for non-empty string":
        (not "x").should(beFalse())
  
  Describe "lsplit":

    It "Should lsplit without seperator present":
      lsplit("hallo", ".").should(equal(("", "hallo")))

    It "Should lsplit with seperator present":
      lsplit("ha.lo", ".").should(equal(("ha", "lo")))

    It "Should lsplit with seperator in first place":
      lsplit(".xx", ".").should(equal(("", "xx")))

    It "Should lsplit with seperator in last place":
      lsplit("xx.", ".").should(equal(("xx", "")))

  Describe "rsplit":

    It "Should rsplit without seperator present":
      rsplit("hallo", ".").should(equal(("hallo", "")))

    It "Should rsplit with seperator present":
      rsplit("ha.lo", ".").should(equal(("ha", "lo")))

    It "Should rsplit with seperator in first place":
      rsplit(".xx", ".").should(equal(("", "xx")))

    It "Should rsplit with seperator in last place":
      rsplit("xx.", ".").should(equal(("xx", "")))

  Describe "Case convertions":

    Describe "lowerCaseStart":
      It "Should return lc string unchanged":
        "fooBar".lowerCaseStart().should(equal("fooBar")) 

      It "Should convert single UC char":
        "C".lowerCaseStart().should(equal("c"))

      It "Should convert multiple UC chars":
        "CCC".lowerCaseStart().should(equal("ccc"))

      It "Should convert mixed str":
        "FOoBar".lowerCaseStart().should(equal("fooBar"))

      It "Should work with non-alphabet chars":
        "_fooBar".lowerCaseStart().should(equal("_fooBar"))

    Describe ".toSnakeCase()":
      It "Should return empty string for nil":
        var x: string
        x.toSnakeCase().should(equal(""))

      It "Should return empty string for emtpy string":
        "".toSnakeCase().should(equal(""))

      It "Should return snake case unchanged":
        "a_b_c_d".should(equal("a_b_c_d"))

      It "Should convert camel case":
        "FooBar".toSnakeCase().should(equal("foo_bar")) 
        "FooBarFooBar".toSnakeCase().should(equal("foo_bar_foo_bar")) 

      It "Should properly convert consecutive upper case":
        "FOOoBAr".toSnakeCase().should(equal("fooo_bar"))

      It "Should strip leading and trailing -/_":
        "_-_fooBar-_-".toSnakeCase().should(equal("foo_bar"))

      It "Should prevent double _":
        "__Fo___BAR__X___".toSnakeCase().should(equal("fo_bar_x"))

      It "Should handle -":
        "__FOO-BAR---boo__lala---".toSnakeCase().should(equal("foo_bar_boo_lala"))

    Describe ".toKebapCase()":
      It "Should return empty string for nil":
        var x: string
        x.toKebapCase().should(equal(""))

      It "Should return empty string for emtpy string":
        "".toKebapCase().should(equal(""))

      It "Should return kebap case unchanged":
        "a-b-c-d".should(equal("a-b-c-d"))

      It "Should convert camel case":
        "FooBar".toKebapCase().should(equal("foo-bar")) 
        "FooBarFooBar".toKebapCase().should(equal("foo-bar-foo-bar")) 

      It "Should properly convert consecutive upper case":
        "FOOoBAr".toKebapCase().should(equal("fooo-bar"))

      It "Should strip leading and trailing -/_":
        "_-_fooBar-_-".toKebapCase().should(equal("foo-bar"))

      It "Should prevent double .":
        "--Fo---BAR--X---".toKebapCase().should(equal("fo-bar-x"))

      It "Should handle _":
        "__--FOO-BAR-__--boo_-__lala__--__".toKebapCase().should(equal("foo-bar-boo-lala"))

        