chatpanelTemplate       = require("./templates/chatPanel.html")
chatinputTemplate       = require("./templates/chatInput.html")
fileUploadTemplate      = require("./templates/fileUpload.html")
cryptoModalTemplate     = require("./templates/channelCryptokeyModal.html")
Regex                   = require("../../regex.js.coffee").REGEXES
Faviconizer             = require("../../ui/Faviconizer.js.coffee").Faviconizer
Autocomplete            = require("./Autocomplete.js.coffee").Autocomplete
Scrollback              = require("./Scrollback.js.coffee").Scrollback
Log                     = require("./Log.js.coffee")
ChatLog                 = require("./ChatLog.js.coffee")
Mewl                    = require("../../ui/Mewl.js.coffee")
Client                  = require('../../client.js.coffee')
ColorModel              = Client.ColorModel
ClientModel             = Client.ClientModel
ClientsCollection       = Client.ClientsCollection

module.exports.CryptoModal = class CryptoModal extends Backbone.View
  className: "backdrop"
  template: _.template(cryptoModalTemplate)
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
      body = crypto.decryptObject(encrypted_body, cryptoKey)  if (typeof cryptoKey isnt "undefined") and (cryptoKey isnt "") and (typeof encrypted_body isnt "undefined")
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
    self = this
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

    @me = new ClientModel(socket: @socket)
    @me.peers = @channel.clients # let the client have access to all the users in the channel

    @chatLog = new ChatLog
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
        model = new @chatMessage(entries[i])
        entry = @chatLog.renderChatMessage(model,
          delayInsert: true
        )
        renderedEntries.push entry
        i++
      @chatLog.insertBatch renderedEntries

    # triggered by ChannelSwitcher:
    @on "show", @show
    @on "hide", @hide
    @channel.clients.on "change:nick", (model, changedAttributes) ->
      prevName = undefined
      currentName = model.getNick(self.me.cryptokey)
      if self.me.is(model)
        prevName = "You are"
      else
        prevClient = new ClientModel(model.previousAttributes())
        prevName = prevClient.getNick(self.me.cryptokey)
        prevName += " is"
      self.chatLog.renderChatMessage new self.chatMessage(
        body: prevName + " now known as " + currentName
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "identity ack"
      )

    @channel.clients.on "add", (model) ->
      self.chatLog.renderChatMessage new self.chatMessage(
        body: model.getNick(self.me.cryptokey) + " has joined the room."
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "join"
      )

    @channel.clients.on "remove", (model) ->
      self.chatLog.renderChatMessage new self.chatMessage(
        body: model.getNick(self.me.cryptokey) + " has left the room."
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "part"
      )

    @channel.clients.on "add remove reset change", (model) ->
      self.chatLog.renderUserlist self.channel.clients
      self.autocomplete.setPool _.map(self.channel.clients.models, (user) ->
        user.getNick self.me.cryptokey
      )


    # doesn't work when defined as a backbone event :(
    @scrollSyncLogs = _.throttle(@_scrollSyncLogs, 500) # so we don't sync too quickly
    $(".messages", @$el).on "mousewheel DOMMouseScroll", @scrollSyncLogs

  events:
    "click button.syncLogs": "activelySyncLogs"
    "click button.deleteLocalStorage": "deleteLocalStorage"
    "click button.deleteLocalStorageAndQuit": "logOut"
    "click button.clearChatlog": "clearChatlog"
    "click .icon-reply": "reply"
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
    self = this
    @noop ev
    console.log ev.originalEvent.dataTransfer # will report .files.length => 0 (it's just a console bug though!)
    console.log ev.originalEvent.dataTransfer.files[0] # it actually exists :o
    file = ev.originalEvent.dataTransfer.files[0]
    if typeof file is "undefined" or file is null
      @clearUploadStaging()
      return
    @file = file
    reader = new FileReader()
    reader.addEventListener "loadend", ((e) ->
      data =
        fileName: self.file.name
        fileSize: readablizeBytes(self.file.size)
        img: null

      # show img preview
      data.img = e.target.result  if e.target.result.match(/^data:image/)
      $(".staging-area", @$el).html self.fileUploadTemplate(data)
    ), false
    reader.readAsDataURL file
    $(".drag-mask", @$el).hide()

  clearUploadStaging: ->
    $(".drag-staging, .drag-mask", @$el).hide()
    $(".staging-area", @$el).html ""
    delete @file

  uploadFile: ->
    self = this
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
    $("textarea", self.$el).focus()
    @hidden = false

  hide: ->
    @$el.hide()
    @hidden = true

  bindReconnections: ->
    self = this

    #Bind the disconnnections, send message on disconnect
    self.socket.on "disconnect", ->
      self.chatLog.renderChatMessage new self.chatMessage(
        body: "Disconnected from the server"
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "client"
      )
      window.disconnected = true
      faviconizer.setDisconnected()


    #On reconnection attempts, print out the retries
    self.socket.on "reconnecting", (nextRetry) ->
      self.chatLog.renderChatMessage new self.chatMessage(
        body: "Connection lost, retrying in " + nextRetry / 1000.0 + " seconds"
        type: "SYSTEM"
        timestamp: new Date().getTime()
        nickname: ""
        class: "client"
      )


    #On successful reconnection, render the chatmessage, and emit a subscribe event
    self.socket.on "reconnect", ->

      #Resend the subscribe event
      self.socket.emit "subscribe",
        room: self.channelName
        reconnect: true
      , -> # server acks and we:
        # if we were idle on reconnect, report idle immediately after ack
        self.me.inactive "", self.channelName, self.socket  if self.me.get("idle")
        self.postSubscribe()



  kill: ->
    self = this
    @socket.emit "unsubscribe:" + @channelName
    _.each @socketEvents, (method, key) ->
      self.socket.removeAllListeners key + ":" + self.channelName


  postSubscribe: (data) ->
    self = this
    @chatLog.renderChatMessage new self.chatMessage(
      body: "Connected. Now talking in channel " + @channelName
      type: "SYSTEM"
      timestamp: new Date().getTime()
      nickname: ""
      class: "client"
    )

    # attempt to automatically /nick and /ident
    $.when(@autoNick()).done ->
      self.autoIdent()


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

  autoAuth: ->

    # we only care about the success of this event, but the server already responds
    # explicitly with a success event if it is so
    storedAuth = $.cookie("channel_pw:" + @channelName)
    @me.channelAuth storedAuth, @channelName  if storedAuth

  render: ->
    @$el.html @template()
    $(".chatarea", @$el).html @chatLog.$el
    @$el.attr "data-channel", @channelName
    @$el.append @inputTemplate(encrypted: (typeof @me.cryptokey isnt "undefined" and @me.cryptokey isnt null))

  checkToNotify: (msg) ->

    # scan through the message and determine if we need to notify somebody that was mentioned:
    msgBody = msg.getBody(@me.cryptokey)
    myNick = @me.getNick(@me.cryptokey)
    msgClass = msg.get("class")
    fromNick = msg.get("nickname")
    atMyNick = "@" + myNick
    encrypted_nick = msg.get("encrypted_nick")
    fromNick = crypto.decryptObject(encrypted_nick, @me.cryptokey)  if encrypted_nick

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
      if OPTIONS.show_mewl and (@hidden or not chatModeActive())
        growl = new Mewl(
          title: @channelName + ":  " + fromNick
          body: msgBody
        )
    msg

  listen: ->
    self = this
    socket = @socket
    @socketEvents =
      chat: (msg) ->
        window.events.trigger "message", socket, self, msg
        message = new self.chatMessage(msg)

        # update our scrollback buffer so that we can quickly edit the message by pressing up/down
        # https://github.com/qq99/echoplexus/issues/113 "Local scrollback should be considered an implicit edit operation"
        self.scrollback.replace message.getBody(self.me.cryptokey), "/edit #" + message.get("mID") + " " + message.getBody(self.me.cryptokey)  if message.get("you") is true
        self.checkToNotify message
        self.persistentLog.add message.toJSON()
        self.chatLog.renderChatMessage message

      "chat:batch": (msgs) ->
        msg = undefined
        i = 0
        l = msgs.length

        while i < l
          msg = JSON.parse(msgs[i])
          self.persistentLog.add msg
          msg.fromBatch = true
          self.chatLog.renderChatMessage new self.chatMessage(msg)
          if self.previousScrollHeight
            setTimeout (->
              chatlog = self.chatLog.$el.find(".messages")[0]
              chatlog.scrollTop = chatlog.scrollHeight - self.previousScrollHeight
            ), 0
          i++
        self.scrollSyncLocked = false # unlock the lock on scrolling to sync logs

      "client:changed": (alteredClient) ->
        prevClient = self.channel.clients.findWhere(id: alteredClient.id)
        alteredClient.color = new ColorModel(alteredClient.color)  if alteredClient.color
        if prevClient
          prevClient.set alteredClient
          prevClient.unset "encrypted_nick"  if typeof alteredClient.encrypted_nick is "undefined"
          # backbone won't unset undefined

          # check to see if it's ME that's being updated
          # TODO: this is hacky, but it fixes notification nick checking :s
          if prevClient.get("id") is self.me.get("id")
            self.me.set alteredClient
            self.me.unset "encrypted_nick"  if typeof alteredClient.encrypted_nick is "undefined"
        # backbone won't unset undefined
        else # there was no previous client by this id
          self.channel.clients.add alteredClient

      "client:removed": (alteredClient) ->
        console.log "client left", alteredClient
        prevClient = self.channel.clients.remove(id: alteredClient.id)

      private_message: (msg) ->
        message = new self.chatMessage(msg)
        msg = self.checkToNotify(message)
        self.persistentLog.add message.toJSON()
        self.chatLog.renderChatMessage message

      private: ->
        self.channel.isPrivate = true
        self.autoAuth()

      webshot: (msg) ->
        self.chatLog.renderWebshot msg

      subscribed: ->
        self.postSubscribe()

      "chat:edit": (msg) ->
        message = new self.chatMessage(msg)
        msg = self.checkToNotify(message) # the edit might have been to add a "@nickname", so check again to notify
        self.persistentLog.replaceMessage message.toJSON() # replace the message with the edited version in local storage
        self.chatLog.replaceChatMessage message # replace the message with the edited version in the chat log

      "client:id": (msg) ->
        self.me.set "id", msg.id

      userlist: (msg) ->

        # update the pool of possible autocompletes
        self.channel.clients.reset msg.users

      "chat:currentID": (msg) ->
        missed = undefined
        self.persistentLog.latestIs msg.mID # store the server's current sequence number

        # find out only what we missed since we were last connected to this channel
        missed = self.persistentLog.getListOfMissedMessages()

        # then pull it, if there was anything
        if missed and missed.length
          socket.emit "chat:history_request:" + self.channelName,
            requestRange: missed


      topic: (msg) ->
        topic = undefined
        return  if msg.body is null

        # attempt to parse the msg.body as a JSON object
        try # if it succeeds, it was an encrypted object
          encrypted_topic = JSON.parse(msg.body)
          if self.me.cryptokey
            topic = crypto.decryptObject(encrypted_topic, self.me.cryptokey)
          else
            topic = encrypted_topic.ct
        catch e

          # console.log(e);
          topic = msg.body
        self.chatLog.setTopic topic

      antiforgery_token: (msg) ->
        self.me.antiforgery_token = msg.antiforgery_token  if msg.antiforgery_token

      file_uploaded: (msg) ->
        fromClient = self.channel.clients.findWhere(id: msg.from_user)
        return  if typeof fromClient is "undefined" or fromClient is null
        nick = undefined
        if self.me.is(fromClient)
          nick = "You"
        else
          nick = fromClient.getNick(self.me.cryptokey)
        chatMessage = new self.chatMessage(
          body: nick + " uploaded a file: " + msg.path
          timestamp: new Date().getTime()
          nickname: ""
        )
        self.chatLog.renderChatMessage chatMessage
        self.persistentLog.add chatMessage.toJSON()

    _.each @socketEvents, (value, key) ->

      # listen to a subset of event
      socket.on key + ":" + self.channelName, value


  attachEvents: ->
    self = this
    window.events.on "chat:broadcast", (data) ->
      self.me.speak
        body: data.body
        room: self.channelName
      , self.socket

    window.events.on "unidle", ->
      if self.$el.is(":visible")
        if self.me
          self.me.active self.channelName, self.socket
          clearTimeout self.idleTimer
          self.startIdleTimer()

    window.events.on "beginEdit:" + @channelName, (data) ->
      mID = data.mID
      msgText = undefined
      msg = self.persistentLog.getMessage(mID) # get the raw message data from our log, if possible
      unless msg # if we didn't have it in our log (e.g., recently cleared storage), then get it from the DOM
        msgText = $(".chatMessage.mine[data-sequence='" + mID + "'] .body").text()
      else
        msgText = msg.body
      $(".chatinput textarea", @$el).val("/edit #" + mID + " " + msg.body).focus()

    window.events.on "edit:commit:" + @channelName, (data) ->
      self.socket.emit "chat:edit:" + self.channelName,
        mID: data.mID
        body: data.newText



    # let the chat server know our call status so we can advertise that to other users
    window.events.on "in_call:" + @channelName, (data) ->
      self.socket.emit "in_call:" + self.channelName

    window.events.on "left_call:" + @channelName, (data) ->
      self.socket.emit "left_call:" + self.channelName


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
    self = this
    @idleTimer = setTimeout(->
      self.me.inactive "", self.channelName, self.socket  if self.me
    , 1000 * 30)

  rerenderInputBox: ->
    $(".chatinput", @$el).remove() # remove old
    # re-render the chat input area now that we've encrypted:
    @$el.append @inputTemplate(encrypted: (typeof @me.cryptokey isnt "undefined"))

  showCryptoModal: ->
    self = this
    modal = new @cryptoModal(channelName: @channelName)
    modal.on "setKey", (data) ->
      if data.key isnt ""
        self.me.cryptokey = data.key
        window.localStorage.setItem "chat:cryptokey:" + self.channelName, data.key
      self.rerenderInputBox()
      $(".chatinput textarea", self.$el).focus()
      self.me.setNick self.me.get("nick"), self.channelName


  clearCryptoKey: ->
    delete @me.cryptokey

    @rerenderInputBox()
    window.localStorage.setItem "chat:cryptokey:" + @channelName, ""
    @me.unset "encrypted_nick"
    @me.setNick "Anonymous", @channelName

