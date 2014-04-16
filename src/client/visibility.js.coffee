# polyfill from http://stackoverflow.com/questions/1060008/is-there-a-way-to-detect-if-a-browser-window-is-not-currently-active
# automatically exposes the property window.visibility_status = "hidden" || "visible"
(->
  hiddenProperty = "hidden"

  create_onchange = (fn) ->

    return (evt) ->
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
        # console.log "Visibility predicted to be #{evtMap[evt.type]}"
        fn(evt.type)
      else
        visibility = if document[hiddenProperty] then "hidden" else "visible"
        # console.log "Visibility known to be #{visibility}"
        fn(visibility)

  # polyfilling an attaching handler
  attachOnchange = (onchange) ->
    if (typeof document.hidden != 'undefined')
      hiddenProperty = 'hidden'
      document.addEventListener("visibilitychange", onchange)
    else if (typeof document.mozHidden != 'undefined')
      hiddenProperty = 'mozHidden'
      document.addEventListener("mozvisibilitychange", onchange)
    else if (typeof document.webkitHidden != 'undefined')
      hiddenProperty = 'webkitHidden'
      document.addEventListener("webkitvisibilitychange", onchange)
    else if (typeof document.msHidden != 'undefined')
      hiddenProperty = 'msHidden'
      document.addEventListener("msvisibilitychange", onchange)
    else if ('onfocusin' in document) # IE 9 and lower:
      document.onfocusin = document.onfocusout = onchange;
    else
      window.onpageshow = window.onpagehide = window.onfocus = window.onblur = onchange;

  window.VisibilityManager =
    onChange: (fn) ->
      onchangeHandler = create_onchange(fn)
      attachOnchange(onchangeHandler)

)()
