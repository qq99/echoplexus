chatMessageTemplate         = require("./templates/chatMessage.html")
linkedImageTemplate         = require("./templates/linkedImage.html")
youtubeTemplate             = require("./templates/youtube.html")
webshotBadgeTemplate        = require("./templates/webshotBadge.html")
REGEXES                     = require("../../regex.js.coffee").REGEXES

module.exports.ChatMessageView = class ChatMessageView extends Backbone.View

  className: 'ChatMessageView'

  chatMessageTemplate: chatMessageTemplate
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
      }, {
        name: 'style'
        observe: 'nickname'
        onGet: (val) -> 'display: none;' if val == 'GitHub'
      }]
    ".github-nickname":
      attributes: [{
        name: 'style'
        observe: 'nickname'
        onGet: (val) -> 'display: block;' if val == 'GitHub'
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
    "click .btn.toggle-armored": "toggleArmored"
    "blur .body-content[contenteditable='true']": "stopInlineEdit"
    "keydown .body-content[contenteditable='true']": "onInlineEdit"
    "dblclick .chatMessage.me:not(.private)": "beginInlineEdit"
    "mouseover .chatMessage": "showSentAgo"
    "click .webshot-badge .toggle": "toggleBadge"

  initialize: (opts) ->
    _.bindAll this
    _.extend this, opts


    @me.pgp_settings.on "change:cached_private", =>
      @model.unwrap()

    @render()

  beginInlineEdit: (ev) ->
    @$el.find(".webshot-badge").remove()
    oldText = @$el.find(".body-content").text().trim()

    # store the old text with the node
    @oldText = oldText

    # make the entry editable
    @$el.find(".body-content").attr("contenteditable", "true").focus()

  onInlineEdit: (ev) ->
    return if ev.ctrlKey or ev.shiftKey # we don't fire any events when these keys are pressed
    return if !(mID = @model.get("mID"))
    $this = $(ev.target)

    switch ev.keyCode
      when 13 # enter key
        ev.preventDefault()
        userInput = $this.text().trim()
        if userInput isnt @oldText
          window.events.trigger "edit:commit:#{@room}",
            mID: mID
            newText: userInput

          @stopInlineEdit ev
        else
          @stopInlineEdit ev

      when 27 # escape key
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
    # TODO: readd preferred time
    humanTime = moment(time).fromNow()

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
        room: @room
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

  renderWebshot: (msg) ->
    targetContent = @$el.find(".body-content").html().trim()
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
    @$el.find(".body").html targetContent
