module.exports.Keystore = class Keystore
  # dictionary of fingerprint -> key meta info
  #   - trusted
  #   - trusted_at (time)
  #   - untrusted
  #   - untrusted_at (time)
  #   - last_used_by (nickname)
  #   - last_used_at (time)
  #   - last_used_in (channel)

  constructor: (opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    @keystore = localStorage.getObj("keystore") || {}

  add: (fingerprint, armored_key, armored_private_key, nick, channel) ->
    if !@keystore[fingerprint]
      @keystore[fingerprint] =
        armored_key: armored_key
        armored_private_key: armored_private_key
        last_used_by: nick
        first_used_at: (new Date()).getTime()
        last_used_at: (new Date()).getTime()
        last_used_in: channel
        trusted: false
      @save()
    else
      @markSeen(fingerprint, nick, channel)

  get: (fingerprint) ->
    return @keystore[fingerprint]

  clean: (fingerprint) ->
    @keystore[fingerprint].armored_private_key = null
    @save()

  markSeen: (fingerprint, nick, channel) ->
    return if !@keystore[fingerprint]
    @keystore[fingerprint].last_used_at = (new Date()).getTime()
    @keystore[fingerprint].last_used_by = nick
    @keystore[fingerprint].last_used_in = channel
    @save()

  is_trusted: (fingerprint) ->
    return @keystore[fingerprint]?.trusted

  is_untrusted: (fingerprint) ->
    return @keystore[fingerprint]?.untrusted

  trust_status: (fingerprint) ->
    return "trusted" if @is_trusted(fingerprint)
    return "untrusted" if @is_untrusted(fingerprint)
    return "unknown"

  trust: (fingerprint) ->
    @keystore[fingerprint].trusted = true
    @keystore[fingerprint].untrusted = false
    @keystore[fingerprint].trusted_at = (new Date()).getTime()
    @save()

  untrust: (fingerprint) ->
    @keystore[fingerprint].trusted = false
    @keystore[fingerprint].untrusted = true
    @keystore[fingerprint].untrusted_at = (new Date()).getTime()
    @save()

  neutral: (fingerprint) ->
    @keystore[fingerprint].trusted = false
    @keystore[fingerprint].untrusted = false
    @save()

  list: ->
    @keystore

  save: ->
    localStorage.setObj "keystore", @keystore
