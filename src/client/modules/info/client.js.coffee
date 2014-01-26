versions = require("../../version.js.coffee")
utility  = require("../../utility.js.coffee")
Mewl                    = require("../../ui/Mewl.js.coffee").MewlNotification

module.exports.InfoClient = class InfoClient extends Backbone.View

  initialize: (opts) ->
    _.bindAll this

    @config = opts.config
    @module = opts.module
    @socket = io.connect(@config.host + "/info")
    @channelName = opts.room

    #Initialize a path variable to hold the paths buffer as we recieve it from other clients
    @listen()
    @render()
    @attachEvents()

  listen: ->
    socket = @socket
    @socketEvents =
      private: =>
        window.events.trigger("private:#{@channelName}")

      "info:latest_supported_client_version": (msg) =>
        window.checkingVersion = false
        theirs = utility.versionStringToNumber(msg)
        ours   = utility.versionStringToNumber(versions.CLIENT_VERSION)
        if theirs > ours
          growl = new Mewl
            title: "Client out of date"
            body: "The server does not support this client.  Reloading..."

          setTimeout ->
            location.reload()
          , 5000

    _.each @socketEvents, (value, key) =>

      # listen to a subset of event
      socket.on "#{key}:#{@channelName}", value

    # initialize the channel
    socket.emit "subscribe", room: @channelName, @postSubscribe

    #On successful reconnect, attempt to rejoin the room
    socket.on "reconnect", =>

      #Resend the subscribe event
      socket.emit "subscribe",
        room: @channelName
        reconnect: true
      , @postSubscribe

  kill: ->

  attachEvents: ->

  postSubscribe: ->
    return if window.checkingVersion
    window.checkingVersion = true

    @socket.emit "info:latest_supported_client_version:#{@channelName}", ""

  refresh: ->

  render: ->
