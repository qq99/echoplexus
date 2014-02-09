#Based on https://github.com/webRTC/webrtc.io-client/blob/master/lib/webrtc.io.js

# Fallbacks for vendor-specific variables until the spec is finalized.
# order is very important: "RTCSessionDescription" defined in Nighly but useless
PeerConnection              = window.PeerConnection = (window.PeerConnection or window.webkitPeerConnection00 or window.webkitRTCPeerConnection or window.mozRTCPeerConnection)
URL                         = window.URL = (window.URL or window.webkitURL or window.msURL or window.oURL)
getUserMedia                = navigator.getUserMedia = (navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia or navigator.msGetUserMedia)
NativeRTCIceCandidate       = window.NativeRTCIceCandidate = (window.mozRTCIceCandidate or window.RTCIceCandidate)
NativeRTCSessionDescription = window.NativeRTCSessionDescription = (window.mozRTCSessionDescription or window.RTCSessionDescription)

# always offer to receive both types of media, regardless of whether we send them
sdpConstraints =
  optional: []
  mandatory:
    OfferToReceiveAudio: true
    OfferToReceiveVideo: true

# create a polyfilled config for the PeerConnection polyfill object, using google's STUN servers
stunIceConfig = ->

  # config objects
  _ff_peerConnectionConfig = iceServers: [url: "stun:23.21.150.121"]
  _chrome_peerConnectionConfig = iceServers: [url: "stun:stun.l.google.com:19302"]

  # ua detection
  if ua.firefox
    _ff_peerConnectionConfig
  else
    _chrome_peerConnectionConfig

# check whether data channel is supported:
supportsDataChannel = (->
  try
    pc = new PeerConnection(stunIceConfig(), {optional: [{RtpDataChannels: true}]})
    channel = pc.createDataChannel("supportCheck",
      reliable: false
    )
    channel.close()
    return true
  catch e # raises exception if createDataChannel is not supported
    return false
)()

# New syntax of getXXXStreams method in M26.
preferOpus = (sdp) ->
  sdpLines = sdp.split("\r\n")
  mLineIndex = null

  # Search for m line.
  i = 0

  while i < sdpLines.length
    if sdpLines[i].search("m=audio") isnt -1
      mLineIndex = i
      break
    i++
  return sdp  if mLineIndex is null

  # If Opus is available, set it as the default in m line.
  j = 0

  while j < sdpLines.length
    if sdpLines[j].search("opus/48000") isnt -1
      opusPayload = extractSdp(sdpLines[j], /:(\d+) opus\/48000/i)
      sdpLines[mLineIndex] = setDefaultCodec(sdpLines[mLineIndex], opusPayload)  if opusPayload
      break
    j++

  # Remove CN in m line and sdp.
  sdpLines = removeCN(sdpLines, mLineIndex)
  sdp = sdpLines.join("\r\n")
  sdp

extractSdp = (sdpLine, pattern) ->
  result = sdpLine.match(pattern)
  (if (result and result.length is 2) then result[1] else null)

setDefaultCodec = (mLine, payload) ->
  elements = mLine.split(" ")
  newLine = []
  index = 0
  i = 0

  while i < elements.length
    # Format of media starts from the fourth.
    newLine[index++] = payload  if index is 3 # Put target payload to the first.
    newLine[index++] = elements[i]  if elements[i] isnt payload
    i++
  newLine.join " "

removeCN = (sdpLines, mLineIndex) ->
  mLineElements = sdpLines[mLineIndex].split(" ")

  # Scan from end for the convenience of removing an item.
  i = sdpLines.length - 1

  while i >= 0
    payload = extractSdp(sdpLines[i], /a=rtpmap:(\d+) CN\/\d+/i)
    if payload
      cnPos = mLineElements.indexOf(payload)

      # Remove CN payload from m line.
      mLineElements.splice cnPos, 1  if cnPos isnt -1

      # Remove CN line in sdp
      sdpLines.splice i, 1
    i--
  sdpLines[mLineIndex] = mLineElements.join(" ")
  sdpLines

