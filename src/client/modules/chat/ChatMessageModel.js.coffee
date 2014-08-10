CryptoWrapper               = require("../../CryptoWrapper.coffee").CryptoWrapper
cryptoWrapper               = new CryptoWrapper
HTMLSanitizer               = require("../../utility.js.coffee").HTMLSanitizer
REGEXES                     = require("../../regex.js.coffee").REGEXES
ColorModel                  = require('../../client.js.coffee').ColorModel

module.exports.ChatMessage = class ChatMessage extends Backbone.Model
  idAttribute: 'mID'

  defaults:
    'references': []

  initialize: (model, opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    _.extend this, opts

    @decryptSharedSecret()
    @unwrap()

    this.on "change:body", (data) =>
      @format_body()

    @me.on "change:cryptokey", (data) =>
      @decryptSharedSecret()
      @unwrap()

    @format_body()

    @nReferences = 0

    window.events.on "color:query:#{@room}", (mID, ack) =>
      if @get("mID") == mID
        @nReferences += 1
        if color = @get("thread_color")
          ack(color)
        else
          @color = new ColorModel()
          rgb = @color.toRGB()
          @set("thread_color", rgb)
          ack(rgb)

    window.events.on "color:dereference:#{@room}", (mID) =>
      if @get("mID") == mID
        @nReferences -= 1
        if @nReferences == 0
          @set("thread_color", "")

  decryptSharedSecret: () ->
    cryptokey = @me.get("cryptokey")
    return if @get("was_encrypted") # it's already decrypted

    if @get("encrypted_nick")
      try
        nickname = cryptoWrapper.decryptObject(@get("encrypted_nick"), cryptokey)
        if nickname
          @set("nickname", nickname)
          @unset("encrypted_nick")
      catch e
        @set("nickname", @get("encrypted_nick").ct)

    if @get("encrypted")
      try
        body = cryptoWrapper.decryptObject(@get("encrypted"), cryptokey)
        if body
          @set("body", body)
          @unset("encrypted")
          @set("was_encrypted", true)
      catch e
        @set("body", @get("encrypted").ct)

  unwrapSigned: (msg) ->
    return if @get('unwrapped')
    msg = this

    body = msg.get("body")
    msg.set('armored', body) if !msg.get('armored')
    armored = msg.get('armored')

    try
      msg.set "pgp_armored", _.escape(armored).replace(/\n/g, "<br>")
      message      = openpgp.cleartext.readArmored(armored)
      msg.set "body", message.text
      key          = KEYSTORE.get(msg.get("fingerprint"))
      if !key
        msg.set "pgp_verified", "unknown_public_key"
      dearmored    = openpgp.key.readArmored(key.armored_key)
      verification = openpgp.verifyClearSignedMessage(dearmored.keys, message)

      msg.set "body", verification.text

      if verification.signatures?[0].valid
        msg.set "pgp_verified", "signed"
      else
        msg.set "pgp_verified", "signature_failure"

      @set 'unwrapped', true
    catch e
      console.warn "Unable to verify PGP signed message: #{e}"

    msg

  unwrapSignedAndEncrypted: (msg) ->
    return if @get('unwrapped')
    msg = this
    body = msg.get("body")
    msg.set('armored', body) if !msg.get('armored')
    armored = msg.get('armored')

    try
      msg.set "pgp_armored", _.escape(armored).replace(/\n/g, "<br>")
      message       = openpgp.message.readArmored(armored)
      key           = KEYSTORE.get(msg.get("fingerprint"))
      if !key
        msg.set "pgp_verified", "unknown_public_key"
      dearmored_pub = openpgp.key.readArmored(key.armored_key)

      @me.pgp_settings.usablePrivateKey '', (priv) =>
        priv          = priv[0]
        decrypted     = openpgp.decryptAndVerifyMessage(priv, dearmored_pub.keys, message)

        msg.set "body", decrypted.text
        msg.set "hidden_body", false

        if decrypted.signatures?[0].valid
          msg.set "pgp_verified", "signed"
          @set 'unwrapped', true
        else
          msg.set "pgp_verified", "signature_failure"
    catch e
      msg.set "hidden_body", true
      console.warn "Unable to decrypt PGP signed message: #{e}"

    msg

  unwrapEncrypted: () ->
    return if @get('unwrapped')
    msg = this
    body = msg.get("body")

    try
      msg.set "pgp_armored", _.escape(body).replace(/\n/g, "<br>")
      message       = openpgp.message.readArmored(body)
      key           = KEYSTORE.get(msg.get("fingerprint"))
      @me.pgp_settings.usablePrivateKey '', (priv) =>
        priv = priv[0]
        decrypted = openpgp.decryptMessage(priv, message)

        msg.set "body", decrypted
        msg.set "hidden_body", false
        @set 'unwrapped', true
    catch e
      msg.set "hidden_body", true
      console.warn "Unable to decrypt PGP signed message: #{e}"

    msg.set "pgp_verified", "not_signed"

    msg

  unwrap: ->
    return if @get('encrypted')
    signed    = @get("pgp_signed")
    encrypted = @get("pgp_encrypted")

    if signed and !encrypted
      @unwrapSigned()
    else if !signed and encrypted
      @unwrapEncrypted()
    else if signed and encrypted
      @unwrapSignedAndEncrypted()

    if signed || encrypted
      @set "trust_status", KEYSTORE.trust_status(@get("fingerprint"))

  extract_links: ->
    body = @get('body')

    links = body.match(REGEXES.urls.all_others) || []

    for url in links
      window.events.trigger "linklog:#{@room}:link", {url: url, timestamp: @get('timestamp')}

  extract_images: ->
    body = @get('body')

    images = body.match(REGEXES.urls.image) || []
    for url in images
      window.events.trigger "linklog:#{@room}:image",
        url: url
        image_url: url
        title: "Linked by #{@get('nickname')}"
        timestamp: @get('timestamp')

  extract_youtubes: ->
    body = @get('body')

    youtubes = body.match(REGEXES.urls.youtube) || []
    for url in youtubes
      window.events.trigger "linklog:#{@room}:youtube", {url: url, timestamp: @get('timestamp')}

  calculate_references: (body) ->
    previousReferences = @get('references')
    matches = body.match(REGEXES.commands.reply)
    if matches
      currentReferences = for match in body.match(REGEXES.commands.reply)
        number = match.replace(/[^0-9]/g, "")
        parseInt(number, 10)
    else
      currentReferences = []

    # update colors
    @set('references', currentReferences)
    newReferences = _.without(currentReferences, previousReferences)
    for ref in newReferences
      window.events.trigger "color:query:#{@room}", ref, (result) =>
        @set("thread_color", result)

    # dereference anything not in our current references
    # TODO: this doesn't actually work atm, need a better way of tracking references
    # calculate_references is being called twice, inflating the ref count
    toDeref = _.difference(previousReferences, currentReferences)
    for ref in toDeref
      window.events.trigger "color:dereference:#{@room}", ref

  format_body: ->
    body = @get("body")
    opts = {}  if !opts

    # only extract links from user-sent messages
    if @get("class") isnt "identity" and @get("trustworthiness") isnt "limited" # setting nick to a image URL or youtube URL should not update media bar
      @extract_images()
      @extract_youtubes()
      @extract_links()

    # sanitize the body:
    if @get("trustworthiness") is "limited"
      sanitizer = new HTMLSanitizer
      body = sanitizer.sanitize(body, ["A", "I", "IMG","UL","LI"], ["href", "title", "class", "src", "target", "rel"])
    else
      body = _.escape(body)

      # convert new lines to breaks:
      if body.match(/\n/g)
        lines = body.split(/\n/g)
        body = ""
        _.each lines, (line) ->
          line = "<pre>" + line + "</pre>"
          body += line

      @calculate_references(body)

      # format >>quotations:
      body = body.replace(REGEXES.commands.reply, "<a rel=\"$2\" class=\"quotation\" href=\"#" + @room + "$2\">&gt;&gt;$2</a>")

      body = body.replace(REGEXES.urls.all_others, "<a rel=\"noreferrer\" target=\"_blank\" href=\"$1\">$1</a>") # hyperify hyperlinks for the chatlog:
      body = body.replace(REGEXES.users.mentions, "<span class=\"mention\">$1</span>")

      body = emojify.replace(body)


    @set 'formatted_body', body
