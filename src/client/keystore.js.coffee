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
    _.bindAll this
    @keystore = localStorage.getObj("keystore") || {}

  add: (fingerprint, armored_key, nick) ->
    if !@keystore[fingerprint]
      @keystore[fingerprint] =
        armored_key: armored_key
        last_used_by: nick
        first_used_at: (new Date()).getTime()
        last_used_at: (new Date()).getTime()
        trusted: false
      @save()
    else
      @markSeen(fingerprint, nick)

  markSeen: (fingerprint, nick) ->
    @keystore[fingerprint].last_used_at = (new Date()).getTime()
    @keystore[fingerprint].last_used_by = nick
    @save()

  is_trusted: (fingerprint) ->
    return @keystore[fingerprint]?.trusted

  is_untrusted: (fingerprint) ->
    return @keystore[fingerprint]?.trusted

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
    @keystore[fingeprrint].untrusted = true
    @keystore[fingerprint].untrusted_at = (new Date()).getTime()
    @save()

  list: ->
    @keystore

  save: ->
    localStorage.setObj "keystore", @keystore
