redis                 = require("redis")
GLOBAL_REDIS_CLIENT   = undefined

module.exports.RedisClient = (port, host) ->
  if !GLOBAL_REDIS_CLIENT
    if host? and port?
      GLOBAL_REDIS_CLIENT = redis.createClient(port, host) if !GLOBAL_REDIS_CLIENT
    else
      GLOBAL_REDIS_CLIENT = redis.createClient() if !GLOBAL_REDIS_CLIENT

  return GLOBAL_REDIS_CLIENT
