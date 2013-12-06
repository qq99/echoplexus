#
#utility:
#    useful extensions to global objects, if they must be made, should be made here
#

# clean up this global stuff!
if Storage
  # extend the local storage protoype if it exists
  Storage::setObj = (key, obj) ->
    localStorage.setItem key, JSON.stringify(obj)
  Storage::getObj = (key) ->
    JSON.parse localStorage.getItem(key)

module.exports.HTMLSanitizer = class HTMLSanitizer

  sanitize: (htmlString, allowedElements) ->

    ALLOWED_TAGS       = ["STRONG", "EM", "P", "A"]
    ALLOWED_ATTRIBUTES = ["href", "title"]

    clean = (el) ->
      tags = Array.prototype.slice.apply(el.getElementsByTagName("*"), [0])
      for tag, i in tags
        # throw it out, and all of its children, if it's not allowed
        if ALLOWED_TAGS.indexOf(tag.nodeName) == -1
          usurp(tags[i])
        # now remove all the troublesome attributes
        attrs = tag.attributes
        for attribute in tag.attributes
          if ALLOWED_ATTRIBUTES.indexOf(attribute.name) == -1
            delete tag.attributes.removeNamedItem(attribute.name)

        null

    usurp = (p) ->
      p.parentNode.removeChild(p)
      null

    div = document.createElement("div");
    div.innerHTML = htmlString
    clean(div)
    return div.innerHTML
