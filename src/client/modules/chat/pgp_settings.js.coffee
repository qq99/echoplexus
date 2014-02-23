module.exports.PGPSettings = class PGPSettings extends Backbone.Model
  initialize: (opts) ->
    # requires channelName
    _.bindAll this
    _.extend this, opts

    this.on "change:armored_keypair", (model, armored_keypair) ->
      priv = openpgp.key.readArmored(armored_keypair?.private)
      pub = openpgp.key.readArmored(armored_keypair?.public)
      uid = priv.keys[0]?.users[0]?.userId?.userid
      fingerprint = priv.keys[0]?.primaryKey?.getFingerprint()
      @set 'user_id', uid if uid
      @set 'fingerprint', fingerprint if fingerprint

    @set 'armored_keypair', localStorage.getObj "pgp:keypair:#{@channelName}"
    @set 'sign?', localStorage.getObj "pgp:sign?:#{@channelName}"
    @set 'encrypt?', localStorage.getObj "pgp:encrypt?:#{@channelName}"


    this.on "change:encrypt? change:sign? change:armored_keypair", @save

  save: ->
    localStorage.setObj "pgp:keypair:#{@channelName}", @get('armored_keypair')
    localStorage.setObj "pgp:sign?:#{@channelName}", @get('sign?')
    localStorage.setObj "pgp:encrypt?:#{@channelName}", @get('encrypt?')

  destroy: ->
    @set 'armored_keypair', null
    @set 'sign?', null
    @set 'encrypt?', null

  usablePrivateKey: (passphrase = '') ->
    if !@privatekey
      dearmored_privs = openpgp.key.readArmored @get('armored_keypair').private
      decrypted = dearmored_privs.keys[0].decrypt(passphrase)
      if decrypted
        @privatekey = dearmored_privs.keys
      else
        console.error "Unable to decrypt private key"

    return @privatekey

  sign: (message) ->
    openpgp.signClearMessage(@usablePrivateKey(), message)

  encrypt: (pubkey, message) ->
    openpgp.encryptMessage(pubkey, message)

  encryptAndSign: (pubkey, message) ->
    openpgp.signAndEncryptMessage(pubkey, @usablePrivateKey(), message)

  trust: (key) ->
    # mark a key as trusted
