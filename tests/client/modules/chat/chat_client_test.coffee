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

  describe 'instance methods', ->
    beforeEach ->
      @subject = new ChatClient
        channel: @channel
        room: "/foo"
        config:
          host: 'http://localhost'

    describe '#listen', ->

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

    describe '#attachEvents', ->

      it 'listens on the eventbus for a namespaced set of events', ->
        namespacedEvents = [
          'private',
          'channelPassword',
          'beginEdit',
          'edit:commit',
          'in_call',
          'left_call'
        ]
        nonNamespacedEvents = [
          'unidle',
          'chat:broadcast'
        ]

        window.events.on.callCount = 0
        @subject.attachEvents()

        calledEvents = window.events.on.args.map (el) ->
          el[0]

        _.each namespacedEvents, (eventName) =>
          assert calledEvents.indexOf("#{eventName}:/foo") != -1, "Did not listen for namespaced event #{eventName}:/foo"

        _.each nonNamespacedEvents, (eventName) =>
          assert calledEvents.indexOf("#{eventName}") != -1, "Did not listen for non-namespaced event #{eventName}"

        assert.equal namespacedEvents.concat(nonNamespacedEvents).length, window.events.on.callCount

    describe '#activelySyncLogs', ->

      it 'does nothing if there were no messages unknown', ->
        @fakeSocket.emit.callCount = 0
        @subject.activelySyncLogs()

        assert.equal 0, @fakeSocket.emit.callCount

      it 'emits an event if messages were missed', ->
        @subject.persistentLog.getMissingIDs = stub().returns([1,2,3])

        @subject.activelySyncLogs()

        assert @fakeSocket.emit.calledWith("chat:history_request:/foo", {requestRange: [1,2,3]})

    describe '#logOut', ->

      it 'clears all cookies', ->
        @subject.logOut()

        cookies = ["nickname", "token:identity", "token:authentication"]

        _.each cookies, (cookie) ->
          assert $.cookie.calledWith("#{cookie}:/foo", null)

        assert cookies.length, $.cookie.callCount

      it 'deletes local storage', ->
        @subject.deleteLocalStorage = stub()

        @subject.logOut()

        assert @subject.deleteLocalStorage.called

      it 'clears the cryptokey', ->
        @subject.clearCryptoKey = stub()

        @subject.logOut()

        assert @subject.clearCryptoKey.called

      it 'leaves the channel', ->
        @subject.logOut()
        assert window.events.trigger.calledWith("leaveChannel", "/foo")

    describe '#deleteLocalStorage', ->
      it 'tells the persistent log to destroy itself', ->
        @subject.persistentLog.destroy = stub()

        @subject.deleteLocalStorage()

        assert @subject.persistentLog.destroy.called

      it 'tells the chat area to clear itself', ->
        @subject.chatLog.clearChat = stub()
        @subject.chatLog.medialog.clearMediaContents = stub()
        @subject.deleteLocalStorage()

        assert @subject.chatLog.clearChat.called
        assert @subject.chatLog.medialog.clearMediaContents.called

    describe '#clearCryptoKey', ->
      it 'clears the key from myself and the channel object', ->

        @subject.me.set "cryptokey", "my secret"
        @subject.channel.set "cryptokey", "my secret"

        @subject.clearCryptoKey()

        assert.equal undefined, @subject.me.get("cryptokey")
        assert.equal undefined, @subject.channel.get("cryptokey")

      it 'destroys the key from localStorage', ->
        window.localStorage.setItem = stub()

        @subject.clearCryptoKey()
        assert window.localStorage.setItem.calledWith("chat:cryptokey:/foo", "")

      it 're-renders the text input box', ->
        @subject.rerenderInputBox = stub()
        @subject.clearCryptoKey()
        assert @subject.rerenderInputBox.called

      it 'unsets my nick, and sets it to Anonymous for security', ->
        @subject.clearCryptoKey()

        assert.equal undefined, @subject.me.get("encrypted_nick")
        assert.equal "Anonymous", @subject.me.get("nick")

    describe '#show', ->
      it 'sets .hidden to false', ->
        @subject.show()
        assert.equal false, @subject.hidden

    describe '#hide', ->
      it 'sets .hidden to true', ->
        @subject.hide()
        assert.equal true, @subject.hidden

    describe '#channelIsPrivate', ->
      it 'sets .isPrivate on the channel', ->
        @subject.channelIsPrivate()
        assert.equal true, @subject.channel.isPrivate

      it 'shows an overlay if the channel is active', ->
        window.showPrivateOverlay = stub()

        @subject.show()
        @subject.channelIsPrivate()

        assert window.showPrivateOverlay.called

      it 'does not show an overlay if the channel is not active', ->
        window.showPrivateOverlay = stub()

        @subject.hide()
        @subject.channelIsPrivate()

        assert.equal false, window.showPrivateOverlay.called

      it 'attempts to automatically authenticate', ->
        @subject.autoAuth = stub()

        @subject.channelIsPrivate()

        assert @subject.autoAuth.called

    describe '#autoAuth', ->
      it 'attempts to authenticate using a token', ->
        @subject.authenticate = stub()
        $.cookie = stub().returns("some token")

        @subject.autoAuth()

        assert $.cookie.calledWith("token:authentication:/foo")
        assert @subject.authenticate.calledWith({token: "some token"})

    describe '#authenticate', ->
      it 'attempts to authenticate using a token if a token is provided', ->
        @subject.me.authenticate_via_token = stub()

        promise = @subject.authenticate({token: 'some token'})

        assert @subject.me.authenticate_via_token.calledWithMatch('token')

      it 'attempts to authenticate using a password if a password is provided', ->
        @subject.me.authenticate_via_password = stub()

        promise = @subject.authenticate({password: 'my secret'})

        assert @subject.me.authenticate_via_password.calledWithMatch('my secret')

      it 'shows an error when no password or token was supplied, or authentication was unsuccessful', ->
        authResult = $.Deferred()
        window.hidePrivateOverlay = stub()
        window.showPrivateOverlay = stub()

        dfrdStub = stub($, 'Deferred').returns(authResult)

        @subject.show()
        @subject.authenticate({})

        authResult.reject(null, "Error")

        assert showPrivateOverlay.called

        dfrdStub.restore()

      it 'marks channel as authenticated and hides overlay when authentication succeeds', ->
        authResult = $.Deferred()
        window.hidePrivateOverlay = stub()

        dfrdStub = stub($, 'Deferred').returns(authResult)

        @subject.authenticate({password: 'my secret'})
        authResult.resolve()

        assert.equal true, @subject.channel.authenticated
        assert hidePrivateOverlay.called

        dfrdStub.restore()
