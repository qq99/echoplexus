config           = require("./config.coffee").Configuration # deploy specific configuration
redisC           = require("./RedisClient.coffee").RedisClient(config.redis?.port, config.redis?.host)

# hackish, as anybody could really end up spoofing this information
# so, we don't let them do too much with this capability
module.exports.allowRepository = (room, repo_url, callback) ->
  redisC.hget "github:webhooks", repo_url, (err, reply) ->
    throw err if err

    if reply
      reply = JSON.parse(reply)
    else
      reply = []

    reply.push room

    redisC.hset "github:webhooks", repo_url, JSON.stringify(reply), (err, reply) ->
      throw err if err
      callback?(null)

module.exports.verifyAllowedRepository = (repo_url, callback) ->

  redisC.hget "github:webhooks", repo_url, (err, reply) ->
    throw err if err

    if reply
      reply = JSON.parse(reply)
      callback?(null, reply)
    else
      callback?("Ignoring request, no matches")

module.exports.prettyPrint = (githubResponse) ->
  r = githubResponse
  "#{r.pusher.name} just pushed #{r.commits.length} commit to #{r.repository.name} (#{r.repository.url})"
