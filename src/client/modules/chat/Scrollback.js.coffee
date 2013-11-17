# object: a stack-like data structure supporting only:
#    - an index representing the currently looked-at element
#  - peeking at an element before/after the current stack pointer, and modifying that pointer
#	- adding new elements to the top of the stack
#	- emptying the stack
#  - replacing an element in the stack with another element
define ->
  ->
    "use strict"
    buffer = []
    position = 0
    add: (userInput) ->
      buffer.push userInput
      position += 1

    prev: ->
      position -= 1  if position > 0
      buffer[position]

    next: ->
      position += 1  if position < buffer.length
      buffer[position]

    replace: (prevObj, newObj) ->
      start = buffer.length - 1 # start at the end of the array as this will be the most common case
      i = start

      while i >= 0
        if buffer[i] is prevObj
          buffer[i] = newObj
          return true
        i--
      false # no match

    reset: ->
      position = buffer.length
