# http://dustinsenos.com/articles/customErrorsInNode
util = require("util")
AbstractError = (msg, constr) ->

  # If defined, pass the constr property to V8's
  # captureStackTrace to clean up the output
  Error.captureStackTrace this, constr or this

  # If defined, store a custom error message
  @message = msg or "Error"


# Extend our AbstractError from Error
util.inherits AbstractError, Error

# Give our Abstract error a name property. Helpful for logging the error later.
AbstractError::name = "Abstract Error"
AuthenticationFailure = (msg) ->
  AuthenticationFailure.super_.call this, msg, @constructor

util.inherits AuthenticationFailure, AbstractError
AuthenticationFailure::message = "Authentication Failure"
module.exports = Authentication: AuthenticationFailure
