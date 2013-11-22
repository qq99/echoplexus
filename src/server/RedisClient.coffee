redis                 = require("redis")
GLOBAL_REDIS_CLIENT   = undefined

module.exports.RedisClient = (port, host) ->
  if !GLOBAL_REDIS_CLIENT
    console.log "no global yet"
    if host? and port?
      console.log "using custom redis conf"
      GLOBAL_REDIS_CLIENT = redis.createClient(port, host) if !GLOBAL_REDIS_CLIENT
    else
      console.log "using default redis conf"
      GLOBAL_REDIS_CLIENT = redis.createClient() if !GLOBAL_REDIS_CLIENT

  return GLOBAL_REDIS_CLIENT
