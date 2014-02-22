_               = require("underscore") if !_
Backbone        = require("backbone") if !Backbone
PermissionModel = require("./PermissionModel.coffee").PermissionModel
REGEXES         = require("./regex.js.coffee").REGEXES
CryptoWrapper   = require("./CryptoWrapper.coffee").CryptoWrapper
cryptoWrapper   = new CryptoWrapper

module.exports.ColorModel = class ColorModel extends Backbone.Model
  defaults:
    r: 0
    g: 0
    b: 0

  initialize: (opts) ->
    if opts
      @set "r", opts.r
      @set "g", opts.g
      @set "b", opts.b
    else
      r = parseInt(Math.random() * 200 + 55, 10) # push the baseline away from black
      g = parseInt(Math.random() * 200 + 55, 10)
      b = parseInt(Math.random() * 200 + 55, 10)
      threshold = 50
      color = 35

      #Calculate the manhattan distance to the colors
      #If the colors are within the threshold, invert them
      if Math.abs(r - color) + Math.abs(g - color) + Math.abs(b - color) <= threshold
        r = 255 - r
        g = 255 - g
        b = 255 - b
      @set "r", r
      @set "g", g
      @set "b", b

  parse: (userString, callback) ->
    if userString.match(REGEXES.colors.hex)
      @setFromHex userString
      callback? null
    else
      callback? new Error("Invalid colour; you must supply a valid CSS hex color code (e.g., '#efefef', '#fff')")

  setFromHex: (hexString) ->

    # trim any leading "#"
    # strip any leading # symbols
    hexString = hexString.substring(1)  if hexString.charAt(0) is "#"
    # e.g. fff -> ffffff
    hexString += hexString  if hexString.length is 3
    r = parseInt(hexString.substring(0, 2), 16)
    g = parseInt(hexString.substring(2, 4), 16)
    b = parseInt(hexString.substring(4, 6), 16)
    @set
      r: r
      g: g
      b: b

  toRGB: ->
    "rgb(#{@attributes.r}, #{@attributes.g}, #{@attributes.b})"

module.exports.ClientsCollection = class ClientsCollection extends Backbone.Collection
  model: exports.ClientModel

