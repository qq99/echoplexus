chatpanelTemplate       = require("./templates/chatPanel.html")
chatinputTemplate       = require("./templates/chatInput.html")
fileUploadTemplate      = require("./templates/fileUpload.html")
cryptoModalTemplate     = require("./templates/channelCryptokeyModal.html")
REGEXES                 = require("../../regex.js.coffee").REGEXES
Faviconizer             = require("../../ui/Faviconizer.js.coffee").Faviconizer
Autocomplete            = require("./Autocomplete.js.coffee").Autocomplete
Scrollback              = require("./Scrollback.js.coffee").Scrollback
Log                     = require("./Log.js.coffee").Log
ChatAreaView            = require("./ChatAreaView.js.coffee").ChatAreaView
Mewl                    = require("../../ui/Mewl.js.coffee").MewlNotification
Client                  = require('../../client.js.coffee')
ColorModel              = Client.ColorModel
ClientModel             = Client.ClientModel
ClientsCollection       = Client.ClientsCollection
CryptoWrapper           = require("../../CryptoWrapper.coffee").CryptoWrapper
cryptoWrapper           = new CryptoWrapper


faviconizer = new Faviconizer

module.exports.CryptoModal = class CryptoModal extends Backbone.View
  className: "backdrop"
  template: cryptoModalTemplate
  events:
    "keydown input.crypto-key": "checkToSetKey"
    "click .set-encryption-key": "setCryptoKey"
    "click .cancel": "remove"

  initialize: (opts) ->
    _.bindAll this
    _.extend this, opts
    @$el.html @template(opts)
    $("body").append @$el
    $("input", @$el).focus()

  checkToSetKey: (e) ->
    @setKey $(".crypto-key", @$el).val()  if e.keyCode is 13

  setCryptoKey: (e) ->
    @setKey $(".crypto-key", @$el).val()

  setKey: (key) ->
    @trigger "setKey",
      key: key

    @remove()

module.exports.ChatMessage = class ChatMessage extends Backbone.Model
  getBody: (cryptoKey) ->
      body = @get("body")
      encrypted_body = @get("encrypted")
      body = cryptoWrapper.decryptObject(encrypted_body, cryptoKey)  if (typeof cryptoKey isnt "undefined") and (cryptoKey isnt "") and (typeof encrypted_body isnt "undefined")
      body

