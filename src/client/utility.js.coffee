#
#utility:
#    useful extensions to global objects, if they must be made, should be made here
#

# attempt to determine their browsing environment
ua = window.ua =
  firefox: !!navigator.mozConnection
  chrome: !!window.chrome

# clean up this global stuff!
if Storage
  # extend the local storage protoype if it exists
  Storage::setObj = (key, obj) ->
    localStorage.setItem key, JSON.stringify(obj)
  Storage::getObj = (key) ->
    JSON.parse localStorage.getItem(key)

module.exports.isMobile = ->
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile/i.test(navigator.userAgent)

module.exports.HTMLSanitizer = class HTMLSanitizer

  sanitize: (htmlString, allowedElements, allowedAttributes) ->

    ALLOWED_TAGS       = ["STRONG", "EM", "P", "A", "UL", "LI"]
    ALLOWED_ATTRIBUTES = ["href", "title"]

    ALLOWED_TAGS       = allowedElements if allowedElements
    ALLOWED_ATTRIBUTES = allowedAttributes if allowedAttributes

    clean = (el) ->
      tags = Array.prototype.slice.apply(el.getElementsByTagName("*"), [0])
      for tag, i in tags
        # throw it out, and all of its children, if it's not allowed
        if ALLOWED_TAGS.indexOf(tag.nodeName) == -1
          usurp(tags[i])
        # now remove all the troublesome attributes
        attrs = tag.attributes
        for attribute in tag.attributes
          if attribute? and ALLOWED_ATTRIBUTES.indexOf(attribute.name) == -1
            delete tag.attributes.removeNamedItem(attribute.name)

        null

    usurp = (p) ->
      p.parentNode.removeChild(p)
      null

    div = document.createElement("div");
    div.innerHTML = htmlString
    clean(div)
    return div.innerHTML

module.exports.versionStringToNumber = (versionString) ->
  numeric = versionString.replace(/\./g,'').replace(/r/gi,'').split('')

  sum = 0

  i = numeric.length - 1
  j = 0
  while i >= 0 # fuckin coffeescript loops
    sum += parseInt(numeric[i], 10) * Math.pow(10,j)
    j++
    i--

  sum
