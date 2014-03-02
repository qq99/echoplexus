utility           = require("../client/utility.js.coffee")
Client            = require('../client/client.js.coffee')
ClientModel       = Client.ClientModel
ClientsCollection = Client.ClientsCollection
ChatClient        = require('../client/modules/chat/client.js.coffee').ChatClient
Options           = require('../client/options.js.coffee').Options
require("../client/events.js.coffee")()
Keystore          = require("../client/keystore.js.coffee").Keystore

window.KEYSTORE = new Keystore()

openpgp.initWorker('js/openpgp.worker.js')

window.SOCKET_HOST = window.location.origin

window.GlobalUIState = new Backbone.Model
  chatIsPinned: false

window.codingModeActive = window.chatModeActive = window.showPrivateOverlay = window.hidePrivateOverlay = ->

$(document).ready ->

  globalOptions = new Options
    show_mewl: false
    suppress_join: true
    highlight_mine: true
    prefer_24hr_clock: false
    suppress_client: false
    show_OS_notifications: true
    suppress_identity_acknowledgements: true
    auto_scroll: true

  # grab the query params:
  params = window.location.search.substr(1) # trim off leading ?
  params = params.split("&")
  options = {}
  _.map params, (ele) ->
    [key, val] = ele.split("=")
    options[key] = val

  channelName = options.channel || "/"

  io.connect window.location.origin,
    "connect timeout": 1000
    reconnect: true
    "reconnection delay": 2000
    "max reconnection attempts": 1000

  channel = new Backbone.Model
    clients: new ClientsCollection()
    modules: []
    authenticated: false
    isPrivate: false

  singleChat = new ChatClient
    channel: channel
    room: channelName
    config:
      host: window.SOCKET_HOST

  singleChat.trigger "show"

  $("body").append(singleChat.$el)
