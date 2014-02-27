redis                 = require("redis")
GLOBAL_REDIS_CLIENT   = undefined

module.exports.RedisClient = (port, host, select) ->
  if !GLOBAL_REDIS_CLIENT
    if host? and port?
      GLOBAL_REDIS_CLIENT = redis.createClient(port, host) if !GLOBAL_REDIS_CLIENT
      meta = " on #{host}:#{port}"
    else
      GLOBAL_REDIS_CLIENT = redis.createClient() if !GLOBAL_REDIS_CLIENT

    GLOBAL_REDIS_CLIENT.once "ready", ->
      version = GLOBAL_REDIS_CLIENT.server_info.redis_version
      console.log "Using redis-#{version}#{meta} on DB #{select}."

      if parseInt(version.replace(/\./g, ""), 10) < 200
        console.log "It's recommended to upgrade redis to 2.0.0 or higher!"

  return GLOBAL_REDIS_CLIENT
