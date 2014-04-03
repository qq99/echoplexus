# A set of common things, global functions, global objects that will
# probably be used across ALL clients (desktop, mobile, embedded)
module.exports.core = ->

  # attempt to determine their browsing environment
  ua = window.ua =
    firefox: !!navigator.mozConnection
    chrome: !!window.chrome

  if Storage # extend the local storage protoype if it exists
    Storage::setObj = (key, obj) ->
      localStorage.setItem key, JSON.stringify(obj)
    Storage::getObj = (key) ->
      JSON.parse localStorage.getItem(key)

  openpgp.initWorker('js/openpgp.worker.min.js')

  Notifications     = require("./ui/Notifications.js.coffee").Notifications
  Faviconizer       = require("./ui/Faviconizer.js.coffee").Faviconizer
  Options           = require("./options.js.coffee").Options
  Keystore          = require("./keystore.js.coffee").Keystore

  require("./visibility.js.coffee")
  require("./events.js.coffee")()

  # these should really be refactored:
  window.codingModeActive = ->
    $("#coding").is ":visible"
  window.chatModeActive = ->
    $("#chatting").is ":visible"

  window.showPrivateOverlay = ->
    $("#is-private, #info-overlay").show()
    $("#panes").hide()
    $("#channel-password").focus()
  window.hidePrivateOverlay = ->
    $("#is-private, #info-overlay").hide()
    $("#panes").show()

  window.turnOffLiveReload = ->
    $(".livereload").attr "checked", false


  # global state / components needed for application
  window.GlobalUIState = new Backbone.Model
    chatIsPinned: false

  window.faviconizer = new Faviconizer()
  window.notifications = new Notifications()

  # Set cookie options
  # 14 seems like a good time to keep the cookie around
  window.COOKIE_OPTIONS =
    path: "/"
    expires: 14
    secure: (window.location.protocol == "https:")

  window.KEYSTORE = new Keystore()
  window.SOCKET_HOST = window.location.origin
  options = new Options()
