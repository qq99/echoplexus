require("../client/bootstrap.core.js.coffee").core()
Client            = require('../client/client.js.coffee')
ClientModel       = Client.ClientModel
ClientsCollection = Client.ClientsCollection
ChatClient        = require('../client/modules/chat/client.js.coffee').ChatClient

# overwrite with noops since these modes don't technically exist in embedded mode:
window.codingModeActive = window.chatModeActive = window.showPrivateOverlay = window.hidePrivateOverlay = ->

$(document).ready ->

  # grab the query params from the iframe URL:
  params = window.location.search.substr(1) # trim off leading ?
  params = params.split("&")
  options = {}
  _.map params, (ele) ->
    [key, val] = ele.split("=")
    options[key] = val

  channelName = options.channel || "/"

  # connect to socket
  io.connect window.location.origin,
    "connect timeout": 1000
    reconnect: true
    "reconnection delay": 2000
    "max reconnection attempts": 1000

  # and throw together a single channel's view
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