module.exports.ClientModel = class ClientModel extends Backbone.Model
  supported_metadata: ["email", "website_url", "country_code", "gender"]
  defaults:
    nick: "Anonymous"
    identified: false
    idle: false
    isServer: false
    authenticated: false
    email: null
    country_code: null
    gender: null
    website_url: null

  toJSON: ->
    json = Backbone.Model::toJSON.apply(this, arguments)
    json.cid = @cid
    json

  initialize: (opts) ->
    _.bindAll this
    if opts and opts.color
      @set "color", new exports.ColorModel(opts.color)
    else
      @set "color", new exports.ColorModel()
    @socket = opts.socket  if opts and opts.socket
    @set "permissions", new PermissionModel()

  authenticate_via_password: (pw, ack) ->
    room = @get('room')
    @socket.emit "join_private:#{room}",
      password: pw
    , (err) ->
      ack.rejectWith(this, [err]) if ack and err
      ack.resolve() if ack

  authenticate_via_token: (token, ack) ->
    room = @get('room')
    @socket.emit "join_private:#{room}",
      token: token
    , (err) ->
      ack.rejectWith(this, [err]) if ack and err
      ack.resolve() if ack

  inactive: (reason, room, socket) ->
    reason = reason or "User idle."
    socket.emit "chat:idle:#{room}",
      reason: reason

    @set "idle", true

  active: (room, socket) ->
    if @get("idle") # only send over wire if we're inactive
      socket.emit "chat:unidle:#{room}"
      @set "idle", false

  getNick: (cryptoKey) ->
    nick = @get("nick")
    encrypted_nick = @get("encrypted_nick")
    if typeof encrypted_nick isnt "undefined"
      if (typeof cryptoKey isnt "undefined") and (cryptoKey isnt "")
        nick = cryptoWrapper.decryptObject(encrypted_nick, cryptoKey)
      else
        nick = encrypted_nick.ct
    nick

  getNickOf: (other) ->
    other.getNick(@cryptokey)

  setNick: (nick, room, ack) ->
    $.cookie "nickname:#{room}", nick, window.COOKIE_OPTIONS
    if @cryptokey
      @set "encrypted_nick", cryptoWrapper.encryptObject(nick, @cryptokey),
        silent: true

      nick = "-"

    @socket.emit "nickname:#{room}",
      nick: nick
      encrypted_nick: @get("encrypted_nick")
    , ->
      ack.resolve() if ack

  identify_via_token: (token, ack) ->
    room = @get('room')
    @socket.emit "verify_identity_token:#{room}",
      token: token
    , ->
      ack.resolve() if ack

  identify: (pw, ack) ->
    room = @get('room')
    @socket.emit "identify:#{room}",
      password: pw
    , ->
      ack.resolve() if ack

  is: (otherModel) ->
    @attributes.id is otherModel.attributes.id

  sendPrivateMessage: (toUsername, body) ->
    room = @get('room')
    @socket.emit "private_message:#{room}",
      body: body
      directedAt: toUsername

  sendEdit: (mID, newBody) ->
    room = @get('room')
    data =
      body: newBody
      mID: mID

    if @cryptokey
      data.encrypted = cryptoWrapper.encryptObject(newBody, @cryptokey)
      data.body = "-"

    @socket.emit "chat:edit:#{room}", data

  sendEncryptedPrivateMessage: (toUsername, body) ->
    room  = @get('room')
    peers = @get('peers')
    # decrypt the list of our peers (we don't have their unencrypted stored in plaintext anywhere)
    peerNicks = _.map peers.models, (peer) =>
      peer.getNick @cryptokey

    ciphernicks = [] # we could potentially be targeting multiple people with the same nick in our whisper

    # check this decrypted list for the target nick
    i = 0
    while i < peerNicks.length
      # if it matches, we'll keep track of their ciphernick to send to the server
      ciphernicks.push peers.at(i).get("encrypted_nick")["ct"]  if peerNicks[i] is toUsername
      i++

    # if anyone was actually a recipient, we'll encrypt the message and send it
    if ciphernicks.length
      encrypted = cryptoWrapper.encryptObject(body, @cryptokey) # encrypt the body text
      body = "-" # clean it immediately after encrypting it
      @socket.emit "private_message:#{room}",
        encrypted: encrypted
        ciphernicks: ciphernicks
        body: body

    # else we just do nothing.

  speak: (msg) ->
    self   = this
    socket = @socket
    body   = msg.body
    room   = @get("room")

    matches = undefined
    window.events.trigger "speak", socket, this, msg
    return  unless body # if there's no body, we probably don't want to do anything
    if body.match(REGEXES.commands.nick) # /nick [nickname]
      body = body.replace(REGEXES.commands.nick, "").trim()
      @setNick body, room
      $.cookie "nickname:#{room}", body, window.COOKIE_OPTIONS
      $.removeCookie "ident_pw:#{room}", window.COOKIE_OPTIONS # clear out the old saved nick
    else if body.match(REGEXES.commands.private) # /private [password]
      body = body.replace(REGEXES.commands.private, "").trim()
      socket.emit "make_private:#{room}",
        password: body
    else if body.match(REGEXES.commands.public) # /public
      body = body.replace(REGEXES.commands.public, "").trim()
      socket.emit "make_public:#{room}"

    else if body.match(REGEXES.commands.register) # /register [password]
      body = body.replace(REGEXES.commands.register, "").trim()
      socket.emit "register_nick:#{room}",
        password: body
    else if body.match(REGEXES.commands.identify) # /identify [password]
      body = body.replace(REGEXES.commands.identify, "").trim()
      @identify body
    else if body.match(REGEXES.commands.topic) # /topic [My channel topic]
      body = body.replace(REGEXES.commands.topic, "").trim()
      if @cryptokey
        encrypted_topic = cryptoWrapper.encryptObject(body, @cryptokey)
        body = "-"
        socket.emit "topic:#{room}",
          encrypted_topic: encrypted_topic

      else
        socket.emit "topic:#{room}",
          topic: body

    else if body.match(REGEXES.commands.private_message) # /tell [nick] [message]
      body = body.replace(REGEXES.commands.private_message, "").trim()
      targetNick = body.split(" ") # take the first token to mean the
      if targetNick.length # only do something if they've specified a target
        targetNick = targetNick[0]
        targetNick = targetNick.substring(1)  if targetNick.charAt(0) is "@" # remove the leading "@" symbol while we match against it; TODO: validate username characters not to include special symbols

        if @cryptokey
          @sendEncryptedPrivateMessage(targetNick, body)
        else
          @sendPrivateMessage(targetNick, body)

    else if body.match(REGEXES.commands.pull_logs) # pull
      body = body.replace(REGEXES.commands.pull_logs, "").trim()
      if body is "ALL"
        console.warn "/pull all -- Not implemented yet"
      else
        nLogs = Math.max(1, parseInt(body, 10))
        nLogs = Math.min(100, nLogs) # 1 <= N <= 100

        window.events.one "gotMissingIDs:#{@options.namespace}", (missed) =>
          if missed.length
            @socket.emit "chat:history_request:#{room}",
              requestRange: missed

        window.events.trigger "getMissingIDs:#{room}", nLogs

    else if body.match(REGEXES.commands.set_color) # /color
      body = body.replace(REGEXES.commands.set_color, "").trim()
      socket.emit "user:set_color:#{room}",
        userColorString: body

    else if matches = body.match(REGEXES.commands.edit) # editing
      mID = matches[2]
      body = body.replace(REGEXES.commands.edit, "").trim()

      @sendEdit(mID, body)
    else if body.match(REGEXES.commands.leave) # leaving
      window.events.trigger "leave:#{room}"
    else if body.match(REGEXES.commands.chown) # become owner
      body = body.replace(REGEXES.commands.chown, "").trim()
      socket.emit "chown:#{room}",
        key: body

    else if body.match(REGEXES.commands.chmod) # change permissions
      body = body.replace(REGEXES.commands.chmod, "").trim()
      socket.emit "chmod:#{room}",
        body: body

    else if body.match(REGEXES.commands.broadcast) # broadcast to speak to all open channels at once
      body = body.replace(REGEXES.commands.broadcast, "").trim()
      window.events.trigger "chat:broadcast",
        body: body

    else if body.match(REGEXES.commands.help)
      socket.emit "help:#{room}"
    else if body.match(REGEXES.commands.roll)
      body = body.replace(REGEXES.commands.roll, "").trim()
      socket.emit "roll:#{room}",
        dice: body
    else if body.match(REGEXES.commands.destroy)
      socket.emit "destroy_logs:#{room}"
    else if body.match(REGEXES.commands.github)
      body = body.replace(REGEXES.commands.github, "").trim()
      split = body.split(" ")
      subcommand = split.shift()
      args = split.join(" ")

      if subcommand.match(REGEXES.github_subcommands.track) and args.match(REGEXES.urls.all_others)
        socket.emit "add_github_webhook:#{room}",
          repoUrl: args

    else unless body.match(REGEXES.commands.failed_command) # match all
      # NOOP
      # send it out to the world!
      if @cryptokey
        msg.encrypted = cryptoWrapper.encryptObject(msg.body, @cryptokey)
        msg.body = "-"
      socket.emit "chat:#{room}", msg
