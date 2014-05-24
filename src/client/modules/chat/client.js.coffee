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
PGPSettings             = require("./pgp_settings.js.coffee").PGPSettings
PGPModal                = require("./pgp_modal.js.coffee").PGPModal
ChatMessage             = require("./ChatMessageModel.js.coffee").ChatMessage

faviconizer = new Faviconizer

module.exports.CryptoModal = class CryptoModal extends Backbone.View
  className: "backdrop"
  template: cryptoModalTemplate
  events:
    "keydown input.crypto-key": "checkToSetKey"
    "click .set-encryption-key": "setCryptoKey"
    "click .cancel": "remove"
    "click .close-button": "remove"

  initialize: (opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
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
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    @hidden = true
    @config = opts.config
    @module = opts.module
    @socket = io.connect(@config.host + "/chat")
    @channel = opts.channel
    @channelName = opts.room
    @channel.get("clients").model = ClientModel
    @autocomplete = new Autocomplete()
    @scrollback = new Scrollback()
    @persistentLog = new Log(namespace: @channelName)

    @pgp_settings = new PGPSettings
      channelName: @channelName

    @me = new ClientModel
      socket: @socket
      room: opts.room
      peers: @channel.get("clients")
      pgp_settings: @pgp_settings

    @chatLog = new ChatAreaView
      button: @channel.get("button")
      room: @channelName
      persistentLog: @persistentLog
      me: @me

    if cryptokey = @channel.get("cryptokey")
      @me.set 'cryptokey', cryptokey

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

      for entry in entries
        msg = @chatLog.createChatMessage(entry)
        msg.set "from_log", true
        entry = @chatLog.renderChatMessage msg

    # triggered by ChannelSwitcher:
    @on "show", @show
    @on "hide", @hide
    @channel.get("clients").on "change:nick", (model, changedAttributes) =>
      prevName = undefined
      currentName = model.getNick()
      if @me.is(model)
        prevName = "You are"
      else
        prevClient = new ClientModel(model.previousAttributes())
        prevName = prevClient.getNick()
        prevName += " is"
      @chatLog.renderChatMessage @chatLog.createChatMessage({
        body: prevName + " now known as " + currentName
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "identity ack"
      })

    @channel.get("clients").on "add", (model) =>
      @chatLog.renderChatMessage @chatLog.createChatMessage({
        body: model.getNick() + " has joined the room."
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "join"
      })

    @channel.get("clients").on "remove", (model) =>
      @chatLog.renderChatMessage @chatLog.createChatMessage({
        body: model.getNick() + " has left the room."
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "part"
      })

    @channel.get("clients").on "add remove reset change", (model) =>
      clients = @channel.get("clients")

      @chatLog.renderUserlist clients
      @autocomplete.setPool _.map(clients.models, (user) =>
        @me.getNickOf(user)
      )
      @me.set("peers", clients)

      # update keystore
      _.map clients.models, (user) =>
        if armored_public_key = user.get("armored_public_key")
          KEYSTORE.add(user.getPGPFingerprint(), armored_public_key, null, @me.getNickOf(user), @channelName)

    # add my own key to keystore
    @me.pgp_settings.on "change:armored_keypair", (model, armored_keypair) =>
      if armored_keypair
        @me.set("armored_public_key", armored_keypair.public)
        my_fingerprint = @me.getPGPFingerprint()
        KEYSTORE.add(my_fingerprint, armored_keypair.public, armored_keypair.private, @me.getNick(), @channelName)
        KEYSTORE.trust(my_fingerprint)

      @socket.emit "set_public_key:#{@channelName}",
        armored_public_key: armored_keypair?.public

    # doesn't work when defined as a backbone event :(
    @scrollSyncLogs = _.throttle(@_scrollSyncLogs, 500) # so we don't sync too quickly
    $(".messages", @$el).on "mousewheel DOMMouseScroll", @scrollSyncLogs

  events:
    "click button.deleteLocalStorage": "deleteLocalStorage"
    "click button.deleteLocalStorageAndQuit": "logOut"
    "click .reply-button": "reply"
    "keydown .chatinput textarea": "handleChatInputKeydown"
    "click button.not-encrypted": "showCryptoModal"
    "click button.pgp-settings": "showPGPModal"
    "click button.encrypted": "clearCryptoKey"
    "dragover .linklog": "showDragUIHelper"
    "dragleave .drag-mask": "hideDragUIHelper"
    "drop .drag-mask": "dropObject"
    "click .cancel-upload": "clearUploadStaging"
    "click .upload": "uploadFile"
    "click .un-keyblock": "unlockKeypair"

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
    @detachEvents()
    @socket.emit "unsubscribe:" + @channelName
    _.each @socketEvents, (method, key) =>
      @socket.removeAllListeners "#{key}:#{@channelName}"

  postSubscribe: (data) ->
    if pub = @pgp_settings.get("armored_keypair")?.public
      @socket.emit "set_public_key:#{@channelName}",
        armored_public_key: pub

    # attempt to automatically /nick and /ident
    @autoNick()

    # start the countdown for idle
    @startIdleTimer()
    window.disconnected = false
    faviconizer.setConnected()

  autoNick: ->
    acked = $.Deferred()
    storedNick = $.cookie("nickname:" + @channelName) || "Anonymous"
    @me.setNick storedNick, @channelName, acked
    acked.promise()

  authenticate: (data) ->
    acked = $.Deferred()
    password = data.password
    token = data.token

    if password
      @me.authenticate_via_password password, acked
    else if token
      @me.authenticate_via_token token, acked
    else
      acked.reject()

    $.when(acked).done =>
      @channel.authenticated = true
      window.events.trigger "hidePrivateOverlay"

    $.when(acked).fail (err) =>
      if !@hidden and err
        window.events.trigger "showPrivateOverlay"
        growl = new Mewl(
          title: @channelName + ": Error"
          body: err
        )

    acked.promise()

  autoAuth: ->
    storedAuth = $.cookie("token:authentication:#{@channelName}")
    return @authenticate(token: storedAuth)

  render: ->
    @$el.html @template()
    $(".chat-panel", @$el).html @chatLog.$el
    @$el.attr "data-channel", @channelName
    @rerenderInputBox()

  channelIsPrivate: =>
    @channel.isPrivate = true
    window.events.trigger "showPrivateOverlay" if !@hidden

    @autoAuth()

  decryptTopic: ->
    return if !@raw_topic # if it has never been set

    # attempt to parse the msg.body as a JSON object
    try # if it succeeds, it was an encrypted object
      encrypted_topic = JSON.parse(@raw_topic.body)
      if cryptokey = @me.get('cryptokey')
        try
          topic = cryptoWrapper.decryptObject(encrypted_topic, cryptokey)
        catch e
          topic = encrypted_topic.ct
      else
        topic = encrypted_topic.ct
    catch e
      topic = @raw_topic.body
      # topic was not encrypted

    @chatLog.setTopic topic

  checkToNotify: (msg) ->

    # scan through the message and determine if we need to notify somebody that was mentioned:
    msgBody = msg.get("body")
    myNick = @me.getNick()
    msgClass = msg.get("class")
    fromNick = msg.get("nickname")
    atMyNick = "@" + myNick

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
        message = @chatLog.createChatMessage(msg)

        if fingerprint = message.get("fingerprint")
          KEYSTORE.markSeen(fingerprint, @me.getNick(), @channelName)

        body = message.get("body")
        @scrollback.replace body, "/edit ##{message.get("mID")} #{body}" if message.get("you") # https://github.com/qq99/echoplexus/issues/113 "Local scrollback should be considered an implicit edit operation"
        message = @checkToNotify message
        @persistentLog.add msg
        @chatLog.renderChatMessage message
        return

      "chat:batch": (msgs) =>
        for msg in msgs
          msg = JSON.parse(msg)
          if not @persistentLog.has(msg.mID)
            @persistentLog.add msg
            @chatLog.renderChatMessage @chatLog.createChatMessage(msg)

        if @previousScrollHeight # for syncing while scrolling
          chatlog = @chatLog.$el.find(".messages")[0]
          chatlog.scrollTop = chatlog.scrollHeight - @previousScrollHeight

        @scrollSyncLocked = false # unlock the lock on scrolling to sync logs
        return

      "client:changed": (alteredClient) =>
        prevClient = @channel.get("clients").findWhere(id: alteredClient.id)
        alteredClient.color = new ColorModel(alteredClient.color)  if alteredClient.color
        if prevClient
          prevClient.set alteredClient
          prevClient.unset "encrypted_nick"  if !alteredClient.encrypted_nick
          # backbone won't unset undefined

          # check to see if it's ME that's being updated
          # TODO: this is hacky, but it fixes notification nick checking :s
          if prevClient.get("id") is @me.get("id")
            @me.set alteredClient
            @me.unset "encrypted_nick"  if !alteredClient.encrypted_nick
        # backbone won't unset undefined
        else # there was no previous client by this id
          @channel.get("clients").add alteredClient

        return

      "client:removed": (alteredClient) =>
        prevClient = @channel.get("clients").remove(id: alteredClient.id)
        return

      private_message: (msg) =>
        message = @chatLog.createChatMessage(msg)
        message = @checkToNotify(message)

        @persistentLog.add msg
        @chatLog.renderChatMessage message
        return

      webshot: (msg) =>
        @chatLog.renderWebshot msg
        return

      subscribed: =>
        @postSubscribe()
        return

      "chat:edit": (msg) =>
        message = @chatLog.createChatMessage(msg)
        message = @checkToNotify(message) # the edit might have been to add a "@nickname", so check again to notify
        @persistentLog.replaceMessage msg # replace the message with the edited version in local storage
        @chatLog.replaceChatMessage message # replace the message with the edited version in the chat log
        return

      "client:id": (msg) =>
        @me.set "id", msg.id
        return

      "token": (msg) =>
        $.cookie "token:#{msg.type}:#{@channelName}", msg.token, window.COOKIE_OPTIONS
        return

      userlist: (msg) =>
        @channel.get("clients").reset msg.users # update the pool of possible autocompletes
        return

      "chat:currentID": (msg) =>
        @persistentLog.latestIs msg.mID # store the server's current sequence number

        # find out only what we missed since we were last connected to this channel
        missed = @persistentLog.getListOfMissedMessages()

        # then pull it, if there was anything
        if missed?.length
          socket.emit "chat:history_request:#{@channelName}", requestRange: missed

        return

      topic: (msg) =>
        return if msg.body is null

        @raw_topic = msg
        @decryptTopic()
        return

      antiforgery_token: (msg) =>
        @me.antiforgery_token = msg.antiforgery_token if msg.antiforgery_token
        return

      file_uploaded: (msg) =>
        fromClient = @channel.get("clients").findWhere(id: msg.from_user)
        return if typeof !fromClient

        if @me.is(fromClient)
          nick = "You"
        else
          nick = fromClient.getNick()

        message = @chatLog.createChatMessage({
          body: "#{nick} uploaded a file: #{msg.path}"
          timestamp: new Date().getTime()
          nickname: ""
        })

        @chatLog.renderChatMessage message
        @persistentLog.add msg.toJSON()
        return

    _.each @socketEvents, (value, key) =>
      # listen to a subset of event
      socket.on "#{key}:#{@channelName}", value

  detachEvents: ->
    window.events.off null, null, this
    $(window).off "resize", @chatLog.scrollToLatest
    return

  attachEvents: ->

    $(window).on "resize", @chatLog.scrollToLatest

    window.events.on "private:#{@channelName}", @channelIsPrivate, this

    window.events.on "local_render:#{@channelName}", (data) =>
      _.extend data, {unwrapped: true}
      message = @chatLog.createChatMessage data
      @chatLog.renderChatMessage message
      if (data.store_local_render) # we might store some of these pre-renders locally, when we only get receipts
        @persistentLog.add _.extend(data, {sending: false})
      return

    window.events.on "echo_received:#{@channelName}", (msg, overwrite) =>
      if overwrite
        message = @chatLog.createChatMessage(msg)
        message.set("you", true)

        body = message.get("body")
        @scrollback.replace body, "/edit ##{message.get("mID")} #{body}" # https://github.com/qq99/echoplexus/issues/113 "Local scrollback should be considered an implicit edit operation"

        delete msg.echo_id # don't need to hold onto this
        @persistentLog.add msg
        @chatLog.replaceChatMessage message, true
      else
        @chatLog.markReceipt msg.echo_id
      
      return

    window.events.on "chat:broadcast", (data) ->
      @me.speak
        body: data.body

      return
    , this

    window.events.on "channelPassword:#{@channelName}", (data) ->
      @authenticate(password: data.password)

      return
    , this

    window.events.on "unidle", ->
      if @$el.is(":visible") and @me
        @me.active @channelName, @socket

        clearTimeout @idleTimer
        @startIdleTimer()

      return
    , this

    window.events.on "beginEdit:#{@channelName}", (data) ->
      mID = data.mID
      msgText = $(".chatMessage[data-sequence='" + mID + "'] .body-content", @$el).text()

      $(".chatinput textarea", @$el).val("/edit ##{mID} #{msgText}").focus()

      return
    , this

    # finalize the edit
    window.events.on "edit:commit:#{@channelName}", (data) ->
      @me.enunciate
        mID: data.mID
        body: data.newText
        type: 'edit'

      return
    , this

    # let the chat server know our call status so we can advertise that to other users
    window.events.on "in_call:#{@channelName}", (data) ->
      @socket.emit "in_call:#{@channelName}"

      return
    , this

    window.events.on "left_call:#{@channelName}", (data) ->
      @socket.emit "left_call:#{@channelName}"

      return
    , this


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

     return

  activelySyncLogs: (ev) ->
    missed = @persistentLog.getMissingIDs(25)
    if missed and missed.length
      @scrollSyncLocked = true # lock it until we receive the batch of logs
      @socket.emit "chat:history_request:" + @channelName,
        requestRange: missed

    return

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

    return

  deleteLocalStorage: (ev) ->
    @persistentLog.destroy()
    @chatLog.clearChat() # visually reinforce to the user that it deleted them by clearing the chatlog
    @chatLog.medialog.clearMediaContents() # "
    return

  logOut: (ev) ->

    # clears all sensitive information:
    $.cookie "nickname:#{@channelName}", null
    $.cookie "token:identity:#{@channelName}", null
    $.cookie "token:authentication:#{@channelName}", null
    @clearCryptoKey() # delete their stored key
    @deleteLocalStorage()
    window.events.trigger "leaveChannel", @channelName

    # visually re-inforce the destruction:
    growl = new Mewl(
      title: @channelName + ":"
      body: "All local data erased."
      lifespan: 7000
    )
    return

  startIdleTimer: ->
    @idleTimer = setTimeout(=>
      @me.inactive "", @channelName, @socket if @me
    , 1000 * 30)
    return

  rerenderInputBox: ->
    $(".chatinput", @$el).remove() # remove old
    # re-render the chat input area now that we've encrypted:
    @$el.find(".chatarea-contents").append @inputTemplate(encrypted: !!@me.get('cryptokey'))
    return

  showCryptoModal: ->
    modal = new CryptoModal(channelName: @channelName)
    modal.on "setKey", (data) =>
      if data.key isnt ""
        @channel.set("cryptokey", data.key)
        @me.set("cryptokey", data.key)
        @decryptTopic()
        window.localStorage.setItem "chat:cryptokey:#{@channelName}", data.key

      @rerenderInputBox()
      _.defer ->
        $(".chatinput textarea", @$el).focus()
      @me.setNick @me.get("nick"), @channelName
    return

  showPGPModal: ->
    modal = new PGPModal
      channelName: @channelName
      me: @me
      pgp_settings: @pgp_settings
    return

  clearCryptoKey: ->
    @me.unset 'cryptokey'
    @channel.unset("cryptokey")

    @rerenderInputBox()
    window.localStorage.setItem "chat:cryptokey:" + @channelName, ""
    @me.unset "encrypted_nick"
    @me.setNick "Anonymous", @channelName
    return

  unlockKeypair: ->
    if @me.pgp_settings.enabled()
      @me.pgp_settings.prompt()
    else
      @showPGPModal()
    return