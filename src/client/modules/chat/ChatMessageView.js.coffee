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

  bindings:
    ".body-content":
      observe: "formatted_body"
      updateMethod: 'html'
    ".nickname":
      observe: "nickname"
      attributes: [{
        name: 'title'
        observe: 'nickname'
      }]
    ".time":
      observe: "timestamp"
      onGet: "formatTimestamp"
    ".body-text-area":
      attributes: [{
        name: 'class'
        observe: 'hidden_body'
        onGet: (val) ->
          if val
            return 'body-text-area keyblocked'
          else
            return 'body-text-area'
      }]

  events:
    "click .chatMessage-edit": "beginEdit"
    "click .btn.toggle-armored": "toggleArmored"
    "blur .body[contenteditable='true']": "stopInlineEdit"
    "keydown .body[contenteditable='true']": "onInlineEdit"
    "dblclick .chatMessage.me:not(.private)": "beginInlineEdit"
    "mouseover .chatMessage": "showSentAgo"
    "click .webshot-badge .badge-title": "toggleBadge"
    "click .un-keyblock": "unlockKeypair"

  initialize: (opts) ->
    _.bindAll this
    _.extend this, opts


    @me.pgp_settings.on "change:cached_private", =>
      @model.unwrap()

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

  renderPreferredTimestamp: (timestamp) ->
    if OPTIONS["prefer_24hr_clock"] # TODO; abstract this check to be listening for an event
      moment(timestamp).format "H:mm:ss"
    else
      moment(timestamp).format "hh:mm:ss a"

  formatTimestamp: (time) ->
    if (new Date()) - time > 1000*60*60*2
      humanTime = moment(time).fromNow()
    else
      humanTime = @renderPreferredTimestamp(time)

  unlockKeypair: ->
    @me.pgp_settings.prompt()

  render: ->
    msg = @model
    body = msg.get('formatted_body')
    if body?.length # if there's anything left in the body,
      chatMessageClasses = ""
      nickClasses = ""

      # special styling of chat
      chatMessageClasses += "highlight "  if msg.get("directedAtMe")
      chatMessageClasses += "fromlog" if msg.get("from_log")
      nickClasses += "system "  if msg.get("type") is "SYSTEM"
      chatMessageClasses += msg.get("class")  if msg.get("class")

      # special styling of nickname depending on who you are:
      # if it's me!
      chatMessageClasses += " me "  if msg.get("you")
      @$el.html(@chatMessageTemplate(
        is_encrypted: !!msg.get("was_encrypted")
        pgp_encrypted: msg.get("pgp_encrypted")
        pgp_armored: msg.get("pgp_armored") || null
        mID: msg.get("mID")
        color: msg.get("color")
        body: body
        room: msg.get("room")
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

      @stickit(@model)
    else
      ""
