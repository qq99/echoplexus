ChatClient        = require('../../../../src/client/modules/chat/client.js.coffee').ChatClient
Client            = require('../../../../src/client/client.js.coffee')
ColorModel        = Client.ColorModel
ClientModel       = Client.ClientModel
ClientsCollection = Client.ClientsCollection

describe 'ChatClient', ->
  beforeEach ->

    window.GlobalUIState = new Backbone.Model
      chatIsPinned: false

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

    @channel = new Backbone.Model
      clients: new ClientsCollection()
      modules: []
      authenticated: false
      isPrivate: false
      cryptokey: ''

  describe '#initialize', ->
    beforeEach ->
      @subject = new ChatClient
        channel: @channel
        room: "/foo"
        config:
          host: 'http://localhost'

    it 'creates an object representing me as a user', ->
      assert @subject.me
      assert.equal @fakeSocket, @subject.me.get("socket")
      assert.equal "/foo", @subject.me.get("room")
      assert.equal 0, @subject.me.get("peers").length

    it 'creates a ChatAreaView', ->
      assert @subject.chatLog
      assert.equal "/foo", @subject.chatLog.room
      assert.equal @subject.me, @subject.chatLog.me

    it 'attempts to subscribe', ->
      assert @fakeSocket.emit.calledWith("subscribe")

  describe '#listen', ->
    beforeEach ->
      @subject = new ChatClient
        channel: @channel
        room: "/foo"
        config:
          host: 'http://localhost'

    it 'attempts to listen to certain namespaced socket events', ->
      socketEvents = [
        'chat',
        'chat:batch',
        'client:changed',
        'client:removed',
        'private_message',
        'webshot',
        'subscribed',
        'chat:edit',
        'client:id',
        'token',
        'userlist',
        'chat:currentID',
        'topic',
        'antiforgery_token',
        'file_uploaded'
      ]

      @fakeSocket.on.callCount = 0
      @subject.listen()

      _.each socketEvents, (eventName) =>
        assert @fakeSocket.on.calledWith("#{eventName}:/foo")

      assert.equal socketEvents.length, @fakeSocket.on.callCount
