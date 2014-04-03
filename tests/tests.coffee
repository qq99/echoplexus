if Storage # extend the local storage protoype if it exists
  Storage::setObj = (key, obj) ->
    localStorage.setItem key, JSON.stringify(obj)
  Storage::getObj = (key) ->
    JSON.parse localStorage.getItem(key)

require('./client/client_model_test.coffee')
require('./client/color_model_test.coffee')
require('./client/htmlsanitizer_test.coffee')
require('./client/utility_test.coffee')
require('./client/regex_test.coffee')
# chat
require('./client/modules/chat/chat_client_test.coffee')
require('./client/modules/chat/log_test.coffee')
require('./server/extensions/dice_test.coffee')
# call
require('./client/modules/call/call_client_test.coffee')

