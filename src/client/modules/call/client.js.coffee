Mewl                          = require("../../ui/Mewl.js.coffee")
callPanelTemplate             = require("./templates/callPanel.html")
mediaStreamContainerTemplate  = require("./templates/mediaStreamContainer.html")
RTC                           = require("./rtc.js.coffee").RTC

module.exports.CallClient = class CallClient extends Backbone.View

  className: "callClient"

  template: callPanelTemplate
  streamTemplate: mediaStreamContainerTemplate

  events:
    "click .join-call": "joinCall"
    "click .hang-up": "leaveCall"
    "click .mute-audio": "toggleMuteAudio"
    "click .mute-video": "toggleMuteVideo"

  initialize: (opts) ->
    _.bindAll this
    @channel = opts.channel
    @channelName = opts.room
    @config = opts.config
    @module = opts.module
    @socket = io.connect(@config.host + "/call")
    @rtc = new RTC
      socket: @socket
      room: @channelName

    @videos = {}
    @render()
    @on "show", =>
      @$el.show()

    @on "hide", =>
      @$el.hide()

    @listen()
    if not window.PeerConnection or not navigator.getUserMedia
      $(".webrtc-error .no-webrtc", @$el).show()
    else
      $(".webrtc-error .no-webrtc", @$el).hide()

      @socket.emit "subscribe", room: @channelName

      window.events.on "sectionActive:calling", @subdivideVideos
      @onResize = _.debounce(@subdivideVideos, 250)
      $(window).on "resize", @onResize

  toggleMuteAudio: (ev) ->
    $this = $(ev.currentTarget)

    if $this.hasClass("unmuted")
      @rtc.setUserMedia audio: false
    else
      @rtc.setUserMedia audio: true
    $this.toggleClass "unmuted"

  toggleMuteVideo: (ev) ->
    $this = $(ev.currentTarget)
    if $this.hasClass("unmuted")
      @rtc.setUserMedia video: false
    else
      @rtc.setUserMedia video: true
    $this.toggleClass "unmuted"

  showError: (err, errMsg) ->
    $(".no-call, .in-call", @$el).hide()
    $(".webrtc-error, .reason.generic", @$el).show()
    $(".reason.generic", @$el).html ""
    $(".reason.generic", @$el).append "<p>WebRTC failed!</p>"
    $(".reason.generic", @$el).append "<p>" + errMsg + "</p>"

  joinCall: (ev) ->
    $target = $(ev.currentTarget)
    withAudio = $target.hasClass("audio")
    withVideo = $target.hasClass("video")
    @joiningCall = true
    return  unless @$el.is(":visible")
    console.log "Asking/Attempting to create client's local stream"

    # should this only create ONE local stream?
    # so that muting one mutes all..
    # probably should wrap it in a model if so so we can listen to it everywhere for UI purposes
    @rtc.requestClientStream
      video: withVideo
      audio: withAudio
    , @gotUserMedia, @showError

  gotUserMedia: (stream) ->
    you = $(".you", @$el).get(0)
    @localStream = stream # keep track of the stream we just made
    @joiningCall = false
    @inCall = true
    you.src = URL.createObjectURL(stream)

    # you.mozSrcObject = URL.createObjectURL(stream);
    you.play()
    $(".no-call", @$el).hide()
    $(".in-call", @$el).show()
    @rtc.listen()
    @rtc.startSignalling()
    @rtc.setUserMedia
      audio: true
      video: true

    window.events.trigger "in_call:" + @channelName

  leaveCall: ->
    @inCall = false
    $(".in-call", @$el).hide()
    @disconnect()
    $(".no-call", @$el).show()
    @showCallInProgress()
    window.events.trigger "left_call:" + @channelName

  showCallInProgress: ->
    $(".call-status", @$el).hide()
    $(".no-call, .call-in-progress", @$el).show()

  showNoCallInProgress: ->
    $(".call-status", @$el).hide()
    $(".no-call, .no-call-in-progress", @$el).show()

  listen: ->

    # on peer joining the call:
    @rtc.on "added_remote_stream", (data) =>
      client = @channel.clients.findWhere(id: data.socketID)
      clientNick = client.getNick() # TODO: handle encrypted version

      console.log "ADDING REMOTE STREAM...", @channel, data.stream, data.socketID

      $video = @createVideoElement(data.socketID)
      @rtc.attachStream data.stream, $video.find("video")[0]
      @subdivideVideos()

      notifications.notify
        title: "echoplexus"
        body: clientNick + " joined the call!"
        tag: "callStatus"

      if OPTIONS.show_mewl
        mewl = new Mewl
          title: @channelName
          body: clientNick + " joined the call!"

    # on peer leaving the call:
    @rtc.on "disconnected_stream", (clientID) =>
      console.log "remove " + clientID
      @removeVideo clientID

    # politely hang up before closing the tab/window
    $(window).on "unload", =>
      @disconnect()

    @socketEvents =
      status: (data) =>
        if data.active and not @inCall and not @joiningCall

          # show the ringing phone if we're not in/joinin a call & a call starts
          @showCallInProgress()
        else @showNoCallInProgress() unless data.active

    _.each @socketEvents, (value, key) =>

      # listen to a subset of event
      @socket.on "#{key}:#{@channelName}", value


  disconnect: ->
    $(".videos", @$el).html ""
    @localStream.stop()  if @localStream
    @videos = []
    @rtc.setUserMedia
      video: false
      audio: false

    @rtc.disconnect()

  kill: ->
    @disconnect()
    _.each @socketEvents, (method, key) =>
      @socket.removeAllListeners "#{key}:#{@channelName}"

    @socket.emit "unsubscribe:#{@channelName}", room: @channelName

    $(window).off "resize", @onResize

  render: ->
    @$el.html @template()

  getNumPerRow: ->
    len = _.size(@videos)
    biggest = undefined

    # Ensure length is even for better division.
    len++  if len % 2 is 1
    biggest = Math.ceil(Math.sqrt(len))
    biggest++  while len % biggest isnt 0
    biggest

  subdivideVideos: ->
    videos = _.values(@videos)
    perRow = @getNumPerRow()
    numInRow = 0
    console.log videos, videos.length
    i = 0
    len = videos.length

    while i < len
      video = videos[i]
      @setWH video, i, len
      numInRow = (numInRow + 1) % perRow
      i++

  setWH: (video, i, len) ->
    $container = $(".videos", @$el)
    containerW = $container.width()
    containerH = $container.height()
    perRow = @getNumPerRow()
    perColumn = Math.ceil(len / perRow)
    width = Math.floor((containerW) / perRow)
    height = Math.floor((containerH) / perColumn)
    video.css
      width: width
      height: height
      position: "absolute"
      left: (i % perRow) * width + "px"
      top: Math.floor(i / perRow) * height + "px"


  createVideoElement: (clientID) ->
    client = @channel.clients.findWhere(id: clientID)
    clientNick = client.getNick() # TODO: handle encrypted version
    $video = $(@streamTemplate(
      id: clientID
      nick: clientNick
    ))

    # keep track of the $element by clientID
    @videos[clientID] = $video

    # add the new stream element to the container
    $(".videos", @$el).append $video
    $video

  removeVideo: (id) ->
    video = @videos[id]
    console.log "video", id, video
    if video
      video.remove()
      delete @videos[id]

  initFullScreen: ->
    button = document.getElementById("fullscreen")
    button.addEventListener "click", (event) ->
      elem = document.getElementById("videos")

      #show full screen
      elem.webkitRequestFullScreen()


