# http://dustinsenos.com/articles/customErrorsInNode
util = require("util")

module.exports.AbstractError = class AbstractError extends Error

  name: "Abstract Error"
  constructor: (msg, constr) ->
    # If defined, pass the constr property to V8's
    # captureStackTrace to clean up the output
    Error.captureStackTrace this, constr or this

    # If defined, store a custom error message
    @message = msg or "Error"

module.exports.AuthenticationFailure = class AuthenticationFailure extends module.exports.AbstractError

  name: "Authentication Failure"
  constructor: (msg, constr) ->
    super
