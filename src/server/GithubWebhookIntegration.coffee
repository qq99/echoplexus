config             = require("./config.coffee").Configuration # deploy specific configuration
redisC             = require("./RedisClient.coffee").RedisClient(config.redis?.port, config.redis?.host)
crypto             = require('crypto')
utility            = new (require("./utility.coffee").Utility)
async              = require("async")

# hackish, as anybody could really end up spoofing this information
# so, we don't let them do too much with this capability
module.exports.allowRepository = (room, repo_url, callback) ->
  redisC.hget "github:webhooks", repo_url, (err, rooms) ->
    throw err if err

    if rooms
      rooms = JSON.parse(rooms)
    else
      rooms = []
    rooms.push room

    utility.getSimpleSaltedMD5 room, (err, hash) ->
      throw err if err

      async.parallel {
        token: (callback) ->
          redisC.hset "github:webhooks:tokens", hash, room, callback
        webhook: (callback) ->
          redisC.hset "github:webhooks", repo_url, JSON.stringify(rooms), callback
      }, (err, stored) ->
        console.log err, hash, stored
        throw err if err
        callback?(null, hash)

module.exports.verifyAllowedRepository = (token, callback) ->
  redisC.hget "github:webhooks:tokens", token, (err, reply) ->
    throw err if err

    if reply
      callback?(null, reply)
    else
      callback?("Ignoring GitHub postreceive hook's request: token not found!")

module.exports.prettyPrint = (githubResponse) ->
  r = githubResponse

  pluralize = (noun, n) ->
    if n > 1
      noun + "s"
    else
      noun

  details = for c in r.commits
    "<li><a href='#{c.url}'>#{c.message}</a></li>"

  "<img class='fl' src='#{module.exports.gravatarURL(r.committer.email)}'></img>
  #{r.committer.name} just pushed #{r.commits.length} #{pluralize('commit', r.commits.length)} to
  <a href='#{r.repository.url}' target='_blank' title='#{r.repository.name} on GitHub'>#{r.repository.name}</a>
  <ul>
    #{details}
  </ul>"

module.exports.gravatarURLHash = (emailAddress) ->
  emailAddress = emailAddress.trim()
  emailAddress = emailAddress.toLowerCase()

  md5 = crypto.createHash 'md5'
  md5.update emailAddress
  md5.digest('hex')

module.exports.gravatarURL = (emailAddress) ->
  "http://www.gravatar.com/avatar/#{module.exports.gravatarURLHash(emailAddress)}.jpg?s=16&d=identicon"
