CallClient = require('../../../../src/client/modules/call/client.js.coffee').CallClient

describe 'CallClient', ->
  beforeEach ->
    window.events =
      trigger: stub()
      on: stub()

    @fakeSocket =
      emit: stub()
      on: stub()
      removeAllListeners: stub()
    window.io =
      connect: stub().returns(@fakeSocket)

    $.cookie = stub()
    $.removeCookie = stub()

    @opts =
      config:
        host: 'localhost'
      room: '/'
      channel:
        clients: new Backbone.Collection
        isPrivate: false

  describe '#initialize', ->
    beforeEach ->
      @subject = new CallClient(@opts)

    it 'creates a new instance of RTC', ->
      assert @subject.rtc
      assert.equal @fakeSocket, @subject.rtc.socket
      assert.equal '/', @subject.rtc.room

    it 'binds events to hide and show', ->
      assert.equal undefined, @subject.$el.attr("style")

      @subject.trigger("hide")
      assert.equal "display: none;", @subject.$el.attr("style")

      @subject.trigger("show")
      assert.equal "display: block;", @subject.$el.attr("style")

  describe '#listen', ->
    beforeEach ->
      @subject = new CallClient(@opts)

    it 'listens to 2 events from RTC', ->
      spy(@subject.rtc, "on")
      @subject.listen()

      assert @subject.rtc.on.calledWith("added_remote_stream")
      assert @subject.rtc.on.calledWith("disconnected_stream")

    it 'binds socket events', ->
      @subject.listen()

      assert @fakeSocket.on.calledWith("status:/")

  describe '#disconnect', ->
    beforeEach ->
      @subject = new CallClient(@opts)

    it 'clears the video area', ->
      $(".videos", @subject.$el).html "<video></video>"

      @subject.disconnect()

      assert.equal "", $(".videos", @subject.$el).html()

    it 'stops the local stream if there is one', ->
      @subject.localStream =
        stop: stub()

      @subject.disconnect()
      assert @subject.localStream.stop.called

    it 'triggers a request to stop streaming audio and video', ->
      spy(@subject.rtc, "setUserMedia")
      @subject.disconnect()

      assert @subject.rtc.setUserMedia.calledWith({audio: false, video: false})

    it 'triggers a request to RTC to disconnect', ->
      spy(@subject.rtc, 'disconnect')
      @subject.disconnect()

      assert @subject.rtc.disconnect.called

  describe '#kill', ->
    beforeEach ->
      @subject = new CallClient(@opts)

    it 'calls #disconnect', ->
      spy(@subject, 'disconnect')
      @subject.kill()

      assert @subject.disconnect.called

    it 'removes all bound events on the socket', ->
      @subject.kill()

      assert @fakeSocket.removeAllListeners.calledWith("status:/")

    it 'emits an unsubscribe event on the socket', ->
      @subject.kill()

      assert @fakeSocket.emit.calledWith("unsubscribe:/")

  describe "#render", ->
    it 'populates the $el', ->
      @subject = new CallClient(@opts)
      @subject.render()

      assert.notEqual "", @subject.$el.html()

  describe '#getNumPerRow', ->
    beforeEach ->
      @subject = new CallClient(@opts)

    it 'returns 1 for 1 videos', ->
      @subject.videos = [1]
      assert.equal 1, @subject.getNumPerRow()

    it 'returns 2 for 2 videos', ->
      @subject.videos = [0,1]
      assert.equal 2, @subject.getNumPerRow()

    it 'returns 2 for 3 videos', ->
      @subject.videos = [0,1,2]
      assert.equal 2, @subject.getNumPerRow()

    it 'returns 2 for 4 videos', ->
      @subject.videos = [0,1,2,3]
      assert.equal 2, @subject.getNumPerRow()

    it 'returns 3 for 5 videos', ->
      @subject.videos = [0,1,2,3,4]
      assert.equal 3, @subject.getNumPerRow()

    it 'returns 3 for 6 videos', ->
      @subject.videos = [0,1,2,3,4,5]
      assert.equal 3, @subject.getNumPerRow()

    it 'returns 4 for 7 videos', ->
      @subject.videos = [0,1,2,3,4,5,6]
      assert.equal 4, @subject.getNumPerRow()

    it 'returns 4 for 8 videos', ->
      @subject.videos = [0,1,2,3,4,5,6,7]
      assert.equal 4, @subject.getNumPerRow()

  describe '#setWH', ->
    beforeEach ->
      @subject = new CallClient(@opts)
      @container = $(".videos", @subject.$el)
      @container.css
        width: "500px"
        height: "1000px"
      @videoEl = $("<video></video>")

    it 'sets a nice width and height (2 videos on 1 row) when there are 2 videos', ->
      @subject.videos = [0,0]
      @subject.setWH(@videoEl, 0, 2)

      assert.equal 250, @videoEl.width()
      assert.equal 1000, @videoEl.height()

    it 'sets a nice width and height (the entire area) when there is 1 video', ->
      @subject.videos = [0]
      @subject.setWH(@videoEl, 0, 1)

      assert.equal 500, @videoEl.width()
      assert.equal 1000, @videoEl.height()


