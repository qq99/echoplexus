chatareaTemplate            = require("./templates/chatArea.html")
userListUserTemplate        = require("./templates/userListUser.html")
REGEXES                     = require("../../regex.js.coffee").REGEXES
CryptoWrapper               = require("../../CryptoWrapper.coffee").CryptoWrapper
HTMLSanitizer               = require("../../utility.js.coffee").HTMLSanitizer
ChatMessageView             = require("./ChatMessageView.js.coffee").ChatMessageView
cryptoWrapper               = new CryptoWrapper
ChatMessage                 = require("./ChatMessageModel.js.coffee").ChatMessage
MediaLog                    = require("./MediaLog.js.coffee").MediaLog

ChatMessageCollection = class ChatMessageCollection extends Backbone.Collection
  comparator: (a, b) ->
    if a.get('timestamp') > b.get('timestamp')
      -1
    else
      1
  model: ChatMessage

module.exports.ChatAreaView = class ChatAreaView extends Backbone.View

  className: "channel"

  # templates:
  template: chatareaTemplate
  userTemplate: userListUserTemplate

  events:
    "click .toggle-support-bar": "toggleSupportBar"
    "click .pin-button": "pinChat"
    "click .pgp-fingerprint-icon.trusted": "untrustFingerprint"
    "click .pgp-fingerprint-icon.untrusted": "neutralTrustFingerprint"
    "click .pgp-fingerprint-icon.unknown": "trustFingerprint"
    "mouseenter .quotation": "showQuotationContext"
    "mouseleave .quotation": "hideQuotationContext"
    "mouseover .user": "showIdleAgo"
    "click .quotation": "addQuotationHighlight"
    "click .chatMessage-edit": "beginEdit"

  initialize: (options) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))

    throw "No room supplied for ChatAreaView" unless options.room

    @scrollToLatest = _.debounce(@_scrollToLatest, 200) # if we're pulling a batch, do the scroll just once

    @button = options.button
    @room = options.room
    @me = options.me

    @medialog = new MediaLog
      room: @room

    @messages = new ChatMessageCollection()
    @timeFormatting = setInterval(=>
      for model in @messages.models
        model.trigger("change:timestamp", model, model.get("timestamp")) # fake out a timestamp change to get stickit to rerender
    , 60*1000)


    @render()
    @attachEvents()

  render: ->
    @$el.html @template(
      roomName: @room
      pinned: window.chatIsPinned
    )

    @$el.find(".supportbar").append(@medialog.$el)

    @stickit @medialog.state,
      ".linklog":
        attributes: [{
          name: 'class'
          observe: 'autoloadMedia'
          onGet: (val) ->
            return 'linklog not-initialized' if val == 'unknown'
            return 'linklog minimized' if !val
            return 'linklog'
        }]
      ".userlist":
        attributes: [{
          name: 'class'
          observe: 'autoloadMedia'
          onGet: (val) ->
            return 'userlist' if val == 'unknown'
            return 'userlist maximized' if !val
            return 'userlist'
        }]
      ".media-opt-in":
        attributes: [{
          name: 'class'
          observe: 'autoloadMedia'
          onGet: (val) ->
            return 'media-opt-in' if val == 'unknown'
            return 'media-opt-in hidden'
        }]

    @stickit window.GlobalUIState,
      "i.pin":
        attributes: [{
          name: 'class'
          observe: 'chatIsPinned'
          onGet: (isPinned) ->
            return 'fa fa-expand' if isPinned
            return 'fa fa-compress'
        }]

  attachEvents: ->

    # media item events:
    # remove it from view on close button
    @$el.on "click", ".close", (ev) ->
      $button = $(this)
      $button.closest(".media-item-container").remove()

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

  replaceChatMessage: (msg, is_echo) ->
    if is_echo
      toReplace = @messages.findWhere({echo_id: msg.get("echo_id")})
      @messages.remove(toReplace)
      toReplace.view.$el.remove()

      @renderChatMessage(msg)

    else
      @messages.add(msg, {merge: true})

  markReceipt: (echo_id) ->
    @messages.findWhere({echo_id: echo_id}).set("sending", false)

  renderWebshot: (msg) ->
    message = @messages.findWhere({mID: msg.from_mID})
    message?.view.renderWebshot(msg)

  createChatMessage: (msg, opts = {}) ->
    message = new ChatMessage(msg, {
      me: @me
      parent: this
      room: @room
    })

  renderChatMessage: (msg, opts) ->
    chatMessageView = new ChatMessageView
      room: @room
      model: msg
      me: @me

    msg.view = chatMessageView

    @messages.add msg

    $chatlog = $(".messages", @$el)

    # O(n) in worst case, assuming document.contains is cheap
    for message in @messages.models
      if !message.view.inDOM # if the view el is not already in the dom, then we'll add it
        if prev # push it in the right spot relative to its neighbours
          if prev.get('timestamp') > message.get('timestamp')
            prev.view.$el.before(message.view.el)
          else
            prev.view.$el.after(message.view.el)
        else # it's the first one we parse, simply push it in
          $chatlog.append(message.view.el)
        message.view.inDOM = true
      prev = message

    @scrollToLatest() if OPTIONS["auto_scroll"]

  clearChat: ->
    @messages.reset()
    $chatlog = $(".messages", @$el)
    $chatlog.html ""

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
        nickClass = if user.get("idle") then "idle" else "active"

        # add him to the visual display
        userItem = @userTemplate(
          nick: nickname
          has_public_key: !!user.get("armored_public_key")
          fingerprint: user.getPGPFingerprint()
          fingerprint_trust: KEYSTORE.trust_status(user.getPGPFingerprint())
          using_encryption: (typeof user.get("encrypted_nick") isnt "undefined")
          id: user.id
          identified: user.get("identified")
          nickClass: nickClass
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
      @button.data.set
        activeUsers: nActive
        totalUsers: total
    else

  setTopic: (newTopic) ->
    $(".channel-topic .value", @$el).text newTopic
    @button.data.set("topic", newTopic)

  showQuotationContext: (ev) ->
    $this = $(ev.currentTarget)
    quoting = $this.attr("rel")
    $quoted = $(".chatMessage[data-sequence='" + quoting + "']", @$el)
    excerpt = $quoted.find(".nick").text().trim() + ": " + $quoted.find(".body-content").text().trim()
    $this.attr "title", excerpt
    $quoted.addClass "context"

  hideQuotationContext: (ev) ->
    $this = $(ev.currentTarget)
    quoting = $this.attr("rel")
    $quoted = $(".chatMessage[data-sequence='" + quoting + "']", @$el)
    $quoted.removeClass "context"

  addQuotationHighlight: (ev) ->
    quoting = $(ev.target).attr("rel")
    $quoted = $(".chatMessage[data-sequence='" + quoting + "']", @$el)
    $(".chatMessage", @$el).removeClass "context-persistent"
    $quoted.addClass "context-persistent"

  showIdleAgo: (ev) ->
    $idle = $(ev.currentTarget).find(".idle")
    if $idle.length
      timestamp = parseInt($idle.attr("data-timestamp"), 10)
      $(ev.currentTarget).attr "title", "Idle since " + moment(timestamp).fromNow()

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

  beginEdit: (ev) ->
    if mID = $(ev.currentTarget).parents(".chatMessage").data("sequence")
      window.events.trigger "beginEdit:" + @room,
        mID: mID
