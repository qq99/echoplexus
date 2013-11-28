client      = require('../../src/client/client.js.coffee')
ClientModel  = client.ClientModel

describe 'ClientModel', ->
  beforeEach ->
    @subject = new ClientModel
    window.events =
      trigger: stub()

    $.cookie = stub()
    $.removeCookie = stub()
    @fakeSocket =
      emit: stub()

    @subject.socket = @fakeSocket

    @subjectSays = (string) =>
      @subject.speak({
        body: string,
        room: '/'
      }, @fakeSocket)

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

  describe "#speak", ->
    describe '/nick', ->
      beforeEach ->
        @subjectSays '/nick Foobar'

      it 'fires a request to change the nickname', ->
        assert @fakeSocket.emit.calledWith('nickname:/')
        assert @fakeSocket.emit.neverCalledWith('chat:/')
      it 'should immediately update the nickname cookie', ->
        assert $.cookie.calledWith('nickname:/', 'Foobar')
      it 'should immediately clear any identity password cookie associated with the nickname', ->
        assert $.removeCookie.calledWith('ident_pw:/')

    describe '/private', ->
      beforeEach ->
        @subjectSays '/private Super secret password'

      it 'fires a request to update the channel password', ->
        assert @fakeSocket.emit.calledWith('make_private:/', {password: "Super secret password", room: "/"})
        assert @fakeSocket.emit.neverCalledWith('chat:/')
      it 'should update the channel password cookie', ->
        assert $.cookie.calledWith('channel_pw:/', 'Super secret password')

    describe '/leave', ->
      it 'should trigger an event on the global eventbus', ->
        @subjectSays '/leave'

        assert window.events.trigger.calledWith("leave:/")
        assert !@fakeSocket.emit.called

    describe '/help', ->
      it 'fires a request', ->
        @subjectSays '/help'

        assert @fakeSocket.emit.calledWith('help:/')
