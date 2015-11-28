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


import os
import locks, threadpool
import tables
import times
from sequtils import keepIf
from strutils import `%`

proc `or`(a, b: float): float =
  if a != 0: a else: b

type Acquisition[T] = ref object of RootObj
  id: int
  lock: Lock
  acquiredAt: float
  released: bool
  releaseRequested: bool

  resource: T

proc newAcquisition[T](id: int, resource: T): Acquisition[T] =
  result = Acquisition[T](
    `id`: id,
    `resource`: resource,
    acquiredAt: cpuTime()
  )
  initLock(result.lock)

proc release*[T](a: Acquisition[T]) =
  a.lock.acquire()
  a.released = true
  a.lock.release()

proc isReleased[T](a: Acquisition[T]): bool =
  a.lock[].acquire()
  result = a.released
  a.lock[].release()

proc requestRelease[T](a: Acquisition[T]) =
  a.lock.acquire()
  a.releaseRequested = true
  a.lock.release()

proc shouldRelease*[T](a: Acquisition[T]): bool =
  a.lock.acquire()
  result = a.releaseRequested 
  a.lock.release()

proc cleanup[T](a: Acquisition[T]) =
  deinitLock(a.lock)

type
  Pool[T] = ref object of RootObj
    # Maximum number of resources to be created.
    maxResources: int
    
    # Maximum idle time in seconds before a resource is destroyed.
    maxIdleTime: float
    
    # Interval in seconds between invoking keepAlive actions on a resource.
    keepAliveInterval: float
    
    # Time in seconds before an acquired resource is forcefully reclaimed.
    reclaimTimeout: float
    
    # Maximum wait time in seconds before a resource acquisition fails.
    maxWaitTime: float

    lockVar: Lock
  
    #runThread: Thread[pointer]    
    runThread: Thread[ptr Pool[T]]    
    doClose: bool
    forceClose: bool
    closeWaitVar: Cond
    
    # Counter for created resources.
    idCounter: int
    
    # Table holding all existing resources.
    resources: Table[int, T]
    
    # Currently idle resources.
    idleResources: seq[tuple[
      id: int, 
      lastUsed: float
    ]]

    resourceAvailableCond: ref Cond

    # Resources currently in use.
    activeResources: seq[Acquisition[T]]
    
proc init[T](p: var Pool[T]) =
  new(p)
  p.maxResources = 20
  p.maxIdleTime = 60
  p.keepAliveInterval = 15
  p.reclaimTimeout = -1
  p.maxWaitTime = 5
  p.resources = initTable[int, T](32)
  p.idleResources = @[]
  p.activeResources = @[]

  initLock(p.lockVar)
  new(p.resourceAvailableCond)
  initCond(p.resourceAvailableCond[])

proc lock[T](p: Pool[T]) =
  p.lockVar.acquire()
  echo(">>>>>>>> LOCK")

proc unlock[T](p: Pool[T]) =
  p.lockVar.release()
  echo("<<<<<<<< UNLOCK")

# Resource methods.

type BuildErr = object of Exception
  discard

proc newBuildErr*(msg: string): ref BuildErr =
  newException(BuildErr, msg)

method buildResource[T](p: Pool[T]): T {. raises: [BuildErr] .} =
  quit("Pool must have a buildResource() method!")

method isAlive[T](res: T): bool {. raises: [] .} =
  quit ("Resource must have an isAlive() method!")

method keepAlive[T](res: T): bool {.raises: [] .} =
  return true

method teardown[T](res: T) {. raises: [] .} =
  discard

# 

proc createResource[T](p: Pool[T]): int =
  # Build a new resource.
  # Lock must be active!

  var newResource = p.buildResource()
  p.idCounter += 1
  var id = p.idCounter
  p.resources[id] = newResource

  p.idleResources.add((id, cpuTime()))
  echo("new res id: ", $id)
  echo("created new resource. Currently idle: ", repr(p.idleResources))
  return id

proc removeResource[T](p: Pool[T], id: int) =
  # Removes a resource and tears it down.
  # Lock must be active!

  p.resources[id].teardown()
  p.resources.del(id)


proc claimIdleResource[T](p: Pool[T]): Acquisition[T] =
  # Claims an idle resource and marks it as active.
  # Lock must be active!
  
  echo("Trying to claim idle resource") 
  if p.idleResources.len() < 1:
    echo("No idle resources available")
    # No idle resources.
    return nil

  # Idle resource is available.
  let (id, lastUsed) = p.idleResources.pop()
  echo("Possible idle resouce: " & $id)

  # Check that the resouce is still alive.
  if not p.resources[id].isAlive():
    # Resouce is not alive, so destroy it.
    p.removeResource(id)
    echo("Removing dead resource: " & $id)
    # Try again.
    return p.claimIdleResource()

  # Add resource to active ones.
  result = newAcquisition(id, p.resources[id])
  p.activeResources.add(result)

proc doAcquire[T](p: Pool[T]): Acquisition[T] =
  # Lock must be active!

  result = p.claimIdleResource()

  if result == nil:
    # No idle resource available.
    # Check if we can create a new one.
    if p.resources.len() < p.maxResources:
      discard p.createResource()
      result = p.claimIdleResource()

