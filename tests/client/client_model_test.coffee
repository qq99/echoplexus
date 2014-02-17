client      = require('../../src/client/client.js.coffee')
ClientModel  = client.ClientModel

describe 'ClientModel', ->
  beforeEach ->
    window.events =
      trigger: stub()

    $.cookie = stub()
    $.removeCookie = stub()
    @fakeSocket =
      emit: stub()

    @subject = new ClientModel
      socket: @fakeSocket
      room: '/'

    @subjectSays = (string) =>
      @subject.speak({
        body: string
      })

  describe 'constructors', ->
    it 'should create a new Permissions model attribute on creation', ->
      assert @subject.get('permissions')
    it 'should create a new Color model attribute on creation if not supplied', ->
      assert @subject.get('color')
    it 'should instantiate a Color model with optional params if supplied', ->
      fakeColor = {r: 3, g: 10, b: 0}
      @subject = new ClientModel color: fakeColor
      assert.equal fakeColor.r, @subject.get('color').get('r')

  describe '#is', ->
    it 'should check the model.id for identity', ->
      @other = new ClientModel
      @other.set('id', 1)
      @subject.set('id', 2)


      assert !@other.is(@subject), "Other client has same ID as subject client"
      assert @subject.is(@subject)

  describe '#identify', ->
    it 'should emit the correct event', ->
      @subject.identify('foobar')
      assert @fakeSocket.emit.calledWith('identify:/', {password: 'foobar'})

  describe '#identify_via_token', ->
    it 'should emit the correct event', ->
      @subject.identify_via_token('foobar')
      assert @fakeSocket.emit.calledWith('verify_identity_token:/', {token: 'foobar'})

  describe '#authenticate_via_password', ->
    it 'should emit the correct event', ->
      @subject.authenticate_via_password('foobar')
      assert @fakeSocket.emit.calledWith('join_private:/', {password: 'foobar'})

  describe '#authenticate_via_token', ->
    it 'should emit the correct event', ->
      @subject.authenticate_via_token('foobar')
      assert @fakeSocket.emit.calledWith('join_private:/', {token: 'foobar'})

  describe '#sendPrivateMessage', ->
    it 'should emit the correct event', ->
      @subject.sendPrivateMessage("Bob", "What's up?")
      assert @fakeSocket.emit.calledWith('private_message:/', {directedAt: 'Bob', body: "What's up?"})

  describe '#sendEdit', ->
    it 'should emit the correct event', ->
      @subject.sendEdit(10, "oops")
      assert @fakeSocket.emit.calledWith("chat:edit:/", {mID: 10, body: "oops"})

  describe "#speak", ->
    describe '/nick', ->
      beforeEach ->
        @subjectSays '/nick Foobar'

      it 'fires a request to change the nickname', ->
        assert.equal true, @fakeSocket.emit.calledWith('nickname:/')
        assert @fakeSocket.emit.calledOnce
      it 'should immediately update the nickname cookie', ->
        assert $.cookie.calledWith('nickname:/', 'Foobar')
      it 'should immediately clear any identity password cookie associated with the nickname', ->
        assert $.removeCookie.calledWith('ident_pw:/')

    describe '/private', ->
      beforeEach ->
        @subjectSays '/private Super secret password'

      it 'fires a request to update the channel password', ->
        assert @fakeSocket.emit.calledWith('make_private:/', {password: "Super secret password"})
        assert @fakeSocket.emit.calledOnce
      it 'should not remember the channel password', ->
        assert.equal false, $.cookie.called

    describe '/public', ->
      beforeEach ->
        @subjectSays '/public'

      it 'fires a request to make the channel public', ->
        assert @fakeSocket.emit.calledWith('make_public:/')
        assert @fakeSocket.emit.calledOnce

    describe '/register', ->
      beforeEach ->
        @subjectSays '/register mynickpw'

      it 'fires a request', ->
        assert @fakeSocket.emit.calledWith('register_nick:/', {password: 'mynickpw'})
        assert @fakeSocket.emit.calledOnce
      it 'does not remember the nick pw', ->
        assert.equal false, $.cookie.called

    describe '/identify', ->
      beforeEach ->
        @subjectSays '/identify mynickpw'

      it 'fires a request', ->
        assert @fakeSocket.emit.calledWith('identify:/', {password: 'mynickpw'})
        assert @fakeSocket.emit.calledOnce
      it 'does not remember the nick pw', ->
        assert.equal false, $.cookie.called

    describe '/topic', ->
      beforeEach ->
        @subjectSays '/topic test'

      it 'fires a request', ->
        assert @fakeSocket.emit.calledWith('topic:/', {topic: 'test'})
        assert @fakeSocket.emit.calledOnce

    describe '/tell', ->
      it 'fires a request', ->
        @subjectSays '/tell qq99 hey yo'
        assert @fakeSocket.emit.calledWith('private_message:/', {body: 'qq99 hey yo', directedAt: 'qq99'})
        assert @fakeSocket.emit.calledOnce

      it 'works when the recipient name is prefixed with @', ->
        @subjectSays '/tell @qq99 hey yo'
        assert @fakeSocket.emit.calledWith('private_message:/', {body: '@qq99 hey yo', directedAt: 'qq99'})
        assert @fakeSocket.emit.calledOnce

    describe '/color', ->
      it 'fires a request', ->
        @subjectSays '/color #fff'
        assert @fakeSocket.emit.calledWith('user:set_color:/', {userColorString: '#fff'})
        assert @fakeSocket.emit.calledOnce

    describe '/edit', ->
      it 'fires a request', ->
        @subjectSays '/edit #555 my new text'
        assert @fakeSocket.emit.calledWith('chat:edit:/', {mID: "555", body: 'my new text'})
        assert @fakeSocket.emit.calledOnce

    describe '/chown', ->
      beforeEach ->
        @subjectSays '/chown channel_owner_p@ssw0rd'

      it 'fires a request', ->
        assert @fakeSocket.emit.calledWith('chown:/', {key: "channel_owner_p@ssw0rd"})
        assert @fakeSocket.emit.calledOnce

      it 'does not attempt to save this value in a cookie', ->
        assert not $.cookie.called

    describe '/leave', ->
      it 'should trigger an event', ->
        @subjectSays '/leave'

        assert window.events.trigger.calledWith("leave:/")
        assert not @fakeSocket.emit.called

    describe '/chmod', ->
      it 'fires a request', ->
        @subjectSays '/chmod +canSetTopic'
        assert @fakeSocket.emit.calledWith('chmod:/', {body: "+canSetTopic"})
        assert @fakeSocket.emit.calledOnce

    describe '/broadcast', ->
      it 'fires an event on the eventbus', ->
        @subjectSays '/broadcast Hey all channels'
        assert not @fakeSocket.emit.called
        assert window.events.trigger.calledWith("chat:broadcast", {body: 'Hey all channels'})

    describe '/help', ->
      it 'fires a request', ->
        @subjectSays '/help'

        assert @fakeSocket.emit.calledWith('help:/')
        assert @fakeSocket.emit.calledOnce
