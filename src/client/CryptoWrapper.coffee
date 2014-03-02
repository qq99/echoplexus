module.exports.CryptoWrapper = class CryptoWrapper

  JsonFormatter:
    stringify: (cipherParams) ->

      # create json object with ciphertext
      jsonObj = ct: cipherParams.ciphertext.toString(CryptoJS.enc.Base64)

      # optionally add iv and salt
      jsonObj.iv = cipherParams.iv.toString()  if cipherParams.iv
      jsonObj.s = cipherParams.salt.toString()  if cipherParams.salt

      # stringify json object
      JSON.stringify jsonObj

    parse: (jsonStr) ->

      # parse json string
      jsonObj = JSON.parse(jsonStr)

      # extract ciphertext from json object, and create cipher params object
      cipherParams = CryptoJS.lib.CipherParams.create(ciphertext: CryptoJS.enc.Base64.parse(jsonObj.ct))

      # optionally extract iv and salt
      cipherParams.iv = CryptoJS.enc.Hex.parse(jsonObj.iv)  if jsonObj.iv
      cipherParams.salt = CryptoJS.enc.Hex.parse(jsonObj.s)  if jsonObj.s
      cipherParams

  encryptObject: (plaintextObj, key) ->
    throw "encryptObject: missing a parameter."  if typeof plaintextObj is "undefined" or typeof key is "undefined" or key is ""
    # CryptoJS only takes strings
    plaintextObj = JSON.stringify(plaintextObj)  if typeof plaintextObj is "object"
    enciphered = CryptoJS.AES.encrypt(plaintextObj, key,
      format: @JsonFormatter
    )
    JSON.parse enciphered.toString() # format it back into an object for sending over socket.io

  decryptObject: (encipheredObj, key) ->
    throw "No enciphered object supplied"  if !encipheredObj
    throw "No key supplied" if !key

    # attempt to decrypt the result:
    try
      decipheredObj = CryptoJS.AES.decrypt(JSON.stringify(encipheredObj), key,
        format: @JsonFormatter
      )
      decipheredString = decipheredObj.toString(CryptoJS.enc.Utf8)
    catch e # if it fails nastily, output the ciphertext
      throw e
