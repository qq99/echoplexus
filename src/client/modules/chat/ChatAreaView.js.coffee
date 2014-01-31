chatareaTemplate            = require("./templates/chatArea.html")
chatMessageTemplate         = require("./templates/chatMessage.html")
linkedImageTemplate         = require("./templates/linkedImage.html")
userListUserTemplate        = require("./templates/userListUser.html")
youtubeTemplate             = require("./templates/youtube.html")
webshotBadgeTemplate        = require("./templates/webshotBadge.html")
REGEXES                     = require("../../regex.js.coffee").REGEXES
CryptoWrapper               = require("../../CryptoWrapper.coffee").CryptoWrapper
HTMLSanitizer               = require("../../utility.js.coffee").HTMLSanitizer
cryptoWrapper               = new CryptoWrapper


module.exports.ChatAreaView = class ChatAreaView extends Backbone.View

  makeYoutubeThumbnailURL: (vID) ->
    window.location.protocol + "//img.youtube.com/vi/" + vID + "/0.jpg"
  makeYoutubeURL: (vID) ->
    window.location.protocol + "//youtube.com/v/" + vID

  className: "channel"

  # templates:
  template: chatareaTemplate
  chatMessageTemplate: chatMessageTemplate
  linkedImageTemplate: linkedImageTemplate
  userTemplate: userListUserTemplate
  youtubeTemplate: youtubeTemplate
  webshotBadgeTemplate: webshotBadgeTemplate

  events:
    "click .clearMediaLog": "clearMedia"
    "click .disableMediaLog": "disallowMedia"
    "click .maximizeMediaLog": "unminimizeMediaLog"
    "click .media-opt-in .opt-in": "allowMedia"
    "click .media-opt-in .opt-out": "disallowMedia"
    "click .chatMessage-edit": "beginEdit"
    "click .toggle-support-bar": "toggleSupportBar"
    "click .pin-button": "pinChat"
    "mouseenter .quotation": "showQuotationContext"
    "mouseleave .quotation": "hideQuotationContext"
    "blur .body[contenteditable='true']": "stopInlineEdit"
    "keydown .body[contenteditable='true']": "onInlineEdit"
    "dblclick .chatMessage.me:not(.private)": "beginInlineEdit"
    "click .edit-profile": "editProfile"
    "click .view-profile": "viewProfile"
    "mouseover .chatMessage": "showSentAgo"
    "mouseover .user": "showIdleAgo"
    "click .webshot-badge .badge-title": "toggleBadge"
    "click .quotation": "addQuotationHighlight"
    "click .youtube.imageThumbnail": "showYoutubeVideo"

  initialize: (options) ->
    self = this
    preferredAutoloadSetting = undefined
    _.bindAll this
    @scrollToLatest = _.debounce(@_scrollToLatest, 200) # if we're pulling a batch, do the scroll just once
    throw "No channel designated for the chat log"  unless options.room
    @room = options.room
    @me = options.me
    @uniqueURLs = {}
    @autoloadMedia = null # the safe default
    preferredAutoloadSetting = window.localStorage.getItem("autoloadMedia:" + @room)
    if preferredAutoloadSetting # if a saved setting exists
      if preferredAutoloadSetting is "true"
        @autoloadMedia = true
      else
        @autoloadMedia = false
    @timeFormatting = setInterval(->
      self.reTimeFormatNthLastMessage 1, true
    , 30 * 1000)
    @render()
    @attachEvents()

  beginInlineEdit: (ev) ->
    $chatMessage = $(ev.target).parents(".chatMessage")
    oldText = undefined
    $chatMessage.find(".webshot-badge").remove()
    oldText = $chatMessage.find(".body").text().trim()

    # store the old text with the node
    $chatMessage.data "oldText", oldText

    # make the entry editable
    $chatMessage.find(".body").attr("contenteditable", "true").focus()

  stopInlineEdit: (ev) ->
    $(ev.target).removeAttr("contenteditable").blur()

  onInlineEdit: (ev) ->
    return  if ev.ctrlKey or ev.shiftKey # we don't fire any events when these keys are pressed
    $this = $(ev.target)
    $chatMessage = $this.parents(".chatMessage")
    oldText = $chatMessage.data("oldText")
    mID = $chatMessage.data("sequence")
    switch ev.keyCode

      # enter:
      when 13
        ev.preventDefault()
        userInput = $this.text().trim()
        if userInput isnt oldText
          window.events.trigger "edit:commit:" + @room,
            mID: mID
            newText: userInput

          @stopInlineEdit ev
        else
          @stopInlineEdit ev

      # escape
      when 27
        @stopInlineEdit ev

  render: ->
    linklogClasses = ""
    userlistClasses = ""
    optInClasses = ""
    if @autoloadMedia is true
      optInClasses = "hidden"
    else if @autoloadMedia is false
      linklogClasses = "minimized"
      userlistClasses = "maximized"
    else # user hasn't actually made a choice (null value)
      linklogClasses = "not-initialized"

    @$el.html @template(
      roomName: @room
      linklogClasses: linklogClasses
      optInClasses: optInClasses
      userlistClasses: userlistClasses
      pinned: window.chatIsPinned
    )

    @stickit window.GlobalUIState,
      "i.pin":
        attributes: [{
          name: 'class'
          observe: 'chatIsPinned'
          onGet: 'formatPinned'
        }]

  formatPinned: (isPinned) ->
    return 'fa fa-expand' if isPinned
    return 'fa fa-compress'

  unminimizeMediaLog: -> # nb: not the opposite of maximize
    # resets the state to the null choice
    # slide up the media tab (if it was hidden)
    $(".linklog", @$el).removeClass("minimized").addClass "not-initialized"
    $(".userlist", @$el).removeClass "maximized"
    $(".media-opt-in", @$el).fadeIn()

  disallowMedia: ->
    @autoloadMedia = false
    @clearMedia()
    window.localStorage.setItem "autoloadMedia:" + @room, false

    # slide down the media tab to make more room for the Users tab
    $(".linklog", @$el).addClass("minimized").removeClass "not-initialized"
    $(".userlist", @$el).addClass "maximized"

  allowMedia: ->
    $(".media-opt-in", @$el).fadeOut()
    @autoloadMedia = true
    window.localStorage.setItem "autoloadMedia:" + @room, true
    $(".linklog", @$el).removeClass "not-initialized"

  beginEdit: (ev) ->
    mID = $(ev.target).parents(".chatMessage").data("sequence")
    if mID
      window.events.trigger "beginEdit:" + @room,
        mID: mID


  attachEvents: ->

    # show "Sent ___ ago" when hovering all chat messages:
    @$el.on "mouseenter", ".chatMessage", (ev) ->
      $(this).attr "title", "sent " + moment($(".time", this).data("timestamp")).fromNow()


    # media item events:
    # remove it from view on close button
    @$el.on "click", ".close", (ev) ->
      $button = $(this)
      $button.closest(".media-item").remove()


    # minimize/maximize the media item
    @$el.on "click", ".hide, .show", (ev) ->
      $button = $(this)
      $button.toggleClass("hide").toggleClass "show"

      # change the icon
      $button.find("i").toggleClass("fa-minus-square-o").toggleClass "fa-plus-square-o"

      # toggle the displayed view (.min|.max)
      $button.closest(".media-item").toggleClass "minimized"

      # update the text
      if $button.hasClass("hide")
        $button.find(".explanatory-text").text "Hide"
      else
        $button.find(".explanatory-text").text "Show"


  _scrollToLatest: (ev) -> #Get the last message and scroll that into view
    now = Number(new Date())

    # don't scroll if the user was manually scrolling recently (<3s ago)
    return if @mostRecentScroll and (now - @mostRecentScroll) < 3000

    # can't simply use last-child, since the last child may be display:none
    # if the user is hiding join/part
    latestMessage = ($(".messages .chatMessage:visible", @$el).last())[0] # so we get all visible, then take the last of that
    latestMessage.scrollIntoView()  if typeof latestMessage isnt "undefined"

  replaceChatMessage: (msg) ->
    msgHtml = @renderChatMessage(msg, # render the altered message, but don't insert it yet
      delayInsert: true
    )
    $oldMsg = $(".chatMessage[data-sequence='" + msg.get("mID") + "']", @$el)
    $oldMsg.after msgHtml
    $oldMsg.remove()

  renderWebshot: (msg) ->
    $targetChat = @$el.find(".chatMessage[data-sequence='" + msg.from_mID + "']")
    targetContent = $targetChat.find(".body").html().trim()
    urlLocation = targetContent.indexOf(msg.original_url) # find position in text
    badgeLocation = targetContent.indexOf(" ", urlLocation) # insert badge after that
    badge = @webshotBadgeTemplate(msg)
    if badgeLocation is -1
      targetContent += badge
    else
      pre = targetContent.slice(0, badgeLocation)
      post = targetContent.slice(badgeLocation)
      targetContent = pre + badge + post
    if @autoloadMedia

      # insert image into media pane
      img = @linkedImageTemplate(
        url: msg.original_url
        image_url: msg.webshot
        title: msg.title
      )
      $(".linklog .body", @$el).prepend img

    # modify content of user-sent chat message
    $targetChat.find(".body").html targetContent

  toggleBadge: (ev) ->

    # show hide page title/excerpt
    $(ev.currentTarget).parents(".webshot-badge").toggleClass "active"

  renderChatMessage: (msg, opts) ->
    self = this
    body = undefined
    nickname = undefined

    if typeof msg.get("encrypted_nick") isnt "undefined"
      nickname = cryptoWrapper.decryptObject(msg.get("encrypted_nick"), @me.cryptokey)
    else
      nickname = msg.get("nickname")
    if typeof msg.get("encrypted") isnt "undefined"
      body = cryptoWrapper.decryptObject(msg.get("encrypted"), @me.cryptokey)
    else
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
      nickClasses += "system "  if msg.get("type") is "SYSTEM"
      chatMessageClasses += msg.get("class")  if msg.get("class")

      # special styling of nickname depending on who you are:
      # if it's me!
      chatMessageClasses += " me "  if msg.get("you")
      chat = self.chatMessageTemplate(
        nickname: nickname
        is_encrypted: (typeof msg.get("encrypted") isnt "undefined")
        mID: msg.get("mID")
        color: msg.get("color")
        body: body
        room: self.room
        humanTime: humanTime
        timestamp: msg.get("timestamp")
        classes: chatMessageClasses
        nickClasses: nickClasses
        isPrivateMessage: (msg.get("type") and msg.get("type") is "private")
        mine: ((if msg.get("you") then true else false))
        identified: ((if msg.get("identified") then true else false))
      )
      unless opts.delayInsert
        self.insertChatMessage
          timestamp: msg.get("timestamp")
          html: chat

      chat

  insertBatch: (htmls) ->
    $(".messages", @$el).append htmls.join("")
    $(".chatMessage", @$el).addClass "fromlog"

  insertChatMessage: (opts) ->

    # insert msg into the correct place in history
    $chatMessage = $(opts.html)
    $chatlog = $(".messages", @$el)
    if opts.timestamp
      timestamps = _.map($(".messages .time", @$el), (ele) ->
        $(ele).data "timestamp"
      )
      # assumed invariant: timestamps are in ascending order
      cur = opts.timestamp
      candidate = -1
      $chatMessage.attr "rel", cur

      # find the earliest message we know of that's before the message we're about to render
      i = timestamps.length - 1

      while i >= 0
        candidate = timestamps[i]
        break  if cur > timestamps[i]
        i--

      # attempt to select this early message:
      $target = $(".messages .chatMessage[rel='" + candidate + "']", @$el)
      if $target.length # it was in the DOM, so we can insert the current message after it
        if i is -1
          $target.last().before $chatMessage # .last() just in case there can be more than one $target
        else
          $target.last().after $chatMessage # .last() just in case there can be more than one $target
      else # it was the first message OR something went wrong
        $chatlog.append $chatMessage
    else # if there was no timestamp, assume it's a diagnostic message of some sort that should be displayed at the most recent spot in history
      $chatlog.append $chatMessage
    @scrollToLatest()  if OPTIONS["auto_scroll"]
    @reTimeFormatNthLastMessage 2 # rewrite the timestamp on the message before the one we just inserted

  renderPreferredTimestamp: (timestamp) ->
    if OPTIONS["prefer_24hr_clock"] # TODO; abstract this check to be listening for an event
      moment(timestamp).format "H:mm:ss"
    else
      moment(timestamp).format "hh:mm:ss a"

  reTimeFormatNthLastMessage: (n, fromNow) ->
    $chatMessages = $(".chatMessage", @$el)
    nChats = $chatMessages.length
    $previousMessage = $($chatMessages[nChats - n])
    prevTimestamp = parseInt($previousMessage.find(".time").attr("data-timestamp"), 10)

    # overwrite the old timestamp's humanValue
    if fromNow
      $previousMessage.find(".time").text moment(prevTimestamp).fromNow()
    else
      $previousMessage.find(".time").text @renderPreferredTimestamp(prevTimestamp)

  clearChat: ->
    $chatlog = $(".messages", @$el)
    $chatlog.html ""

  clearMedia: ->
    $mediaPane = $(".linklog .body", @$el)
    $mediaPane.html ""

  renderUserlist: (users) ->
    self = this
    $userlist = $(".userlist .body", @$el)
    if users # if we have users
      # keep track of what the chat client tells us
      @knownUsers = users

      # clear out the userlist
      $userlist.html ""
      userHTML = ""
      nActive = 0
      total = 0
      _.each users.models, (user) ->
        nickname = user.getNick(self.me.cryptokey)

        # add him to the visual display
        userItem = self.userTemplate(
          nick: nickname
          using_encryption: (typeof user.get("encrypted_nick") isnt "undefined")
          id: user.id
          color: user.get("color").toRGB()
          identified: user.get("identified")
          idle: user.get("idle")
          idleSince: user.get("idleSince")
          operator: user.get("operator")
          inCall: user.get("inCall")
          me: (user.get("id") is self.me.get("id"))
        )
        nActive += 1  unless user.get("idle")
        total += 1
        userHTML += userItem

      $userlist.append userHTML
      $(".userlist .count .active .value", @$el).html nActive
      $(".userlist .count .total .value", @$el).html total
    else


  # there's always gonna be someone...
  viewProfile: (ev) ->
    uID = $(ev.target).parents(".user").attr("rel")
    window.events.trigger "view_profile",
      uID: uID
      room: @room
      clients: @knownUsers


  editProfile: (ev) ->
    uID = $(ev.target).parents(".user").attr("rel")
    window.events.trigger "edit_profile",
      uID: uID
      room: @room
      clients: @knownUsers


  setTopic: (newTopic) ->
    $(".channel-topic .value", @$el).html newTopic

  showQuotationContext: (ev) ->
    $this = $(ev.currentTarget)
    quoting = $this.attr("rel")
    $quoted = $(".chatMessage[data-sequence='" + quoting + "']")
    excerpt = undefined
    excerpt = $quoted.find(".nick").text().trim() + ": " + $quoted.find(".body").text().trim()
    $this.attr "title", excerpt
    $quoted.addClass "context"

  hideQuotationContext: (ev) ->
    $this = $(ev.currentTarget)
    quoting = $this.attr("rel")
    $quoted = $(".chatMessage[data-sequence='" + quoting + "']")
    $quoted.removeClass "context"

  addQuotationHighlight: (ev) ->
    quoting = $(ev.target).attr("rel")
    $quoted = $(".chatMessage[data-sequence='" + quoting + "']")
    $(".chatMessage", @$el).removeClass "context-persistent"
    $quoted.addClass "context-persistent"

  showIdleAgo: (ev) ->
    $idle = $(ev.currentTarget).find(".idle")
    if $idle.length
      timestamp = parseInt($idle.attr("data-timestamp"), 10)
      $(ev.currentTarget).attr "title", "Idle since " + moment(timestamp).fromNow()

  showSentAgo: (ev) ->
    $time = $(".time", ev.currentTarget)
    timestamp = parseInt($time.attr("data-timestamp"), 10)
    $(ev.currentTarget).attr "title", "sent " + moment(timestamp).fromNow()

  showYoutubeVideo: (ev) ->
    $(ev.currentTarget).hide()
    $(ev.currentTarget).siblings(".video").show()

  toggleSupportBar: (ev) ->
    $target = $(ev.currentTarget)
    $button = $target.find(".btn")

    if $button.hasClass("fa-caret-right")
      $button.removeClass("fa-caret-right").addClass("fa-caret-left")
    else
      $button.removeClass("fa-caret-left").addClass("fa-caret-right")

    $target.parents(".supportbar").toggleClass("expanded").siblings(".chatarea").toggleClass("expanded")

  pinChat: (ev) ->
    $target = $(ev.currentTarget)

    window.GlobalUIState.set('chatIsPinned', !window.GlobalUIState.get('chatIsPinned'))

    $("#chatting").toggleClass("pinned-section")
    if window.GlobalUIState.get('chatIsPinned')
      $(".tabButton").not("[data-target='#chatting']").first().click() # as soon as we pin the chat, we'll click the next module open
    else
      $("#panes > section").hide() # hide everything
      $(".tabButton[data-target='#chatting']").click() # make it as if chat were active for the very first time
