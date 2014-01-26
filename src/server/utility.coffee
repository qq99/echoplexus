crypto = require("crypto")

module.exports.Utility = class Utility

  getSimpleSaltedMD5: (stringToHash, callback) ->

    crypto.randomBytes 64, (err, buf) ->
      throw err if err

      salted = buf.toString('hex') + stringToHash
      md5 = crypto.createHash('md5')
      md5.update(salted)
      hash = md5.digest('hex')

      callback?(null, hash)
