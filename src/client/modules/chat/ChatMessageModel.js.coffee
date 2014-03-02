CryptoWrapper               = require("../../CryptoWrapper.coffee").CryptoWrapper
cryptoWrapper               = new CryptoWrapper
REGEXES                     = require("../../regex.js.coffee").REGEXES

module.exports.ChatMessage = class ChatMessage extends Backbone.Model
  idAttribute: 'mID'

  initialize: (model, opts) ->
    _.bindAll this
    _.extend this, opts

    @decryptSharedSecret()
    @unwrap()

    @me.on "change:cryptokey", (data) =>
      @decryptSharedSecret()
      @format_body()

    @format_body()

  decryptSharedSecret: () ->
    cryptokey = @me.get("cryptokey")
    return if @get("was_encrypted") # it's already decrypted

    if @get("encrypted_nick")
      try
        nickname = cryptoWrapper.decryptObject(@get("encrypted_nick"), cryptokey)
        @set("nickname", nickname)
        @unset("encrypted_nick")
      catch e
        @set("nickname", @get("encrypted_nick").ct)

    if @get("encrypted")
      try
        body = cryptoWrapper.decryptObject(@get("encrypted"), cryptokey)
        @set("body", body)
        @unset("encrypted")
      catch e
        @set("body", @get("encrypted").ct)

    #console.log body, nickname

  unwrapSigned: (msg) ->
    return if @unwrapped
    msg = this
    body = msg.get("body")

    try
      msg.set "pgp_armored", _.escape(body).replace(/\n/g, "<br>")
      message      = openpgp.cleartext.readArmored(body)
      msg.set "body", message.text
      key          = KEYSTORE.get(msg.get("fingerprint"))
      if !key
        msg.set "pgp_verified", "unknown_public_key"
      dearmored    = openpgp.key.readArmored(key.armored_key)
      verification = openpgp.verifyClearSignedMessage(dearmored.keys, message)

      msg.set "body", verification.text

      if verification.signatures?[0].valid
        msg.set "pgp_verified", "signed"
        msg.set "trust_status", KEYSTORE.trust_status(msg.get("fingerprint"))
      else
        msg.set "pgp_verified", "signature_failure"

      @unwrapped = true
    catch e
      console.warn "Unable to verify PGP signed message: #{e}"

    msg

  unwrapSignedAndEncrypted: (msg) ->
    return if @unwrapped
    msg = this
    body = msg.get("body")

    try
      msg.set "pgp_armored", _.escape(body).replace(/\n/g, "<br>")
      message       = openpgp.message.readArmored(body)
      key           = KEYSTORE.get(msg.get("fingerprint"))
      if !key
        msg.set "pgp_verified", "unknown_public_key"
      dearmored_pub = openpgp.key.readArmored(key.armored_key)

      @me.pgp_settings.usablePrivateKey '', (priv) ->
        priv          = priv[0]
        decrypted     = openpgp.decryptAndVerifyMessage(priv, dearmored_pub.keys, message)

        msg.set "body", decrypted.text
        msg.set "hidden_body", false

        if decrypted.signatures?[0].valid
          msg.set "pgp_verified", "signed"
          msg.set "trust_status", KEYSTORE.trust_status(msg.get("fingerprint"))
          @unwrapped = true
        else
          msg.set "pgp_verified", "signature_failure"
    catch e
      msg.set "hidden_body", true
      console.warn "Unable to decrypt PGP signed message: #{e}"

    msg

  unwrapEncrypted: () ->
    return if @unwrapped
    msg = this
    body = msg.get("body")

    try
      msg.set "pgp_armored", _.escape(body).replace(/\n/g, "<br>")
      message       = openpgp.message.readArmored(body)
      key           = KEYSTORE.get(msg.get("fingerprint"))
      @me.pgp_settings.usablePrivateKey '', (priv) ->
        priv = priv[0]
        decrypted = openpgp.decryptMessage(priv, message)

        msg.set "body", decrypted
        msg.set "hidden_body", false
        msg.set "trust_status", KEYSTORE.trust_status(msg.get("fingerprint"))
        @unwrapped = true
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

  format_body: ->
    msg = this
    nickname  = msg.get("nickname")


    body = msg.get("body")

    opts = {}  if !opts
    if @autoloadMedia and msg.get("class") isnt "identity" and msg.get("trustworthiness") isnt "limited" # setting nick to a image URL or youtube URL should not update media bar
      # put image links on the side:
      images = undefined
      if images = body.match(REGEXES.urls.image)
        i = 0
        l = images.length

        while i < l
          href = images[i]

          # only do it if it's an image we haven't seen before
          if !self.uniqueURLs[href]?
            img = self.linkedImageTemplate(
              url: href
              image_url: href
              title: "Linked by " + nickname
            )
            $(".linklog .body", @$el).prepend img
            self.uniqueURLs[href] = true
          i++

      # body = body.replace(REGEXES.urls.image, "").trim(); // remove the URLs

      # put youtube linsk on the side:
      youtubes = undefined
      if youtubes = body.match(REGEXES.urls.youtube)
        i = 0
        l = youtubes.length

        while i < l
          vID = (REGEXES.urls.youtube.exec(youtubes[i]))[5]
          src = undefined
          img_src = undefined
          yt = undefined
          REGEXES.urls.youtube.exec "" # clear global state
          src = @makeYoutubeURL(vID)
          img_src = @makeYoutubeThumbnailURL(vID)
          yt = self.youtubeTemplate(
            vID: vID
            img_src: img_src
            src: src
            originalSrc: youtubes[i]
          )
          if !self.uniqueURLs[src]?
            $(".linklog .body", @$el).prepend yt
            self.uniqueURLs[src] = true
          i++

      # put hyperlinks on the side:
      links = undefined
      if links = body.match(REGEXES.urls.all_others)
        i = 0
        l = links.length

        while i < l
          if !self.uniqueURLs[links[i]]?
            $(".linklog .body", @$el).prepend "<a rel='noreferrer' href='" + links[i] + "' target='_blank'>" + links[i] + "</a>"
            self.uniqueURLs[links[i]] = true
          i++
    # end media insertion

    # sanitize the body:
    if msg.get("trustworthiness") is "limited"
      sanitizer = new HTMLSanitizer
      body = sanitizer.sanitize(body, ["A", "I", "IMG","UL","LI"], ["href", "title", "class", "src", "target", "rel"])
      nickname = sanitizer.sanitize(nickname, ["I"], ["class"])
    else
      body = _.escape(body)
      nickname = _.escape(nickname)

      # convert new lines to breaks:
      if body.match(/\n/g)
        lines = body.split(/\n/g)
        body = ""
        _.each lines, (line) ->
          line = "<pre>" + line + "</pre>"
          body += line


      # format >>quotations:
      body = body.replace(REGEXES.commands.reply, "<a rel=\"$2\" class=\"quotation\" href=\"#" + @room + "$2\">&gt;&gt;$2</a>")

      # hyperify hyperlinks for the chatlog:
      body = body.replace(REGEXES.urls.all_others, "<a rel=\"noreferrer\" target=\"_blank\" href=\"$1\">$1</a>")
      body = body.replace(REGEXES.users.mentions, "<span class=\"mention\">$1</span>")

      body = emojify.run(body)


    @set 'formatted_body', body
