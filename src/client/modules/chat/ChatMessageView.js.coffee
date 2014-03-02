chatMessageTemplate         = require("./templates/chatMessage.html")
linkedImageTemplate         = require("./templates/linkedImage.html")
youtubeTemplate             = require("./templates/youtube.html")
webshotBadgeTemplate        = require("./templates/webshotBadge.html")
REGEXES                     = require("../../regex.js.coffee").REGEXES

module.exports.ChatMessageView = class ChatMessageView extends Backbone.View

  className: 'ChatMessageView'

  chatMessageTemplate: chatMessageTemplate
  linkedImageTemplate: linkedImageTemplate
  youtubeTemplate: youtubeTemplate
  webshotBadgeTemplate: webshotBadgeTemplate

  events:
    "click .chatMessage-edit": "beginEdit"
    "click .btn.toggle-armored": "toggleArmored"
    "blur .body[contenteditable='true']": "stopInlineEdit"
    "keydown .body[contenteditable='true']": "onInlineEdit"
    "dblclick .chatMessage.me:not(.private)": "beginInlineEdit"
    "mouseover .chatMessage": "showSentAgo"
    "click .webshot-badge .badge-title": "toggleBadge"

  initialize: (opts) ->
    _.bindAll this
    _.extend this, opts

    # @model.on "change:body", (ev) =>
    #   @render()
    @render()

  beginEdit: (ev) ->
    if mID = @model.get("mID")
      window.events.trigger "beginEdit:" + @room,
        mID: mID

  beginInlineEdit: (ev) ->
    $chatMessage = $(ev.target).parents(".chatMessage")
    oldText = undefined
    $chatMessage.find(".webshot-badge").remove()
    oldText = $chatMessage.find(".body").text().trim()

    # store the old text with the node
    $chatMessage.data "oldText", oldText

    # make the entry editable
    $chatMessage.find(".body").attr("contenteditable", "true").focus()

  onInlineEdit: (ev) ->
    return  if ev.ctrlKey or ev.shiftKey # we don't fire any events when these keys are pressed
    $this = $(ev.target)
    $chatMessage = $this.parents(".chatMessage")
    oldText = $chatMessage.data("oldText")
    mID = @model.get("mID")

    return if !mID

    switch ev.keyCode

      # enter:
      when 13
        ev.preventDefault()
        userInput = $this.text().trim()
        if userInput isnt oldText
          console.log "edit:commit:" + @room
          window.events.trigger "edit:commit:" + @room,
            mID: mID
            newText: userInput

          @stopInlineEdit ev
        else
          @stopInlineEdit ev

      # escape
      when 27
        @stopInlineEdit ev

  stopInlineEdit: (ev) ->
    $(ev.target).removeAttr("contenteditable").blur()

  showSentAgo: (ev) ->
    $time = $(".time", ev.currentTarget)
    timestamp = parseInt($time.attr("data-timestamp"), 10)
    $(ev.currentTarget).attr "title", "sent " + moment(timestamp).fromNow()

  toggleArmored: (ev) ->
    $message = $(ev.currentTarget).parents(".chatMessage")
    $(".pgp-armored-body", $message).toggle()
    $(".body-content", $message).toggle()

  toggleBadge: (ev) ->

    # show hide page title/excerpt
    $(ev.currentTarget).parents(".webshot-badge").toggleClass "active"

  unwrapSigned: (msg) ->
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
    catch e
      console.warn "Unable to verify PGP signed message: #{e}"

    msg

  unwrapSignedAndEncrypted: (msg) ->
    body = msg.get("body")

    try
      msg.set "pgp_armored", _.escape(body).replace(/\n/g, "<br>")
      message       = openpgp.message.readArmored(body)
      key           = KEYSTORE.get(msg.get("fingerprint"))
      if !key
        msg.set "pgp_verified", "unknown_public_key"
      dearmored_pub = openpgp.key.readArmored(key.armored_key)
      priv          = @me.pgp_settings.usablePrivateKey()[0]
      decrypted     = openpgp.decryptAndVerifyMessage(priv, dearmored_pub.keys, message)

      msg.set "body", decrypted.text

      if decrypted.signatures?[0].valid
        msg.set "pgp_verified", "signed"
        msg.set "trust_status", KEYSTORE.trust_status(msg.get("fingerprint"))
      else
        msg.set "pgp_verified", "signature_failure"
    catch e
      console.warn "Unable to decrypt PGP signed message"

    msg

  unwrapEncrypted: (msg) ->
    body = msg.get("body")

    try
      msg.set "pgp_armored", _.escape(body).replace(/\n/g, "<br>")
      message       = openpgp.message.readArmored(body)
      key           = KEYSTORE.get(msg.get("fingerprint"))
      priv          = @me.pgp_settings.usablePrivateKey()[0]
      decrypted     = openpgp.decryptMessage(priv, message)

      msg.set "body", decrypted
      msg.set "trust_status", KEYSTORE.trust_status(msg.get("fingerprint"))
    catch e
      console.warn "Unable to decrypt PGP signed message"

    msg.set "pgp_verified", "not_signed"

    msg

  render: ->
    msg = @model
    nickname  = msg.get("nickname")
    signed    = msg.get("pgp_signed")
    encrypted = msg.get("pgp_encrypted")

    if signed and !encrypted
      msg = @unwrapSigned(msg)
    else if !signed and encrypted
      msg = @unwrapEncrypted(msg)
    else if signed and encrypted
      msg = @unwrapSignedAndEncrypted(msg)

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
              title: "Linked by " + msg.nickname
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

    if body.length # if there's anything left in the body,
      chatMessageClasses = ""
      nickClasses = ""
      humanTime = undefined

      if not opts.delayInsert
        humanTime = moment(msg.get("timestamp")).fromNow()
      else if (new Date()) - msg.get("timestamp") > 1000*60*60*2
        humanTime = moment(msg.get("timestamp")).fromNow()
      else
        humanTime = @renderPreferredTimestamp(msg.get("timestamp"))

      # special styling of chat
      chatMessageClasses += "highlight "  if msg.get("directedAtMe")
      chatMessageClasses += "fromlog" if msg.get("from_log")
      nickClasses += "system "  if msg.get("type") is "SYSTEM"
      chatMessageClasses += msg.get("class")  if msg.get("class")

      # special styling of nickname depending on who you are:
      # if it's me!
      chatMessageClasses += " me "  if msg.get("you")
      @$el.html(@chatMessageTemplate(
        nickname: nickname
        is_encrypted: !!msg.get("was_encrypted")
        pgp_encrypted: msg.get("pgp_encrypted")
        pgp_armored: msg.get("pgp_armored") || null
        mID: msg.get("mID")
        color: msg.get("color")
        body: body
        room: msg.get("room")
        humanTime: humanTime
        timestamp: msg.get("timestamp")
        classes: chatMessageClasses
        nickClasses: nickClasses
        isPrivateMessage: (msg.get("type") and msg.get("type") is "private")
        mine: ((if msg.get("you") then true else false))
        identified: ((if msg.get("identified") then true else false))
        fingerprint: msg.get("fingerprint")
        pgp_verified: msg.get("pgp_verified")
        trust_status: msg.get("trust_status")
      ))
    else
      ""
