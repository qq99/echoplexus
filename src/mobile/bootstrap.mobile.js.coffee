require("../client/bootstrap.core.js.coffee").core()
ChannelSwitcher = require("./ui/channel-switcher.js.coffee").ChannelSwitcher
utility         = require("../client/utility.js.coffee")
window.MODE     = 'mobile'
TouchGestures   = require("./ui/gestures.js.coffee").TouchGestures

$(document).ready ->

  setTimeout (->
    # reconnect the socket manually using the navigator's onLine property
    # don't bind this too early, just in case it interferes with the normal sequence of events
    $(window).on "online", ->
      console.log "attempting to force a sio reconnect"
      # the socket.io reconnect doesn't always fire after waking up from computer sleep
      # I assume this is due to max reconnection attempts being reached while disconnected, but who knows for sure
      # assuming it'll re-use the cnxn params we used below
      io.connect window.location.origin

  ), 5000

  # when the navigator goes offline, we'll attempt to set their icon to reflect that
  # this might be redundant, but is a good assumption when you're not running it on localhost
  $(window).on "offline", ->
    console.log "navigator has no internet connectivity"
    faviconizer.setDisconnected()

  io.connect window.location.origin,
    "connect timeout": 1000
    reconnect: true
    "reconnection delay": 2000
    "max reconnection attempts": 1000

  channelSwitcher = new ChannelSwitcher()
  $("header").append channelSwitcher.$el
  $("span.options").on "click", (ev) ->
    $(this).siblings("div.options").toggle()

  $(window).on "click", ->
    notifications.requestNotificationPermission()

  window.events.on "chat:activity", (data) ->
    $(".button[data-target='#chatting']").addClass "activity"  unless chatModeActive()
    unless document.hasFocus()
      faviconizer.setActivity()
      document.title = "!echoplexus"

  Gestures = new TouchGestures
