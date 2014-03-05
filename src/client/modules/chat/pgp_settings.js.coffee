pgpPassphraseModalTemplate = require("./templates/pgpPassphraseModal.html")

PGPPassphraseModal = class PGPPassphraseModal extends Backbone.View
  className: "backdrop"
  template: pgpPassphraseModalTemplate

  events:
    "keydown #pgp-passphrase": "unlock"
    "click .close-button": "destroy"

  initialize: (opts) ->
    _.bindAll this
    _.extend this, opts

    @$el.html @template()

    $("body").append @$el

    _.defer =>
      @$el.find("input").focus()

  destroy: ->
    @$el.remove()

  unlock: (ev) ->
    return unless ev.keyCode == 13
    $passphraseEl = $("#pgp-passphrase")
    passphrase = $passphraseEl.val()
    $passphraseEl.val("")

    try # attempt to unlock key
      usablePrivateKey = @pgp_settings.decryptPrivateKey(passphrase)
      @on_unlock(usablePrivateKey)
      @destroy()
    catch e
      console.error e
      # display an error, try again, etc


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

  clear: ->
    @set 'cached_private', null
    @set 'armored_keypair', null
    @set 'sign?', null
    @set 'encrypt?', null

  destroy: ->
    @clear()

    my_fingerprint = @get 'fingerprint'
    KEYSTORE.untrust(my_fingerprint)
    KEYSTORE.clean(my_fingerprint)

  decryptPrivateKey: (passphrase = '') ->
    throw 'Invalid passphrase' if @prev == passphrase and !@get('cached_private')
    @prev = passphrase

    if !@get('cached_private')
      dearmored_privs = openpgp.key.readArmored @get('armored_keypair').private
      decrypted = dearmored_privs.keys[0].decrypt(passphrase)
      if decrypted
        console.log 'decrypted'
        @set 'cached_private', dearmored_privs.keys
        @set 'key_error', false
      else
        @set 'key_error', true
        throw "Unable to decrypt private key"
    #else
      #console.log 'using cached priv'

    return @get('cached_private')

  usablePrivateKey: (passphrase = '', callback) ->
    try
      usableKey = @decryptPrivateKey(passphrase)
      callback(usableKey)
    catch
      throw 'Unable to unlock private key'

  sign: (message, callback) ->
    @usablePrivateKey '', (usablePrivateKey) ->
      signed = openpgp.signClearMessage(usablePrivateKey, message)
      callback(signed)

  enabled: ->
    return !!@get('armored_keypair')

  requestPassphrase: ->
    (new PGPPassphraseModal(
      pgp_settings: this
      on_unlock: ->
        callback?(null)
    ))

  prompt: (callback) ->
    if @get('cached_private') # there's already a decrypted pkey for immediate use, do a no-op
      callback?(null)
    else if !@get('key_error') # we haven't had an error decrypting key yet, so try to use the blank passphrase
      try # see if '' unlocks it
        @usablePrivateKey '', ->
          callback?(null) # if it unlocked it, we'll call the callback with success
      catch # else, we'll display the modal to get them to unlock their key
        @requestPassphrase()
    else # there was a key error, so make them unlock
      @requestPassphrase()

  usablePublicKey: (armored_public_key) ->
    dearmored_pubs = openpgp.key.readArmored(armored_public_key)
    dearmored_pubs.keys

  encrypt: (pubkey, message) ->
    openpgp.encryptMessage(@usablePublicKey(pubkey), message)

  encryptAndSign: (pubkey, message, callback) ->
    @usablePrivateKey '', (usablePrivateKey) =>
      pub = @usablePublicKey(pubkey)
      signed_encrypted = openpgp.signAndEncryptMessage(pub, usablePrivateKey[0], message)
      callback(signed_encrypted)

  trust: (key) ->
    # mark a key as trusted
