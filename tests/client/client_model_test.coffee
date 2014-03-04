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

    @fakeBob = new Backbone.Model
      nick: 'Bob'
      encrypted_nick:
        ct: 'BobCiphernick'
        iv: 'iv'
        s: 's'

    @fakeBob.getNick = ->
      return 'Bob'

    @fakeAlice = new Backbone.Model
      nick: 'Alice'
      encrypted_nick:
        ct: 'AliceCiphernick'
        iv: 'iv'
        s: 's'

    @fakeAlice.getNick = ->
      return 'Alice'

    @fake_armord_private = "
      -----BEGIN PGP PRIVATE KEY BLOCK-----
      Version: OpenPGP.js v0.4.0
      Comment: http://openpgpjs.org

      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
      YxtUzA==
      =I7HN
      -----END PGP PRIVATE KEY BLOCK-----
    "
    @fake_armored_public = "
      -----BEGIN PGP PUBLIC KEY BLOCK-----
      Version: OpenPGP.js v0.4.0
      Comment: http://openpgpjs.org

      xo0EUxO5WgEEANT7ESjhFHHGtnc01f705avi4YPl7E9kUZJCAxQUUlo+h2I4
      59bg/WKzGCrmA01OlwbSF3wJFEPfVWrb/VLmKIoqAsQv3rykJhbpGe9ocEo0
      uq89D2THbD2D68Xyre4P0KIXuqdn3+yFAb8ghPER6vy4yoPQv7WCeaoaPEl9
      2HsdABEBAAHNIUFub255bW91cyA8QW5vbnltb3VzQGVjaG9wbGV4LnVzPsKf
      BBABCAATBQJTE7lbCRBTzoJvoASYJQIbAwAAoDkEAK4oSw8c6AktVt4dJVXy
      b1tgW0WZBv03wWVTVrrd+OvHl236zRmSg2iAZOalTfR66tKUxgGhFUAXGM/h
      RJhMvXBxQ8yG8xIw+3nRJMNHKxMM9hzElCIfp96N1qGsRlCygE6xkHZYQf7g
      ngVAVLzKRoiomPBz5IQg7utZgCA14lMdzo0EUxO5WwEEAIN86EU1l9umOD1F
      UX/W3BU/sp5y9a7uGBkdDxiJQUgMt9t/PkcO3JtKYLH5E7SSWsnbDMq7cb7+
      iQr5MIN2P5/Qmh5PmGajmfF6gaGrF/ctyCA9gA1Ugt4/VKq0XPP1PjuEPXl4
      W7Rv4O8W2sOVzi90/Wdysvljs2jAY1VH3Rb/ABEBAAHCnwQYAQgAEwUCUxO5
      XAkQU86Cb6AEmCUCGwwAAO4zA/9QjPgSfvGqcytaHlmL3nDLwU5VENK0xkpF
      gzfmHMDDIKuGfQ2cSt+VTzX3f/x5ocilGfsvIiTXP3EOkBqldsxi0P5r/Com
      /G9adpSH6pb3x+MJKzNLRbsenDwo+5GBO0ASWgygCXoEuA+3B4HH4RRaDgOq
      nZDqizRPlkC/YxtUzA==
      =Bszq
      -----END PGP PUBLIC KEY BLOCK-----
    "


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

  describe '#authenticate_via_password', ->
    it 'should emit the correct event', ->
      @subject.authenticate_via_password('foobar')
      assert @fakeSocket.emit.calledWith('join_private:/', {password: 'foobar'})

  describe '#authenticate_via_token', ->
    it 'should emit the correct event', ->
      @subject.authenticate_via_token('foobar')
      assert @fakeSocket.emit.calledWith('join_private:/', {token: 'foobar'})

  describe '#sendEdit', ->
    it 'should emit the correct event', ->
      @subject.sendEdit(10, "oops")
      assert @fakeSocket.emit.calledWith("chat:edit:/", {mID: 10, body: "oops"})

  describe "#speak special commands", ->
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

    describe '/topic', ->
      beforeEach ->
        @subjectSays '/topic test'

      it 'fires a request', ->
        assert @fakeSocket.emit.calledWith('topic:/', {topic: 'test'})
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

  describe 'in pure plaintext', ->
    beforeEach ->
      @subject.unset 'cryptokey'
      @subject.pgp_settings =
        get: -> return false

    it 'emits to everyone with no encrypted body', ->
      @subjectSays "hi all"
      assert @fakeSocket.emit.calledOnce
      [event, msg] = @fakeSocket.emit.args[0]
      assert.equal "chat:/", event
      assert.equal "hi all", msg.body
      assert !msg.encrypted

    it 'sends a private directed_message only to the users we want to chat with', ->
      @subject.set 'peers', new Backbone.Collection([@fakeBob, @fakeAlice])
      @subjectSays "/w @Alice hi all"
      assert @fakeSocket.emit.calledOnce
      [event, msg] = @fakeSocket.emit.args[0]
      assert.equal "directed_message:/", event
      assert.equal "@Alice hi all", msg.body
      assert.equal "private", msg.class
      assert.equal "private", msg.type
      assert.equal true, msg.ack_requested
      assert !msg.encrypted
      # routes to the right guy?
      assert.deepEqual {"nick": "Alice"}, @fakeSocket.emit.args[0][1].directed_to

  describe 'while using a shared secret', ->
    beforeEach ->
      @subject.set 'cryptokey', 'some secret'

    describe 'with no PGP settings', ->
      beforeEach ->
        @subject.pgp_settings =
          get: -> return false

      it 'emits to everyone an encrypted body', ->
        @subjectSays 'hello there'
        assert @fakeSocket.emit.calledOnce
        [event, msg] = @fakeSocket.emit.args[0]
        assert.equal "chat:/", event
        assert.equal "-", msg.body
        assert msg.encrypted.ct
        assert msg.encrypted.iv
        assert msg.encrypted.s

      it 'sends a private directed_message only to the users we want to chat with', ->
        @subject.set 'peers', new Backbone.Collection([@fakeBob, @fakeAlice])

        @subjectSays '/w @Bob hello there'
        assert @fakeSocket.emit.calledOnce

        [event, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", event
        assert.equal "-", msg.body
        assert.equal "private", msg.class
        assert.equal "private", msg.type
        assert.equal true, msg.ack_requested
        assert msg.encrypted.ct
        assert msg.encrypted.iv
        assert msg.encrypted.s
        # routes to the right guy?
        assert.deepEqual {"ciphernick": 'BobCiphernick'}, @fakeSocket.emit.args[0][1].directed_to

      it 'sends a private message to all users that match the nick', ->

        @fakeAlice.getNick = -> return "Bob"

        @subject.set 'peers', new Backbone.Collection([@fakeBob, @fakeAlice])
        @subjectSays '/w @Bob hello there'
        assert @fakeSocket.emit.calledTwice

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal "-", msg.body
        assert.equal "private", msg.class
        assert.equal "private", msg.type
        assert.equal true, msg.ack_requested
        assert msg.encrypted.ct
        assert msg.encrypted.iv
        assert msg.encrypted.s
        # routes to the right guy?
        assert.deepEqual {"ciphernick": 'BobCiphernick'}, msg.directed_to

        [eventname, msg] = @fakeSocket.emit.args[1]
        assert.equal "directed_message:/", eventname
        assert.equal "-", msg.body
        assert.equal "private", msg.class
        assert.equal "private", msg.type
        assert.equal true, msg.ack_requested
        assert msg.encrypted.ct
        assert msg.encrypted.iv
        assert msg.encrypted.s
        # routes to the right guy?
        assert.deepEqual {"ciphernick": 'AliceCiphernick'}, msg.directed_to

    describe 'while using a PGP key with no passphrase', ->
      describe 'and signing only', ->
        beforeEach ->
          @subject.pgp_settings =
            get: (key) ->
              return true if key == "sign?"
              return false
            prompt: (cb) -> cb?()
            sign: (message, cb) -> cb?("signed~~~message")

        it 'should sign the message', ->
          signMessage = stub(@subject, 'signMessage')
          @subjectSays "hello"

          assert signMessage.called

        it 'should sign the message and send a directed_message when whispering', ->
          signMessage = spy(@subject, 'signMessage')
          @subject.set 'peers', new Backbone.Collection([@fakeBob, @fakeAlice])

          @subjectSays "/w @Alice hello"

          assert signMessage.calledOnce, "signMessage never called!"
          assert @fakeSocket.emit.calledOnce, "emit not called twice"

          [eventname, msg] = @fakeSocket.emit.args[0]
          assert.equal "directed_message:/", eventname
          assert.equal false, msg.pgp_encrypted
          assert.equal true, msg.pgp_signed
          assert.equal "-", msg.body
          assert msg.encrypted
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.deepEqual {"ciphernick": "AliceCiphernick"}, msg.directed_to

        it 'should sign the message and send a directed_message to all users that match the nickname when whispering', ->
          signMessage = spy(@subject, 'signMessage')
          @fakeBob.nick = "Alice"
          @fakeBob.getNick = -> return "Alice"

          @subject.set 'peers', new Backbone.Collection([@fakeBob, @fakeAlice])

          @subjectSays "/w @Alice hello"

          assert signMessage.calledOnce, "signMessage never called!"
          assert @fakeSocket.emit.calledTwice, "emit not called twice"

          [eventname, msg] = @fakeSocket.emit.args[0]
          assert.equal "directed_message:/", eventname
          assert.equal false, msg.pgp_encrypted
          assert.equal true, msg.pgp_signed
          assert.equal "-", msg.body
          assert msg.encrypted
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.deepEqual {"ciphernick": "BobCiphernick"}, msg.directed_to

          [eventname, msg] = @fakeSocket.emit.args[1]
          assert.equal "directed_message:/", eventname
          assert.equal false, msg.pgp_encrypted
          assert.equal true, msg.pgp_signed
          assert.equal "-", msg.body
          assert msg.encrypted
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.deepEqual {"ciphernick": "AliceCiphernick"}, msg.directed_to

      describe 'and encrypting only', ->
        beforeEach ->
          @subject.pgp_settings =
            get: (key) ->
              return true if key == "encrypt?"
              return false
            prompt: (cb) -> cb?()
            encrypt: stub().returns "encrypted~~~message"

        it 'should encrypt the message, sending it directed_to the fingerprints we trust', ->
          @subject.getPGPPeers = ->
            return [{fingerprint: 'A'}, {fingerprint: 'B'}]

          @subjectSays 'hello'

          assert @fakeSocket.emit.calledTwice, "emit was not called twice"
          assert @subject.pgp_settings.encrypt.calledTwice, "encrypt was not called twice"

          [eventname, msg] = @fakeSocket.emit.args[0]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal false, msg.pgp_signed
          assert.equal "-", msg.body
          assert msg.encrypted
          assert.deepEqual {"fingerprint": "A"}, msg.directed_to

          [eventname, msg] = @fakeSocket.emit.args[1]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal false, msg.pgp_signed
          assert.equal "-", msg.body
          assert msg.encrypted
          assert.deepEqual {"fingerprint": "B"}, msg.directed_to

        it 'should encrypt and send the message only to the user nick that was specified when whispering', ->
          @subject.getPGPPeers = ->
            return [{fingerprint: 'A', nick: 'Alice'}]
          @subject.getCiphernicksMatching = ->
            return ['AliceCiphernick']

          @subjectSays '/w @Alice hello Alice'

          assert @fakeSocket.emit.calledOnce, "Emitted too many messages!"
          assert @subject.pgp_settings.encrypt.calledOnce, "Encrypted too many times; this could be slow"

          [eventname, msg] = @fakeSocket.emit.args[0]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal false, msg.pgp_signed
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.deepEqual {"fingerprint": "A"}, msg.directed_to

        it 'should encrypt and send the message to all users whos nicks match when whispering', ->
          @subject.getPGPPeers = ->
            return [{fingerprint: 'A', nick: 'Alice'}, {fingerprint: 'B', nick: 'Alice'}]

          @subjectSays '/w @Alice hello Alice'

          assert @fakeSocket.emit.calledTwice
          assert @subject.pgp_settings.encrypt.calledTwice

          [eventname, msg] = @fakeSocket.emit.args[0]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal false, msg.pgp_signed
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.deepEqual {"fingerprint": "A"}, msg.directed_to

          [eventname, msg] = @fakeSocket.emit.args[1]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal false, msg.pgp_signed
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.deepEqual {"fingerprint": "B"}, msg.directed_to

      describe 'while signing & encrypting', ->
        beforeEach ->
          @subject.pgp_settings =
            get: (key) ->
              return true if key == "encrypt?"
              return true if key == "sign?"
              return false
            prompt: (cb) -> cb?()
            encryptAndSign: (peer_armored_public_key, msg_body, cb) -> cb?('signed~~~encrypted')

        it 'should encrypt and sign the message, sending it directed_to the fingerprints we trust', ->
          @subject.getPGPPeers = ->
            return [{fingerprint: 'A'}, {fingerprint: 'B'}]

          @subjectSays 'hello'

          assert @fakeSocket.emit.calledTwice
          #assert @subject.pgp_settings.encrypt.calledTwice

          [eventname, msg] = @fakeSocket.emit.args[0]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal true, msg.pgp_signed
          assert.notEqual "hello", msg.body
          assert.deepEqual {"fingerprint": "A"}, msg.directed_to

          [eventname, msg] = @fakeSocket.emit.args[1]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal true, msg.pgp_signed
          assert.notEqual "hello", msg.body
          assert.deepEqual {"fingerprint": "B"}, msg.directed_to

        it 'should encrypt and sign the message, sending it directed_to only nicks that we specified while whispering', ->
          @subject.getPGPPeers = ->
            return [{fingerprint: 'B', nick: 'Bob'}]

          @subjectSays '/w Bob hello'

          assert @fakeSocket.emit.calledOnce
          #assert @subject.pgp_settings.encrypt.calledTwice

          [eventname, msg] = @fakeSocket.emit.args[0]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal true, msg.pgp_signed
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.notEqual "hello", msg.body
          assert.deepEqual {"fingerprint": "B"}, msg.directed_to

        it 'should encrypt and sign the message, sending it directed_to all nicks that match what we specified while whispering', ->
          @subject.getPGPPeers = ->
            return [{fingerprint: 'A', nick: 'Alice'}, {fingerprint: 'B', nick: 'Alice'}]

          @subjectSays '/w Alice hello'

          assert @fakeSocket.emit.calledTwice

          [eventname, msg] = @fakeSocket.emit.args[0]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal true, msg.pgp_signed
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.notEqual "hello", msg.body
          assert.deepEqual {"fingerprint": "A"}, msg.directed_to

          [eventname, msg] = @fakeSocket.emit.args[1]
          assert.equal "directed_message:/", eventname
          assert.equal true, msg.pgp_encrypted
          assert.equal true, msg.pgp_signed
          assert.equal "private", msg.type
          assert.equal "private", msg.class
          assert.notEqual "hello", msg.body
          assert.deepEqual {"fingerprint": "B"}, msg.directed_to



  describe 'while using a PGP key with no passphrase', ->
    describe 'and signing only', ->
      beforeEach ->
        @subject.pgp_settings =
          get: (key) ->
            return true if key == "sign?"
            return false
          prompt: (cb) -> cb?()
          sign: (message, cb) -> cb?("signed~~~message")

      it 'should sign the message', ->
        signMessage = stub(@subject, 'signMessage')
        @subjectSays "hello"

        assert signMessage.called

      it 'should sign the message and send a directed_message when whispering', ->
        signMessage = spy(@subject, 'signMessage')
        @subject.set 'peers', new Backbone.Collection([@fakeBob, @fakeAlice])

        @subjectSays "/w @Alice hello"

        assert signMessage.called, "signMessage never called!"
        assert @fakeSocket.emit.calledOnce

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal false, msg.pgp_encrypted
        assert.equal true, msg.pgp_signed
        assert.equal "private", msg.type
        assert.equal "private", msg.class
        assert.deepEqual {"nick": "Alice"}, msg.directed_to

      it 'should sign the message and send a directed_message to all users that match the nickname when whispering', ->
        signMessage = spy(@subject, 'signMessage')
        @fakeBob.getNick = -> return "Alice"

        @subject.set 'peers', new Backbone.Collection([@fakeBob, @fakeAlice])

        @subjectSays "/w @Alice hello"

        assert signMessage.calledOnce, "signMessage never called!"
        assert @fakeSocket.emit.calledOnce

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal false, msg.pgp_encrypted
        assert.equal true, msg.pgp_signed
        assert.equal "private", msg.type
        assert.equal "private", msg.class
        assert.deepEqual {"nick": "Alice"}, msg.directed_to

    describe 'and encrypting only', ->
      beforeEach ->
        @subject.pgp_settings =
          get: (key) ->
            return true if key == "encrypt?"
            return false
          prompt: (cb) -> cb?()
          encrypt: stub().returns "encrypted~~~message"

      it 'should encrypt the message, sending it directed_to the fingerprints we trust', ->
        @subject.getPGPPeers = ->
          return [{fingerprint: 'A'}, {fingerprint: 'B'}]

        @subjectSays 'hello'

        assert @fakeSocket.emit.calledTwice
        assert @subject.pgp_settings.encrypt.calledTwice

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal false, msg.pgp_signed
        assert.deepEqual {"fingerprint": "A"}, msg.directed_to

        [eventname, msg] = @fakeSocket.emit.args[1]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal false, msg.pgp_signed
        assert.deepEqual {"fingerprint": "B"}, msg.directed_to

      it 'should encrypt and send the message only to the user nick that was specified when whispering', ->
        @subject.getPGPPeers = ->
          return [{fingerprint: 'A', nick: 'Alice'}]

        @subjectSays '/w @Alice hello Alice'

        assert @fakeSocket.emit.calledOnce, "Emitted too many messages!"
        assert @subject.pgp_settings.encrypt.calledOnce, "Encrypted too many times; this could be slow"

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal false, msg.pgp_signed
        assert.equal "private", msg.type
        assert.equal "private", msg.class
        assert.deepEqual {"fingerprint": "A"}, msg.directed_to

      it 'should encrypt and send the message to all users whos nicks match when whispering', ->
        @subject.getPGPPeers = ->
          return [{fingerprint: 'A', nick: 'Alice'}, {fingerprint: 'B', nick: 'Alice'}]

        @subjectSays '/w @Alice hello Alice'

        assert @fakeSocket.emit.calledTwice

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal false, msg.pgp_signed
        assert.equal "private", msg.type
        assert.equal "private", msg.class
        assert.deepEqual {"fingerprint": "A"}, msg.directed_to

        [eventname, msg] = @fakeSocket.emit.args[1]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal false, msg.pgp_signed
        assert.equal "private", msg.type
        assert.equal "private", msg.class
        assert.deepEqual {"fingerprint": "B"}, msg.directed_to

    describe 'while signing & encrypting', ->
      beforeEach ->
        @subject.pgp_settings =
          get: (key) ->
            return true if key == "encrypt?"
            return true if key == "sign?"
            return false
          prompt: (cb) -> cb?()
          encryptAndSign: (peer_armored_public_key, msg_body, cb) -> cb?('signed~~~encrypted')

      it 'should encrypt and sign the message, sending it directed_to the fingerprints we trust', ->
        @subject.getPGPPeers = ->
          return [{fingerprint: 'A'}, {fingerprint: 'B'}]

        @subjectSays 'hello'

        assert @fakeSocket.emit.calledTwice
        #assert @subject.pgp_settings.encrypt.calledTwice

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal true, msg.pgp_signed
        assert.notEqual "hello", msg.body
        assert.deepEqual {"fingerprint": "A"}, msg.directed_to

        [eventname, msg] = @fakeSocket.emit.args[1]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal true, msg.pgp_signed
        assert.notEqual "hello", msg.body
        assert.deepEqual {"fingerprint": "B"}, msg.directed_to

      it 'should encrypt and sign the message, sending it directed_to only nicks that we specified while whispering', ->
        @subject.getPGPPeers = ->
          return [{fingerprint: 'B', nick: 'Bob'}]


        @subjectSays '/w Bob hello'

        assert @fakeSocket.emit.calledOnce

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal true, msg.pgp_signed
        assert.equal "private", msg.type
        assert.equal "private", msg.class
        assert.notEqual "hello", msg.body
        assert.deepEqual {"fingerprint": "B"}, msg.directed_to

      it 'should encrypt and sign the message, sending it directed_to all nicks that match what we specified while whispering', ->
        @subject.getPGPPeers = ->
          return [{fingerprint: 'A', nick: 'Alice'}, {fingerprint: 'B', nick: 'Alice'}]

        @subjectSays '/w Alice hello'

        assert @fakeSocket.emit.calledTwice

        [eventname, msg] = @fakeSocket.emit.args[0]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal true, msg.pgp_signed
        assert.equal "private", msg.type
        assert.equal "private", msg.class
        assert.notEqual "hello", msg.body
        assert.deepEqual {"fingerprint": "A"}, msg.directed_to

        [eventname, msg] = @fakeSocket.emit.args[1]
        assert.equal "directed_message:/", eventname
        assert.equal true, msg.pgp_encrypted
        assert.equal true, msg.pgp_signed
        assert.equal "private", msg.type
        assert.equal "private", msg.class
        assert.notEqual "hello", msg.body
        assert.deepEqual {"fingerprint": "B"}, msg.directed_to
