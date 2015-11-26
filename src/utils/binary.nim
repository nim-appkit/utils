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

from strutils import nil

########
# Ptr. #
########

type Ptr*[T] = object
  # Ptr is a helper object that makes working with pointers more convenient.

  ptrVal*: ptr T
  ptrAddr*: ByteAddress
  size*: int

proc `[]`*[T](p: Ptr[T]): T =
  p.ptrVal[]

proc `[]=`*[T](p: Ptr[T], val: T) =
  p.ptrVal[] = val

proc `[]`*[T](p: Ptr[T], index: Natural): Ptr[T] =
  if index == 0:
    return p
  if index > p.size - 1:
    raise newException(Exception, "Index out of bounds")
  Ptr[T](
    ptrVal: cast[ptr T](p.ptrAddr + index * sizeof T),
    ptrAddr: p.ptrAddr + index,
    size: p.size - index
  )

proc `[]=`*[T](p: Ptr[T], index: Natural, val: T) =
  p[index][] = val

iterator items[T](p: Ptr[T]): T =
  for i in 0..p.size - 1:
    yield p[i][]

iterator pairs[T](p: Ptr[T]): tuple[key: int, val: T] =
  for i in 0..p.size - 1:
    yield (i, cast[ptr T](p.ptrAddr + i * sizeof T)[])

proc convert*[T](p: Ptr[T], typ: typedesc): Ptr[typ] =
  Ptr[typ](
    ptrVal: cast[ptr typ](p.ptrAddr),
    ptrAddr: p.ptrAddr,
    size: 1
  )

proc valueAs*(p: Ptr, typ: typedesc): typ =
  cast[p](p.ptrVal[])

proc alloc*[T](p: var Ptr[T], size: Natural) =
  p.size = int(size)
  p.ptrVal = cast[ptr T](alloc0((sizeof T) * size))
  p.ptrAddr = cast[ByteAddress](p.ptrVal)

proc free*(p: Ptr) =
  dealloc(p.ptrVal)

proc copyFrom*(p: Ptr, source: pointer, size: int) =
  copyMem(p.ptrVal, source, size)

proc copyTo*(p: Ptr, dest: pointer) =
  copyMem(dest, p.ptrVal, p.size)

proc copyFrom*(p: Ptr, source: Ptr) =
  copyMem(p.ptrVal, source.ptrVal, source.size)

proc newPtr*[T](size: Natural): Ptr[T] =
  result.alloc(size)

proc newPtr*[T](p: pointer, size: Natural): Ptr[T] =
  result.ptrVal = cast[ptr T](p)
  result.ptrAddr = cast[ByteAddress](p)
  result.size = size

proc newPtr*[T](p: ptr T, size: Natural): Ptr[T] =
  result.ptrVal = p
  result.ptrAddr = cast[ByteAddress](p)
  result.size = int(size)

proc newPtr*(s: string): Ptr[uint8] =
  var s = s
  result.alloc(s.len())
  copyMem(result.ptrVal, addr(s[0]), s.len())

proc toString*(p: Ptr[uint8]): string =
  result = newString(p.size)
  for i, c in p:
    result[i] = char(c)

proc toBinary*[T](p: Ptr[T], withChildren: bool = false, asHex: bool = false): string =
  result = ""
  for i in 0..(sizeof T) - 1:
    when cpuEndian == bigEndian:
      var pos = i
    else:
      var pos = (sizeof T) - 1 - i
    var byte = cast[ptr uint8](p.ptrAddr + pos)
    
    if asHex:
      result &= "0x" & strutils.toHex(BiggestInt(byte[]), 2)
      continue
    
    var j = 7'u8
    while true:
      result &= $int((byte[] shr j and 1) > 0)

      if j > 0'u8:
        j -= 1'u8
      else:
        break
    if i < (sizeof T) - 1:
      result &= " "
      
  if withChildren and p.size > 1:
    for i in 1..p.size - 1:
      result &= " | " & p[i].toBinary(false, asHex)
