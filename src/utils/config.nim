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

from strutils import contains, format
from json import nil
from sequtils import nil

import values

from strings import nil

###########
# Config. #
###########

type Config* = ref object of RootObj
  # A config object to be used for application configuration.
  # 
  # Provides many convenience accesors to access (nested) configuration data 
  # and options for loading configuration from YAML, JSON, or ini files.

  data: Map

######################
# Getters / setters. #
######################

proc getData*(c: Config): Map =
  # Retrieve the raw config data as values.ValueMap.

  c.data

proc setData*(c: Config, data: Map not nil) =
  # Set the config data from a values.ValueMap.

  c.data = data

iterator pairs*(c: Config, nested: bool = false): tuple[key: string, val: ValueRef] =
  for key, val in c.data.fieldPairs:
    yield (key, val)

iterator keys*(c: Config): string =
  for key in c.data.keys:
    yield key

proc getKeys*(c: Config): seq[string] =
  sequtils.toSeq(c.keys)

proc setValue*[T](c: Config, key: string, val: T) =
  # Set a config value.

  var key = key
  var data = c.data
  while key.contains('.'):
    let (left, right) = strings.lsplit(key, ".")

    if not data.hasKey(left):
      data[left] = newValueMap()

    key = right
    data = data[left]
  data[key] = val

proc getValue*(c: Config, key: string, defaultVal: ValueRef): ValueRef =
  # Retrieve a raw values.Value config key.
  # 
  # If the key is not found, the given default is returned.

  var data = c.data
  var key = key
  while key.contains('.'):
    var (left, right) = strings.lsplit(key, ".")
    if not data.hasKey(left):
      return defaultVal
    data = data[left]
    key = right
  result = if data.hasKey(key): data[key] else: defaultVal

proc getValue*(c: Config, key: string): ValueRef {.raises: [Exception, KeyError, ValueError].} =
  # Retrieve a raw values.Value config key.
  # 
  # If the key is not found, a KeyError is raised.
  result = c.getValue(key, nil)
  if result == nil:
    raise newException(KeyError, "Config key $1 not found".format(key))

proc `[]`*(c: Config, key: string not nil): ValueRef =
  c.getValue(key)

proc `[]=`*[T](c: Config, key: string, val: T) =
  c.setValue(key, val)

proc `.`*(c: Config, key: string not nil): ValueRef =
  c.getValue(key)

proc `.=`*[T](c: Config, key: string, val: T) =
  c.setValue(key, val)

proc hasKey*(c: Config, key: string not nil): bool =
  # Checks if the config has a certain config key.

  c.getValue(key, nil) != nil

proc getString*(c: Config, key: string not nil, default: string not nil): string =
  # Retrieve a string config value.
  # 
  # If the key is not found, the default value is returned.
  # If the config key is not of type string, a ValueError is raised.
  
  let val = c.getValue(key, nil)
  if val == nil:
    return default
  if not val.isString():
    raise newException(ValueError, "Key $1 is not a string, but '$2' - Use asString() instead".format(key, val.kind))
  result = val.getString()

proc getString*(c: Config, key: string not nil): string =
  # Retrieve a string config value.
  # 
  # If the key is not found, a KeyError is raised.
  # If the config key is not of type string, a ValueError is raised.

  let val = c.getValue(key)
  if not val.isString():
    raise newException(ValueError, "Key $1 is not a string, but '$2'".format(key, val.kind))
  result = val.getString()

proc getInt*(c: Config, key: string not nil, default: int): BiggestInt =
  # Retrieve an int config value.
  # 
  # If the key is not found, the default value is returned.
  # If the config key is not of type int, a ValueError is raised.
  
  let val = c.getValue(key, nil)
  if val == nil:
    return default
  if not val.isInt():
    raise newException(ValueError, "Key $1 is not an int, but '$2'".format(key, val.kind)) 
  result = val.getInt()

proc getInt*(c: Config, key: string not nil): BiggestInt =
  # Retrieve an int config value.
  # 
  # If the key is not found, a KeyError is raised.
  # If the config key is not of type int, a ValueError is raised.
  
  let val = c.getValue(key)
  if not val.isInt():
    raise newException(ValueError, "Key $1 is not an int, but '$2'".format(key, val.kind)) 
  result = val.getInt()

proc getFloat*(c: Config, key: string not nil, default: float): float =
  # Retrieve a float config value.
  # 
  # If the key is not found, the default value is returned.
  # If the config key is not of type float, a ValueError is raised.
  
  let val = c.getValue(key, nil)
  if val == nil:
    return default
  if not val.isFloat():
    raise newException(ValueError, "Key $1 is not a float, but '$2'".format(key, val.kind))
  result = val.getFloat()

proc getFloat*(c: Config, key: string not nil): float =
  # Retrieve a float config value.
  # 
  # If the key is not found, a KeyError is raised.
  # If the config key is not of type string, a ValueError is raised.
  
  let val = c.getValue(key)
  if not val.isFloat():
    raise newException(ValueError, "Key $1 is not an int, but '$2'".format(key, val.kind)) 
  result = val.getFloat()


#################
# Constructors. #
#################

proc newConfig*(): Config =
  # Construct a new empty config.

  Config(data: newValueMap(autoNesting = true))

proc newConfig*(data: tuple): Config =
  # Build a new config based on a tuple.

  result = Config(data: @%(data))
  result.data.autoNesting = true


#########
# JSON. #
#########

proc configFromJson*(jsonContent: string): Config {.raises: [ValueError, json.JsonParsingError, Exception].} = 
  # Load configuration from a json string.

  result = Config(data: values.fromJson(jsonContent))
  result.data.autoNesting = true

proc configFromJsonFile*(path: string): Config {.raises: [IOError, ValueError, json.JsonParsingError, Exception].} =
  # Load configuration from a JSON file.

  result = configFromJson(readFile(path))
  result.data.autoNesting = true

proc toJson*(c: Config): string =
  # Converts the config to a json string.

  values.toJson(c.data)

proc writeJsonFile*(c: Config, path: string) =
  # Writes the config data to a file as json.

  writeFile(path, c.toJson())