module.exports.ChatClient = class ChatClient extends Backbone.View

  readablizeBytes = (bytes) ->
    s = ["bytes", "kB", "MB", "GB", "TB", "PB"]
    e = Math.floor(Math.log(bytes) / Math.log(1024))
    (bytes / Math.pow(1024, e)).toFixed(2) + " " + s[e]

  className: "chatChannel"

  template: chatpanelTemplate
  inputTemplate: chatinputTemplate
  fileUploadTemplate: fileUploadTemplate

  initialize: (opts) ->
    _.bindAll this
    @hidden = true
    @config = opts.config
    @module = opts.module
    @socket = io.connect(@config.host + "/chat")
    @channel = opts.channel
    @channel.clients.model = ClientModel
    @channelName = opts.room
    @autocomplete = new Autocomplete()
    @scrollback = new Scrollback()
    @persistentLog = new Log(namespace: @channelName)

    @me = new ClientModel
      socket: @socket
      room: opts.room
    @me.peers = @channel.clients # let the client have access to all the users in the channel

    @chatLog = new ChatAreaView
      room: @channelName
      persistentLog: @persistentLog
      me: @me

    @me.cryptokey = window.localStorage.getItem("chat:cryptokey:" + @channelName)
    delete @me.cryptokey  if @me.cryptokey is ""

    @me.persistentLog = @persistentLog
    @listen()
    @render()
    @attachEvents()
    @bindReconnections() # Sets up the client for Disconnect messages and Reconnect messages

    # initialize the channel
    @socket.emit "subscribe", room: @channelName, @postSubscribe

    # if there's something in the persistent chatlog, render it:
    unless @persistentLog.empty()
      entries = @persistentLog.all()
      renderedEntries = []
      i = 0
      l = entries.length

      while i < l
        model = new ChatMessage(entries[i])
        entry = @chatLog.renderChatMessage(model,
          delayInsert: true
        )
        renderedEntries.push entry
        i++
      @chatLog.insertBatch renderedEntries

    # triggered by ChannelSwitcher:
    @on "show", @show
    @on "hide", @hide
    @channel.clients.on "change:nick", (model, changedAttributes) =>
      prevName = undefined
      currentName = model.getNick(@me.cryptokey)
      if @me.is(model)
        prevName = "You are"
      else
        prevClient = new ClientModel(model.previousAttributes())
        prevName = prevClient.getNick(@me.cryptokey)
        prevName += " is"
      @chatLog.renderChatMessage new ChatMessage(
        body: prevName + " now known as " + currentName
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "identity ack"
      )

    @channel.clients.on "add", (model) =>
      @chatLog.renderChatMessage new ChatMessage(
        body: model.getNick(@me.cryptokey) + " has joined the room."
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "join"
      )

    @channel.clients.on "remove", (model) =>
      @chatLog.renderChatMessage new ChatMessage(
        body: model.getNick(@me.cryptokey) + " has left the room."
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "part"
      )

    @channel.clients.on "add remove reset change", (model) =>
      @chatLog.renderUserlist @channel.clients
      @autocomplete.setPool _.map(@channel.clients.models, (user) =>
        user.getNick @me.cryptokey
      )


    # doesn't work when defined as a backbone event :(
    @scrollSyncLogs = _.throttle(@_scrollSyncLogs, 500) # so we don't sync too quickly
    $(".messages", @$el).on "mousewheel DOMMouseScroll", @scrollSyncLogs

    $(window).on "resize", @chatLog.scrollToLatest

  events:
    "click button.syncLogs": "activelySyncLogs"
    "click button.deleteLocalStorage": "deleteLocalStorage"
    "click button.deleteLocalStorageAndQuit": "logOut"
    "click button.clearChatlog": "clearChatlog"
    "click .reply-button": "reply"
    "keydown .chatinput textarea": "handleChatInputKeydown"
    "click button.not-encrypted": "showCryptoModal"
    "click button.encrypted": "clearCryptoKey"
    "dragover .linklog": "showDragUIHelper"
    "dragleave .drag-mask": "hideDragUIHelper"
    "drop .drag-mask": "dropObject"
    "click .cancel-upload": "clearUploadStaging"
    "click .upload": "uploadFile"

  _scrollSyncLogs: (ev) ->
    # make a note of how tall in scrollable px the messages area used to be
    @previousScrollHeight = ev.currentTarget.scrollHeight

    # let the chatlog know that we've been scrolling (s.t. it doesn't autoscroll back down on us)
    @chatLog.mostRecentScroll = Number(new Date())

    # load more messages as we scroll upwards
    @activelySyncLogs()  if ev.currentTarget.scrollTop is 0 and not @scrollSyncLocked

  showDragUIHelper: (ev) ->
    @noop ev
    $(".linklog", @$el).addClass "drag-into"
    $(".drag-mask, .drag-staging", @$el).show()

  hideDragUIHelper: (ev) ->
    @noop ev
    $(".linklog", @$el).removeClass "drag-into"
    $(".drag-mask, .drag-staging", @$el).hide()

  noop: (ev) ->
    ev.stopPropagation()
    ev.preventDefault()


  # return false;
  dropObject: (ev) ->
    @noop ev
    console.log ev.originalEvent.dataTransfer # will report .files.length => 0 (it's just a console bug though!)
    console.log ev.originalEvent.dataTransfer.files[0] # it actually exists :o
    file = ev.originalEvent.dataTransfer.files[0]
    if typeof file is "undefined" or file is null
      @clearUploadStaging()
      return
    @file = file
    reader = new FileReader()
    reader.addEventListener "loadend", ((e) =>
      data =
        fileName: @file.name
        fileSize: readablizeBytes(@file.size)
        img: null

      # show img preview
      data.img = e.target.result  if e.target.result.match(/^data:image/)
      $(".staging-area", @$el).html @fileUploadTemplate(data)
    ), false
    reader.readAsDataURL file
    $(".drag-mask", @$el).hide()

  clearUploadStaging: ->
    $(".drag-staging, .drag-mask", @$el).hide()
    $(".staging-area", @$el).html ""
    delete @file

  uploadFile: ->
    $progressBarContainer = $(".progress-bar", @$el)
    $progressMeter = $(".meter", @$el)

    # construct a new form to send the data via
    oForm = new FormData()

    # add the file to the form
    oForm.append "user_upload", @file

    # create a new XHR request
    oReq = new XMLHttpRequest()

    # is it uploads, increase the width of the progress bar
    oReq.upload.addEventListener "progress", ((ev) ->
      percentage = (ev.loaded / ev.total) * 100
      $progressMeter.css "width", percentage + "%" # namespace
    ), false

    # when it's done, hide the progress bar
    oReq.upload.addEventListener "load", (ev) ->
      $progressBarContainer.removeClass "active"

    oReq.open "POST", window.location.origin
    oReq.setRequestHeader "Using-Permission", "canUploadFile"
    oReq.setRequestHeader "Channel", @channelName
    oReq.setRequestHeader "From-User", @me.get("id")
    oReq.setRequestHeader "Antiforgery-Token", @me.antiforgery_token
    oReq.send oForm # send it

    # show the progress bar
    $progressBarContainer.addClass "active"
    @clearUploadStaging()
    false

  show: ->
    @$el.show()
    @chatLog.scrollToLatest()
    $("textarea", @$el).focus()
    @hidden = false

  hide: ->
    @$el.hide()
    @hidden = true

  bindReconnections: ->
    #Bind the disconnnections, send message on disconnect
    @socket.on "disconnect", =>
      @chatLog.renderChatMessage new ChatMessage
        body: "Disconnected from the server"
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "client"

      window.disconnected = true
      faviconizer.setDisconnected()


    #On reconnection attempts, print out the retries
    @socket.on "reconnecting", (nextRetry) =>
      @chatLog.renderChatMessage new ChatMessage
        body: "Connection lost, retrying in " + nextRetry / 1000.0 + " seconds"
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "client"

    #On successful reconnection, render the chatmessage, and emit a subscribe event
    @socket.on "reconnect", =>

      #Resend the subscribe event
      @socket.emit "subscribe",
        room: @channelName
        reconnect: true
      , => # server acks and we:
        # if we were idle on reconnect, report idle immediately after ack
        @me.inactive "", @channelName, @socket  if @me.get("idle")
        @postSubscribe()



  kill: ->
    $(window).off "resize", @chatLog.scrollToLatest
    console.log 'kill'
    window.events.off "channelPassword:#{@channelName}"
    @socket.emit "unsubscribe:" + @channelName
    _.each @socketEvents, (method, key) =>
      @socket.removeAllListeners "#{key}:#{@channelName}"


  postSubscribe: (data) ->
    @chatLog.renderChatMessage new ChatMessage
      body: "Connected. Now talking in channel " + @channelName
      type: "SYSTEM"
      timestamp: new Date().getTime()
      nickname: ""
      class: "client"

    # attempt to automatically /nick and /ident
    $.when(@autoNick()).done =>
      @autoIdent()

    # start the countdown for idle
    @startIdleTimer()
    window.disconnected = false
    faviconizer.setConnected()

  autoNick: ->
    acked = $.Deferred()
    storedNick = $.cookie("nickname:" + @channelName)
    if storedNick
      @me.setNick storedNick, @channelName, acked
    else
      acked.reject()
    acked.promise()

  autoIdent: ->
    acked = $.Deferred()
    storedIdent = $.cookie("ident_pw:" + @channelName)
    if storedIdent
      @me.identify storedIdent, @channelName, acked
    else
      acked.reject()
    acked.promise()

  authenticate: (password) ->
    acked = $.Deferred()

    if password
      @me.channelAuth password, @channelName, acked if password
    else
      acked.reject()

    $.when(acked).done =>
      @channel.authenticated = true
      hidePrivateOverlay()

    $.when(acked).fail (err) =>
      if !@hidden
        showPrivateOverlay()
        if password
          growl = new Mewl(
            title: @channelName + ": Error"
            body: err
          )

    acked.promise()

  autoAuth: ->
    storedAuth = $.cookie("channel_pw:" + @channelName)
    return @authenticate(storedAuth)

  render: ->
    @$el.html @template()
    $(".chat-panel", @$el).html @chatLog.$el
    @$el.attr "data-channel", @channelName
    @$el.find(".chatarea-contents").append @inputTemplate(encrypted: (typeof @me.cryptokey isnt "undefined" and @me.cryptokey isnt null))

  channelIsPrivate: =>
    @channel.isPrivate = true
    showPrivateOverlay() if !@hidden

    @autoAuth()

  checkToNotify: (msg) ->

    # scan through the message and determine if we need to notify somebody that was mentioned:
    msgBody = msg.getBody(@me.cryptokey)
    myNick = @me.getNick(@me.cryptokey)
    msgClass = msg.get("class")
    fromNick = msg.get("nickname")
    atMyNick = "@" + myNick
    encrypted_nick = msg.get("encrypted_nick")
    fromNick = cryptoWrapper.decryptObject(encrypted_nick, @me.cryptokey)  if encrypted_nick

    # check to see if me.nick is contained in the msgme.
    if (msgBody.toLowerCase().indexOf(atMyNick.toLowerCase()) isnt -1) or (msgBody.toLowerCase().indexOf("@all") isnt -1)

      # do not alter the message in the following circumstances:
      # don't notify for join/part; it's annoying when anonymous
      return msg  if (msgClass.indexOf("part") isnt -1) or (msgClass.indexOf("join") isnt -1)  if msgClass # short circuit
      if @channel.isPrivate or msgClass is "private"

        # display more privacy-minded notifications for private channels
        notifications.notify
          title: "echoplexus"
          body: "There are new unread messages"
          tag: "chatMessage"

      else

        # display a full notification
        notifications.notify
          title: fromNick + " says:"
          body: msgBody
          tag: "chatMessage"

      msg.set "directedAtMe", true # alter the message
    if msg.get("type") isnt "SYSTEM" # count non-system messages as chat activity
      window.events.trigger "chat:activity",
        channelName: @channelName


      # do not show a growl for this channel's chat if we're looking at it
      if (@hidden or not chatModeActive())
        growl = new Mewl(
          title: @channelName + ":  " + fromNick
          body: msgBody
        )
    msg

  listen: ->
    socket = @socket
    @socketEvents =
      chat: (msg) =>
        window.events.trigger "message", socket, @, msg
        message = new ChatMessage(msg)

        # update our scrollback buffer so that we can quickly edit the message by pressing up/down
        # https://github.com/qq99/echoplexus/issues/113 "Local scrollback should be considered an implicit edit operation"
        @scrollback.replace message.getBody(@me.cryptokey), "/edit ##{message.get("mID")} #{message.getBody(@me.cryptokey)}"  if message.get("you")
        @checkToNotify message
        @persistentLog.add message.toJSON()
        @chatLog.renderChatMessage message

      "chat:batch": (msgs) =>
        msg = undefined
        i = 0
        l = msgs.length

        while i < l
          msg = JSON.parse(msgs[i])
          if not @persistentLog.has(msg.mID)
            @persistentLog.add msg
            msg.fromBatch = true
            @chatLog.renderChatMessage new ChatMessage(msg)
          i++

        if @previousScrollHeight
          chatlog = @chatLog.$el.find(".messages")[0]
          chatlog.scrollTop = chatlog.scrollHeight - @previousScrollHeight

        @scrollSyncLocked = false # unlock the lock on scrolling to sync logs

      "client:changed": (alteredClient) =>
        prevClient = @channel.clients.findWhere(id: alteredClient.id)
        alteredClient.color = new ColorModel(alteredClient.color)  if alteredClient.color
        if prevClient
          prevClient.set alteredClient
          prevClient.unset "encrypted_nick"  if !alteredClient.encrypted_nick?
          # backbone won't unset undefined

          # check to see if it's ME that's being updated
          # TODO: this is hacky, but it fixes notification nick checking :s
          if prevClient.get("id") is @me.get("id")
            @me.set alteredClient
            @me.unset "encrypted_nick"  if !alteredClient.encrypted_nick?
        # backbone won't unset undefined
        else # there was no previous client by this id
          @channel.clients.add alteredClient

      "client:removed": (alteredClient) =>
        prevClient = @channel.clients.remove(id: alteredClient.id)

      private_message: (msg) =>
        message = new ChatMessage(msg)
        msg = @checkToNotify(message)
        @persistentLog.add message.toJSON()
        @chatLog.renderChatMessage message

      webshot: (msg) =>
        @chatLog.renderWebshot msg

      subscribed: =>
        @postSubscribe()

      "chat:edit": (msg) =>
        message = new ChatMessage(msg)
        msg = @checkToNotify(message) # the edit might have been to add a "@nickname", so check again to notify
        @persistentLog.replaceMessage message.toJSON() # replace the message with the edited version in local storage
        @chatLog.replaceChatMessage message # replace the message with the edited version in the chat log

      "client:id": (msg) =>
        @me.set "id", msg.id

      userlist: (msg) =>

        # update the pool of possible autocompletes
        @channel.clients.reset msg.users

      "chat:currentID": (msg) =>
        missed = undefined
        @persistentLog.latestIs msg.mID # store the server's current sequence number

        # find out only what we missed since we were last connected to this channel
        missed = @persistentLog.getListOfMissedMessages()

        # then pull it, if there was anything
        if missed?.length
          socket.emit "chat:history_request:#{@channelName}", requestRange: missed

      topic: (msg) =>
        return if msg.body is null

        # attempt to parse the msg.body as a JSON object
        try # if it succeeds, it was an encrypted object
          encrypted_topic = JSON.parse(msg.body)
          if @me.cryptokey
            topic = cryptoWrapper.decryptObject(encrypted_topic, @me.cryptokey)
          else
            topic = encrypted_topic.ct
        catch e
          topic = msg.body

        @chatLog.setTopic topic

      antiforgery_token: (msg) =>
        @me.antiforgery_token = msg.antiforgery_token if msg.antiforgery_token

      file_uploaded: (msg) =>
        fromClient = @channel.clients.findWhere(id: msg.from_user)
        return if typeof !fromClient?

        if @me.is(fromClient)
          nick = "You"
        else
          nick = fromClient.getNick(@me.cryptokey)

        chatMessage = new ChatMessage
          body: "#{nick} uploaded a file: #{msg.path}"
          timestamp: new Date().getTime()
          nickname: ""

        @chatLog.renderChatMessage chatMessage
        @persistentLog.add chatMessage.toJSON()

    _.each @socketEvents, (value, key) =>
      # listen to a subset of event
      socket.on "#{key}:#{@channelName}", value


  attachEvents: ->
    window.events.on "private:#{@channelName}", @channelIsPrivate

    window.events.on "chat:broadcast", (data) =>
      @me.speak
        body: data.body
        room: @channelName
      , @socket

    window.events.on "channelPassword:#{@channelName}", (data) =>
      @authenticate data.password

    window.events.on "unidle", =>
      if @$el.is(":visible") and @me?
        @me.active @channelName, @socket

        clearTimeout @idleTimer
        @startIdleTimer()

    window.events.on "beginEdit:#{@channelName}", (data) =>
      mID = data.mID
      msg = @persistentLog.getMessage(mID) # get the raw message data from our log, if possible
      unless msg # if we didn't have it in our log (e.g., recently cleared storage), then get it from the DOM
        msgText = $(".chatMessage.mine[data-sequence='" + mID + "'] .body", @$el).text()
      else
        msgText = msg.body

      $(".chatinput textarea", @$el).val("/edit ##{mID} #{msg.body}").focus()

    # finalize the edit
    window.events.on "edit:commit:#{@channelName}", (data) =>
      @socket.emit "chat:edit:#{@channelName}",
        mID: data.mID
        body: data.newText

    # let the chat server know our call status so we can advertise that to other users
    window.events.on "in_call:#{@channelName}", (data) =>
      @socket.emit "in_call:#{@channelName}"

    window.events.on "left_call:#{@channelName}", (data) =>
      @socket.emit "left_call:#{@channelName}"


  handleChatInputKeydown: (ev) ->
    return  if ev.ctrlKey or ev.shiftKey # we don't fire any events when these keys are pressed
    $this = $(ev.target)
    switch ev.keyCode

      # enter:
      when 13
        ev.preventDefault()
        userInput = $this.val()
        @scrollback.add userInput
        if userInput.match(REGEXES.commands.join) # /join [channel_name]
          channelName = userInput.replace(REGEXES.commands.join, "").trim()
          window.events.trigger "joinChannel", channelName
        else
          @me.speak
            body: userInput
            room: @channelName
          , @socket
        $this.val ""
        @scrollback.reset()

      # up:
      when 38
        $this.val @scrollback.prev()

      # down
      when 40
        $this.val @scrollback.next()

      # escape
      when 27
        @scrollback.reset()
        $this.val ""

      # tab key
      when 9
        ev.preventDefault()
        flattext = $this.val()

        # don't continue to append auto-complete results on the end
        return  if flattext.length >= 1 and flattext[flattext.length - 1] is " "
        text = flattext.split(" ")
        stub = text[text.length - 1]
        completion = @autocomplete.next(stub)
        text[text.length - 1] = completion  if completion isnt ""
        text[0] = text[0]  if text.length is 1
        $this.val text.join(" ")

  activelySyncLogs: (ev) ->
    missed = @persistentLog.getMissingIDs(25)
    if missed and missed.length
      @scrollSyncLocked = true # lock it until we receive the batch of logs
      @socket.emit "chat:history_request:" + @channelName,
        requestRange: missed


  reply: (ev) ->
    ev.preventDefault()
    $this = $(ev.currentTarget)
    mID = $this.parents(".chatMessage").data("sequence")
    $textarea = $(".chatinput textarea", @$el)
    curVal = undefined
    curVal = $textarea.val()
    if curVal.length
      $textarea.val curVal + " >>" + mID
    else
      $textarea.val ">>" + mID
    $textarea.focus()

  deleteLocalStorage: (ev) ->
    @persistentLog.destroy()
    @chatLog.clearChat() # visually reinforce to the user that it deleted them by clearing the chatlog
    @chatLog.clearMedia() # "

  logOut: (ev) ->

    # clears all sensitive information:
    $.cookie "nickname:" + @channelName, null
    $.cookie "ident_pw:" + @channelName, null
    $.cookie "channel_pw:" + @channelName, null
    @clearCryptoKey() # delete their stored key
    @deleteLocalStorage()
    window.events.trigger "leaveChannel", @channelName

    # visually re-inforce the destruction:
    growl = new Mewl(
      title: @channelName + ":"
      body: "All local data erased."
      lifespan: 7000
    )

  clearChatlog: ->
    @chatLog.clearChat()

  startIdleTimer: ->
    @idleTimer = setTimeout(=>
      @me.inactive "", @channelName, @socket if @me?
    , 1000 * 30)

  rerenderInputBox: ->
    $(".chatinput", @$el).remove() # remove old
    # re-render the chat input area now that we've encrypted:
    @$el.append @inputTemplate(encrypted: (typeof @me.cryptokey isnt "undefined"))

  showCryptoModal: ->
    modal = new CryptoModal(channelName: @channelName)
    modal.on "setKey", (data) =>
      if data.key isnt ""
        @me.cryptokey = data.key
        window.localStorage.setItem "chat:cryptokey:#{@channelName}", data.key

      @rerenderInputBox()
      $(".chatinput textarea", @$el).focus()
      @me.setNick @me.get("nick"), @channelName

  clearCryptoKey: ->
    delete @me.cryptokey

    @rerenderInputBox()
    window.localStorage.setItem "chat:cryptokey:" + @channelName, ""
    @me.unset "encrypted_nick"
    @me.setNick "Anonymous", @channelName

