// http://dustinsenos.com/articles/customErrorsInNode
var util = require('util');

var AbstractError = function (msg, constr) {
	// If defined, pass the constr property to V8's
	// captureStackTrace to clean up the output
	Error.captureStackTrace(this, constr || this);
	// If defined, store a custom error message
	this.message = msg || 'Error';
};
// Extend our AbstractError from Error
util.inherits(AbstractError, Error);
// Give our Abstract error a name property. Helpful for logging the error later.
AbstractError.prototype.name = 'Abstract Error';


var AuthenticationFailure = function (msg) {
	AuthenticationFailure.super_.call(this, msg, this.constructor);
};
util.inherits(AuthenticationFailure, AbstractError);
AuthenticationFailure.prototype.message = 'Authentication Failure';

module.exports = {
  Authentication: AuthenticationFailure
}