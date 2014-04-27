module.exports.TouchGestures = class TouchGestures extends Backbone.Model

  initialize: ->
    console.log 'initializing touch gestures'
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    @set 'switcherInactive', false
    @windowEl = $(window)[0]
    @$switcher = $("nav.functionality")
    @switcherEl = @$switcher[0]
    @attachEvents()
    @gestureTolerance = 100 # ms

  attachEvents: ->

    Hammer(@windowEl).on "dragright", (ev) =>
      @dragrightStart = new Date() if !@dragrightStart
      if ev.gesture.center.pageX > 100
        @openSwitcher(ev, true)

    Hammer(@windowEl).on "dragleft", (ev) =>
      @dragleftStart = new Date() if !@dragleftStart
      if !@get("switcherInactive")
        @closeSwitcher(ev, true)

    $("#channel-switcher").on "click", ".channel-switcher-contents button", =>
      if !@get("switcherInactive")
        @$switcher.addClass("inactive")
        @set "switcherInactive", true

    Hammer(@windowEl).on "release", @fingerUp

  openSwitcher: (ev, acquireLock) ->
    return if !@get('switcherInactive')
    @gestureLock = "openSwitcher" if !@gestureLock and acquireLock
    return if @gestureLock != "openSwitcher"

    now = new Date()
    if now - @dragrightStart > @gestureTolerance
      @set 'switcherInactive', false
      @$switcher.removeClass("inactive")
      delete @dragrightStart

    ev.gesture.preventDefault()
    ev.preventDefault()

  closeSwitcher: (ev, acquireLock) ->
    return if @get('switcherInactive')
    @gestureLock = "closeSwitcher" if !@gestureLock and acquireLock
    return if @gestureLock != "closeSwitcher"

    now = new Date()
    if now - @dragleftStart > @gestureTolerance
      @set 'switcherInactive', true
      @$switcher.addClass("inactive")
      delete @dragleftStart

    ev.gesture.preventDefault()
    ev.preventDefault()

  fingerUp: (ev) ->
    delete @dragleftStart
    delete @dragrightStart
    @touchesFrozen = false
    @gestureLock = ""
