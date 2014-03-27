# polyfill from http://stackoverflow.com/questions/1060008/is-there-a-way-to-detect-if-a-browser-window-is-not-currently-active
# automatically exposes the property window.visibility_status = "hidden" || "visible"
(->
  hidden = "hidden"

  # Standards:
  if (hidden in document)
    document.addEventListener("visibilitychange", onchange)
  else if ((hidden = "mozHidden") in document)
    document.addEventListener("mozvisibilitychange", onchange)
  else if ((hidden = "webkitHidden") in document)
    document.addEventListener("webkitvisibilitychange", onchange)
  else if ((hidden = "msHidden") in document)
    document.addEventListener("msvisibilitychange", onchange)
  else if ('onfocusin' in document) # IE 9 and lower:
    document.onfocusin = document.onfocusout = onchange;
  else
    window.onpageshow = window.onpagehide = window.onfocus = window.onblur = onchange;

  onchange = (evt) ->
    v = 'visible'
    h = 'hidden'
    evtMap =
      focus: v
      focusin: v
      pageshow: v
      blur: h
      focusout: h
      pagehide: h

    evt = evt || window.event;
    if (evt.type in evtMap)
      window.visibility_status = evtMap[evt.type]
    else
      window.visibility_status = if this[hidden] then "hidden" else "visible"
)()