mergeConstraints = (cons1, cons2) ->
  merged = cons1
  for name of cons2.mandatory
    merged.mandatory[name] = cons2.mandatory[name]
  merged.optional.concat cons2.optional
  merged



pcDataChannelConfig = optional: [{DtlsSrtpKeyAgreement: true}, {RtpDataChannels: true}, {DtlsSrtpKeyAgreement: true}]
pcConfig = optional: [DtlsSrtpKeyAgreement: true]

if navigator.webkitGetUserMedia
  unless webkitMediaStream::getVideoTracks
    webkitMediaStream::getVideoTracks = ->
      @videoTracks

    webkitMediaStream::getAudioTracks = ->
      @audioTracks
  unless webkitRTCPeerConnection::getLocalStreams
    webkitRTCPeerConnection::getLocalStreams = ->
      @localStreams

    webkitRTCPeerConnection::getRemoteStreams = ->
      @remoteStreams

module.exports.RTC = class RTC extends Backbone.Model

  defaults:
    me: null # my socket id
    connected: false

  initialize: (opts) ->
    self = this
    _.bindAll this
    _.extend this, opts
    @peerConnections = {}
    @localStreams = []
    @peerIDs = []


  # this.dataChannels = {};
  listen: ->
    self = this
    room = @room
    socket = @socket
    @socketEvents =
      ice_candidate: (data) ->

        # console.log('received signal: ice_candidate', data);
        candidate = new NativeRTCIceCandidate(data)
        self.peerConnections[data.id].addIceCandidate candidate

      new_peer: (data) ->
        console.log "signal: new_peer", data
        id = data.id
        pc = self.createPeerConnection(id)
        self.peerIDs.push id
        self.peerIDs = _.uniq(self.peerIDs) # just in case...

        # extend a welcome arm to our new peer <3
        self.sendOffer id

      remove_peer: (data) ->
        console.log "signal: remove_peer", data
        id = data.id
        self.trigger "disconnected_stream", id
        self.peerConnections[id].close()  if typeof (self.peerConnections[id]) isnt "undefined"
        delete self.peerConnections[id]


        # delete self.dataChannels[id];
        delete self.peerIDs[_.indexOf(@peerIDs, id)]

      offer: (data) ->
        console.log "recieved Offer"
        self.receiveOffer data.id, data.sdp

      answer: (data) ->
        console.log "recieved Answer"
        self.receiveAnswer data.id, data.sdp

    _.each @socketEvents, (value, key) ->

      # listen to a subset of event
      socket.on key + ":" + room, value


  startSignalling: ->
    self = this

    # attempt to register our intent to join/start call with the signalling server
    @socket.emit "join:" + @get("room"), {}, (ack) ->
      self.set
        me: ack.you
        connected: true

      self.connections = ack.connections


  disconnect: ->
    self = this
    @socket.emit "leave:" + @get("room"), {}

    # remove all signalling socket listeners
    _.each @socketEvents, (method, key) ->
      self.socket.removeAllListeners key + ":" + self.room

    _.each self.peerConnections, (connection, key) ->
      connection.close()
      self.trigger "disconnected_stream", key

    @localStreams = []
    @peerConnections = {}
    @dataChannels = {}
    @set
      connected: false
      me: null


  sendOffers: ->
    i = 0
    len = @peerIDs.length

    while i < len
      socketId = @peerIDs[i]
      @sendOffer socketId
      i++

  createPeerConnection: (targetClientID) ->
    self = this
    room = @get("room")
    if typeof @peerConnections[targetClientID] isnt "undefined" # don't create it twice!
      console.warn "Tried to create a peer connection, but we already had one for this target client.  This is probably a latent bug."
      return
    pc = @peerConnections[targetClientID] = new PeerConnection(stunIceConfig(), pcDataChannelConfig)

    # when we learn about our own ice candidates
    pc.onicecandidate = (event) ->
      if event.candidate
        self.socket.emit "ice_candidate:" + room,
          label: event.candidate.sdpMLineIndex
          candidate: event.candidate.candidate
          id: targetClientID

    pc.onopen = ->
      console.log "stream opened"

    pc.onaddstream = (event) =>
      console.log "remote stream added", targetClientID
      self.trigger "added_remote_stream",
        stream: event.stream
        socketID: targetClientID

    pc

  createPeerConnections: ->
    self = this
    _.each @peerIDs, (connection) ->
      self.createPeerConnection connection


  sendOffer: (socketId) ->
    console.log "Sending offers to ", socketId
    pc = @peerConnections[socketId]
    room = @get("room")
    self = this
    _.each self.localStreams, (stream) ->
      pc.addStream stream

    @createDataChannel(pc, "test", true)

    pc.createOffer ((description) ->

      # description.sdp = preferOpus(description.sdp); // alter sdp
      pc.setLocalDescription description

      # let the target client's socket know our SDP offering
      self.socket.emit "offer:" + room,
        id: socketId
        sdp: description

    ), ((err) ->
      console.error err
    ), sdpConstraints

  receiveOffer: (socketId, sdp) ->
    self = this
    pc = @createPeerConnection(socketId)
    _.each @localStreams, (stream) ->
      pc.addStream stream

    @createDataChannel(pc, "test", false)

    pc.setRemoteDescription new NativeRTCSessionDescription(sdp)
    pc.createAnswer ((session_description) ->
      pc.setLocalDescription session_description
      self.socket.emit "answer:" + self.get("room"),
        id: socketId
        sdp: session_description

    ), ((err) ->
      console.error err
    ), sdpConstraints

  receiveAnswer: (socketId, sdp) ->
    pc = @peerConnections[socketId]
    pc.setRemoteDescription new NativeRTCSessionDescription(sdp)

  requestClientStream: (opt, onSuccess, onFail) ->
    self = this
    options = undefined
    onSuccess = onSuccess or ->

    onFail = onFail or ->

    options =
      video: !!opt.video
      audio: !!opt.audio

    if getUserMedia
      getUserMedia.call navigator, options, ((stream) ->
        self.localStreams.push stream
        onSuccess stream
      ), (error) ->
        onFail error, "Could not connect to stream"

    else
      onFail null, "Your browser does not appear to support getUserMedia"

  addLocalStreamsToRemote: ->
    self = this
    streams = @localStreams
    pcs = @peerConnections
    _.each pcs, (pc, peer_id) ->
      _.each streams, (stream) ->
        pc.addStream stream



  attachStream: (stream, element) ->

    # element can be a dom element or a dom ele's ID
    element = document.getElementById(element)  if typeof (element) is "string"
    if ua.firefox
      element.mozSrcObject = stream
      element.play()
    else
      element.src = webkitURL.createObjectURL(stream)

  setUserMedia: (opts) ->
    _.each @localStreams, (stream) ->
      if opts.video?
        _.each stream.getVideoTracks(), (track) ->
          track.enabled = opts.video

      if opts.audio?
        _.each stream.getAudioTracks(), (track) ->
          track.enabled = opts.audio

  createDataChannel: (peerConnection, label, sender) ->
    if !supportsDataChannel
      console.error "Your browser does not support WebRTC data channels"
      return

    peerConnection.ondatachannel = (event) =>
      dataChannel = event.channel

      console.log "Received data channel: ", event
      @attachDataChannelEvents(dataChannel, label)

    if sender
      console.log "Initiating data channel"
      dataChannel = peerConnection.createDataChannel(label, {reliable: false})
      @attachDataChannelEvents(dataChannel, label)

  attachDataChannelEvents: (dataChannel, label) ->
    dataChannel.onerror = (error) ->
      console.error "DC:#{label} error:", error

    dataChannel.onmessage = (event) ->
      console.log "DC:#{label} rec:", event.data

    dataChannel.onopen = ->
      dataChannel.send("Hello World!")

    dataChannel.onclose = ->
      console.log "DC:#{label} closed"
