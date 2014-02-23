module.exports.PGPSettings = class PGPSettings extends Backbone.Model
  initialize: (opts) ->
    # requires channelName
    _.bindAll this
    _.extend this, opts

    this.on "change:armored_keypair", (model, armored_keypair) ->
      priv = openpgp.key.readArmored(armored_keypair.private)
      pub = openpgp.key.readArmored(armored_keypair.public)
      uid = priv.keys[0]?.users[0]?.userId?.userid
      @set 'user_id', uid if uid

    @set 'armored_keypair', localStorage.getObj "pgp:keypair:#{@channelName}"
    @set 'sign?', localStorage.getObj "pgp:sign?:#{@channelName}"
    @set 'encrypt?', localStorage.getObj "pgp:encrypt?:#{@channelName}"


    this.on "change:encrypt? change:sign? change:armored_keypair", @save

  save: ->
    localStorage.setObj "pgp:keypair:#{@channelName}", @get('armored_keypair')
    localStorage.setObj "pgp:sign?:#{@channelName}", @get('sign?')
    localStorage.setObj "pgp:encrypt?:#{@channelName}", @get('encrypt?')
