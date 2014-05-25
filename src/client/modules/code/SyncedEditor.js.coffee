ClientStructures      = require('../../client.js.coffee')
ColorModel            = ClientStructures.ColorModel
ClientsCollection     = ClientStructures.ClientsCollection
ClientModel           = ClientStructures.ClientModel

module.exports.SyncedEditor = class SyncedEditor extends Backbone.View

  class: "syncedEditor"

  initialize: (opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    throw "There was no editor supplied to SyncedEditor"  unless opts.hasOwnProperty("editor")
    throw "There was no room supplied to SyncedEditor"  unless opts.hasOwnProperty("room")
    @editor = opts.editor
    @clients = opts.clients
    @channelName = opts.room
    @subchannelName = opts.subchannel
    @channel = opts.channel
    @channelKey = @channelName + ":" + @subchannelName
    @socket = io.connect(opts.host + "/code")
    @active = false
    @listen()
    @attachEvents()

    # initialize the channel
    @socket.emit "subscribe",
      room: @channelName
      subchannel: @subchannelName
    , @postSubscribe

    @on "show", =>
      @active = true
      @editor.refresh() if @editor

    @on "hide", =>
      @active = false
      $(".ghost-cursor").remove()

    # remove their ghost-cursor when they leave
    @clients.on "remove", (model) =>
      $(".ghost-cursor[rel='#{@channelKey}#{model.get("id")}']").remove()

    $("body").on "codeSectionActive", => # sloppy, forgive me
      @trigger "eval"

  postSubscribe: ->

  kill: ->
    @dead = true
    _.each @socketEvents, (method, key) =>
      @socket.removeAllListeners "#{key}:#{@channelKey}"

    @socket.emit "unsubscribe:#{@channelKey}", room: @channelName

  attachEvents: ->
    socket = @socket
    @editor.on "change", (instance, change) =>
      if change.origin? and change.origin isnt "setValue"
        socket.emit "code:change:#{@channelKey}", change
      @trigger "eval" if codingModeActive()

    @editor.on "cursorActivity", (instance) =>
      return if not @active or not codingModeActive() # don't report cursor events if we aren't looking at the document
      socket.emit "code:cursorActivity:#{@channelKey}", cursor: instance.getCursor()

  listen: ->
    editor = @editor
    socket = @socket
    @socketEvents =
      "code:change": (change) =>
        # received a change from another client, update our view
        @applyChanges change

      "code:request": =>
        # received a transcript request from server, it thinks we're authority
        # send a copy of the entirety of our code
        socket.emit "code:full_transcript:#{channelKey}", code: editor.getValue()

      "code:sync": (data) ->
        # hard reset / overwrite our code with the value from the server
        editor.setValue data.code if editor.getValue() isnt data.code

      "code:authoritative_push": (data) =>
        # received a batch of changes and a starting value to apply those changes to
        editor.setValue data.start
        i = 0

        while i < data.ops.length
          @applyChanges data.ops[i]
          i++

      "code:cursorActivity": (data) => # show the other users' cursors in our view
        return  if not @active or not codingModeActive()
        pos = editor.cursorCoords(data.cursor, "local") # their position
        fromClient = @clients.get(data.id) # our knowledge of their client object
        fromNick = fromClient.getNick(@channel.get("cryptokey"))
        return  if !fromClient? # this should never happen

        # try to find an existing ghost cursor:
        $ghostCursor = $(".ghost-cursor[rel='#{@channelKey}#{data.id}']") # NOT SCOPED: it's appended and positioned absolutely in the body!
        unless $ghostCursor.length # if non-existent, create one
          $ghostCursor = $("<div class='ghost-cursor' rel='#{@channelKey}#{data.id}'></div>")
          $(editor.getWrapperElement()).find(".CodeMirror-lines > div").append $ghostCursor
          $ghostCursor.append "<div class='user'>#{fromNick}</div>"
        clientColor = fromClient.get("color").toRGB()
        $ghostCursor.css
          background: clientColor
          color: clientColor
          top: pos.top
          left: pos.left

    _.each @socketEvents, (value, key) =>
      socket.on "#{key}:#{@channelKey}", value

    #On successful reconnect, attempt to rejoin the room
    socket.on "reconnect", =>
      return if @dead
      #Resend the subscribe event
      socket.emit "subscribe",
        room: @channelName
        subchannel: @subchannelName
        reconnect: true

  applyChanges: (change) ->
    editor = @editor
    editor.replaceRange change.text, change.from, change.to
    while change.next isnt `undefined` # apply all the changes we receive until there are no more
      change = change.next
      editor.replaceRange change.text, change.from, change.to
