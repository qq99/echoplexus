CryptoWrapper               = require("../../CryptoWrapper.coffee").CryptoWrapper
cryptoWrapper               = new CryptoWrapper

module.exports.ChatMessage = class ChatMessage extends Backbone.Model
  idAttribute: 'mID'

  getBody: (cryptoKey) ->
    body = @get("body")
    encrypted_body = @get("encrypted")
    body = cryptoWrapper.decryptObject(encrypted_body, cryptoKey)  if (typeof cryptoKey isnt "undefined") and (cryptoKey isnt "") and (typeof encrypted_body isnt "undefined")
    body