proc acquire[T](p: Pool[T]): Acquisition[T] =
  # Acquires a new resource.

  # Lock the pool. 
  p.lock()
  echo(">> Lock acquired!")

  if p.doClose:
    # Pool is closing down, so no new resources can be acquired.
    p.unlock()
    return nil
  
  echo("P: Trying to new res") 
  result = p.doAcquire()  
  if result != nil:
    echo("P: new/idle res available")
    # Idle or newly created resource available.
    # Release lock and return.
    p.unlock()
    return

  # Max connections already exist, so wait.
  p.unlock()

  # Wait for resource to become available.
  echo("Waiting for acquisition")
  p.resourceAvailableCond[].wait(p.lockVar)

  result = p.doAcquire()
  # Note: if result is null, 
  # acquisition is assumed to have failed.

  p.unlock()

proc doRelease[T](p: Pool[T], acquisition: Acquisition[T]) =
  # Release an acquired resource.
  # Lock must be active!

  let id = acquisition.id

  # Remove res from active resources.
  keepIf(p.activeResources, proc(a: Acquisition[T]): bool = a.id != id)

  # Check if resource is still alive.
  if not p.resources[id].isAlive():
    # Resource is not alive anymore, so remove it.
    p.removeResource(id)
  else:
    # Resource still alive.
    # Send a keep-alive to be sure, and make it available again.
    if not p.resources[id].keepAlive():
      # Keep-alive failed.
      p.removeResource(id)
    else:
      p.idleResources.add((id, cpuTime()))

proc release[T](p: Pool[T], acquisition: Acquisition[T]) =
  # Relase an acquired resource.

  # Lock pool.
  p.lock()
  p.doRelease(acquisition)
  # Unlock the pool.
  p.unlock()

proc run[T](pp: ptr Pool[T]) =
  var p = pp[]

  while true:
    sleep(10000)
    p.lock()
    echo("processing ")

    # Handle closing logic.
    if p.doClose:
      # Shutdown logic is handled in other loop below.
      break

    # Not closing, so process normally.
    var now = cpuTime()
    # Check if idle resources need a keepalive or should be closed.
    var remainingIdle: seq[tuple[id: int, lastUsed: float]] = @[]
      
    for index, item in p.idleResources:
      var (id, lastUsed) = item
      if p.maxIdleTime > 0 and now - lastUsed > p.maxIdleTime:
        # Maximum idle time has passed. 
        p.removeResource(id)
        continue

      if p.keepAliveInterval > 0:
        if now - lastUsed > p.keepAliveInterval:
          if not p.resources[item.id].keepAlive():
            # Keepalive failed, so remove.
            p.removeResource(item.id)
            continue

          p.idleResources[index].lastUsed = now

      remainingIdle.add(p.idleResources[index])

    p.idleResources = remainingIdle

    discard """
    if p.waitList.len() > 0:
      # Process waitlist items.
      var availableCount = p.idleResources.len() + (p.maxResources - p.activeResources.len())
      for item in p.waitList:
        if availableCount < 1:
          break

        var c = item.waitVar
        c[].signal()
        availableCount -= 1
    """

    p.unlock()

  # Shutdown logic.

  # Abort all waiting acquisitions.
    discard """
  for item in p.waitList:
    item.waitVar[].signal()
  p.waitList = @[]
  """
  
  # Send shouldRelease to all active acquisitions. 
  for ac in p.activeResources:
    ac.requestRelease()

  if p.forceClose:
    # Forced closedown, so we do not wait.
    p.closeWaitVar.signal()
    p.unlock()
    return

  # Unlock.
  p.unlock()

  # Wait for all resources to get released.
  while true:
    p.lock()
    if p.activeResources.len() < 1:
      # No more active resources, so all done.
      p.closeWaitVar.signal()
      p.unlock()
      break
    p.unlock()

proc start[T](p: var Pool[T]) =
  initCond(p.closeWaitVar)
  var pp: ptr Pool[T] = p.addr
  createThread(p.runThread, run, pp)

proc close[T](p: Pool[T], force: bool = false) =
  # Close down the whole pool.

  p.lock.acquire()
  # Let run thread know that it should close.
  p.doClose = true 
  p.forceClose = force
  p.lock.release()

  # Wait until closing is done.
  p.closeWaitVar.wait(p.lockVar)
  
  # Waiting is all done.
  # Clean up resources.
  p.lock.acquire()
  for id in p.resources.keys():
    p.removeResource(id)
  p.lock.release()

  # All done, closedown finished.

type Resource = object
  id: int


var idCount = 0

method buildResource(p: Pool[Resource]): Resource =
  idCount += 1
  echo("buildResource() - " & $idCount)
  Resource(id: idCount)

method isAlive(res: Resource): bool =
  echo("spec.isAlive() - " & $(res.id))
  true

method keepAlive(res: Resource): bool =
  echo("keepAlive() - " & $(res.id))

method teardown(res: Resource): bool =
  echo("teardown() - " & $(res.id))

var p: Pool[Resource]
p.init()
p.maxResources = 1
p.start()


proc doWork(id: int) {.gcsafe.} =
  echo($id & ": Acquiring new res")
  var ac = p.acquire()
  echo("Acquired resource " & ac.id.`$`)

  sleep(10000)
  echo($id & ": Releasing res: " & $ac.id)
  ac.release()
  echo($id & ": All done!")
  

for i in 0..3:
  spawn(doWork(i))

sleep(9999999)
