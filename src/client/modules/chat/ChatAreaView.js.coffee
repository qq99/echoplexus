chatareaTemplate            = require("./templates/chatArea.html")
userListUserTemplate        = require("./templates/userListUser.html")
REGEXES                     = require("../../regex.js.coffee").REGEXES
CryptoWrapper               = require("../../CryptoWrapper.coffee").CryptoWrapper
HTMLSanitizer               = require("../../utility.js.coffee").HTMLSanitizer
ChatMessageView             = require("./ChatMessageView.js.coffee").ChatMessageView
cryptoWrapper               = new CryptoWrapper
ChatMessage                 = require("./ChatMessageModel.js.coffee").ChatMessage

ChatMessageCollection = class ChatMessageCollection extends Backbone.Collection
  comparator: 'timestamp'
  model: ChatMessage

module.exports.ChatAreaView = class ChatAreaView extends Backbone.View

  makeYoutubeThumbnailURL: (vID) ->
    window.location.protocol + "//img.youtube.com/vi/" + vID + "/0.jpg"
  makeYoutubeURL: (vID) ->
    window.location.protocol + "//youtube.com/v/" + vID

  className: "channel"

  # templates:
  template: chatareaTemplate
  userTemplate: userListUserTemplate

  events:
    "click .clearMediaLog": "clearMedia"
    "click .disableMediaLog": "disallowMedia"
    "click .maximizeMediaLog": "unminimizeMediaLog"
    "click .media-opt-in .opt-in": "allowMedia"
    "click .media-opt-in .opt-out": "disallowMedia"
    "click .toggle-support-bar": "toggleSupportBar"
    "click .pin-button": "pinChat"
    "click .pgp-fingerprint-icon.trusted": "untrustFingerprint"
    "click .pgp-fingerprint-icon.untrusted": "neutralTrustFingerprint"
    "click .pgp-fingerprint-icon.unknown": "trustFingerprint"
    "mouseenter .quotation": "showQuotationContext"
    "mouseleave .quotation": "hideQuotationContext"
    "mouseover .user": "showIdleAgo"
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

    if self == top # not iframed
      latestMessage.scrollIntoView() if typeof latestMessage isnt "undefined"
    else # iframed
      $(".messages")[0].scrollTop = latestMessage.offsetTop if typeof latestMessage isnt "undefined"

  replaceChatMessage: (msg) ->
    @messages.add(msg, {merge: true})

  renderWebshot: (msg) ->
    $targetChat = @$el.find(".chatMessage[data-sequence='" + msg.from_mID + "']")
    targetContent = $targetChat.find(".body-content").html().trim()
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

  renderChatMessage: (msg, opts) ->
    @messages = @messages || (new ChatMessageCollection())

    chatMessageView = new ChatMessageView
      model: msg
      me: @me

    msg.view = chatMessageView

    @messages.add msg # proper sorting collection needed

    $chatlog = $(".messages", @$el)
    for message in @messages.models
      $chatlog.append message.view.$el

    null

    @scrollToLatest() if OPTIONS["auto_scroll"]

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
    @messages.reset()
    $chatlog = $(".messages", @$el)
    $chatlog.html ""

  clearMedia: ->
    $mediaPane = $(".linklog .body", @$el)
    $mediaPane.html ""

  renderUserlist: (users) ->
    $userlist = $(".userlist .body", @$el)
    users = @cached_users if !users # use a local copy

    @cached_users = users
    if users # if we have users
      # keep track of what the chat client tells us
      @knownUsers = users

      # clear out the userlist
      $userlist.html ""
      userHTML = ""
      nActive = 0
      total = 0
      _.each users.models, (user) =>
        nickname = @me.getNickOf(user)

        # add him to the visual display
        userItem = @userTemplate(
          nick: nickname
          has_public_key: !!user.get("armored_public_key")
          fingerprint: user.getPGPFingerprint()
          fingerprint_trust: KEYSTORE.trust_status(user.getPGPFingerprint())
          using_encryption: (typeof user.get("encrypted_nick") isnt "undefined")
          id: user.id
          color: user.get("color").toRGB()
          identified: user.get("identified")
          idle: user.get("idle")
          idleSince: user.get("idleSince")
          operator: user.get("operator")
          inCall: user.get("inCall")
          me: user.is(@me)
        )
        nActive += 1  unless user.get("idle")
        total += 1
        userHTML += userItem

      $userlist.append userHTML
      $(".userlist .count .active .value", @$el).html nActive
      $(".userlist .count .total .value", @$el).html total
    else

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

  untrustFingerprint: (ev) ->
    fingerprint = $(ev.currentTarget).data("fingerprint")
    KEYSTORE.untrust(fingerprint)
    @renderUserlist()
    $(".pgp-verification-icon .fa-check", @$el).removeClass("trusted unknown").addClass("untrusted")

  trustFingerprint: (ev) ->
    fingerprint = $(ev.currentTarget).data("fingerprint")
    KEYSTORE.trust(fingerprint)
    @renderUserlist()
    $(".pgp-verification-icon .fa-check", @$el).removeClass("untrusted unknown").addClass("trusted")

  neutralTrustFingerprint: (ev) ->
    fingerprint = $(ev.currentTarget).data("fingerprint")
    KEYSTORE.neutral(fingerprint)
    @renderUserlist()
    $(".pgp-verification-icon .fa-check", @$el).removeClass("untrusted trusted").addClass("unknown")
