#
#utility:
#    useful extensions to global objects, if they must be made, should be made here
#

# extend the local storage protoype if it exists
module.exports = ->
  if Storage
    Storage::setObj = (key, obj) ->
      localStorage.setItem key, JSON.stringify(obj)

    Storage::getObj = (key) ->
      JSON.parse localStorage.getItem(key)
