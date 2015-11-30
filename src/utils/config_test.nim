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

from algorithm import sorted
from os import nil

import alpha, omega
import values

import config

Suite "Config":
  
  Describe "Accessors":

    It "Should get/set values with get/setValue()":
      var c = newConfig()

      c.setValue("str", "str")
      c.getValue("str").getString().should equal "str"
      c.setValue("i", 10)
      c.getValue("i").getInt().should equal 10

    It "Should get/set NESTED values with get/SetValue()":
      var c = newConfig()

      c.setValue("a.b.c.d", "str")
      c.setValue("a.b.c.e", 50)
      c.getValue("a.b.c.d").getString().should equal "str"
      c.getValue("a.b.c.e").getInt().should equal 50

    It "Should report hasKey() for nested keys":
      var c = newConfig()
      c.setValue("a.b.c.d.e", "str")
      c.hasKey("a").should beTrue()
      c.hasKey("a.b.c.e").should beFalse()
      c.hasKey("a.b.c.d").should beTrue()

    It "Should set/get nested values with [](=)":
      var c = newConfig()
      c["x"] = "x"
      c["a.b.c.d"] = 22
      assert c["x"] == "x"
      assert c["a"]["b"]["c"]["d"] == 22

    It "Should set/get nested values with .(=)":
      var c = newConfig() 
      c.x = "x"
      c["a.b.c.d"] = 22

      assert c.x == "x"
      assert c.a.b.c.d == 22
      c.getValue("a.b.c.d").should equal 22

  Describe "Typed accessors":

    It "Should get string":
      var c = newConfig()
      c["a.b"] = "x"
      c.getString("a.b").should equal "x"

    It "Should get a string with a default val":
      var c = newConfig()
      c.getString("a", "default").should equal "default" 

    It "Should get an int":
      var c = newConfig()
      c["a.b"] = 22
      c.getInt("a.b").should equal 22

    It "Should get an int with a default val":
      var c = newConfig()
      c.getInt("a", 33).should equal 33

    It "Should get a float":
      var c = newConfig()
      c["a.b"] = 22.22
      c.getFloat("a.b").should equal 22.22

    It "Should get a float with a default val":
      var c = newConfig()
      c.getFloat("a", 33.33).should equal 33.33


  Describe "JSON":

    It "Should build a config from json":
      var c = configFromJson("""{"s": "s", "i": 1, "f": 1.1, "nested": {"arr": [1, 2, 3]}}""" )
      sorted(c.getKeys(), cmp[string]).should equal(@["f", "i", "nested", "s"])

    It "Should build a config from a json file.":
      var tmpFile = os.joinPath(os.getTempDir(), "nim_utils_config_json_test.json")
      writeFile(tmpFile, """{"s": "s", "i": 1, "f": 1.1, "nested": {"arr": [1, 2, 3]}}""" )

      var c = configFromJsonFile(tmpFile)
      sorted(c.getKeys(), cmp[string]).should equal(@["f", "i", "nested", "s"])

    It "Should dump a config to json.":
      var tmpFile = os.joinPath(os.getTempDir(), "nim_utils_config_json_test.json")
      var c = newConfig()
      c.s = "s"
      c.i = 1
      c.f = 1.1
      c.nested = @%(arr: @[1, 2, 3])

      c.writeJsonFile(tmpFile)
      var fileC = configFromJsonFile(tmpFile)

      sorted(c.getKeys(), cmp[string]).should equal(sorted(fileC.getKeys(), cmp[string]))
