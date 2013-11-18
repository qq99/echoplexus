#Initializer for our app
#
#Set up requirejs
(->
  "use strict"
  config =
    paths:
      jquery: "../../lib/jquery/jquery.min"
      underscore: "../../lib/underscore/underscore-min"
      backbone: "../../lib/backbone/backbone-min"
      keymaster: "../../lib/keymaster/keymaster.min"
      "jquery.cookie": "../../lib/jquery.cookie/jquery.cookie"
      text: "../../lib/requirejs-text/text"
      moment: "../../lib/moment/moment"
      codemirror: "../../lib/codemirror/lib/codemirror"
      "codemirror-js": "../../lib/codemirror/mode/javascript/javascript"
      "codemirror-html": "../../lib/codemirror/mode/htmlmixed/htmlmixed"
      "codemirror-xml": "../../lib/codemirror/mode/xml/xml"
      "codemirror-css": "../../lib/codemirror/mode/css/css"
      AES: "../../lib/CryptoJS-3.1.2/rollups/aes"

    shim:
      AES:
        deps: ["../../lib/CryptoJS-3.1.2/components/core", "../../lib/CryptoJS-3.1.2/components/enc-base64", "../../lib/CryptoJS-3.1.2/components/enc-utf16", "../../lib/CryptoJS-3.1.2/components/pbkdf2"]

      underscore:
        exports: "_"

      jquery:
        exports: "$"

      backbone:
        deps: ["underscore", "jquery"]
        exports: "Backbone"

      keymaster:
        exports: "key"

      codemirror:
        exports: "CodeMirror"

      "codemirror-js": ["codemirror"]
      "codemirror-html": ["codemirror"]
      "codemirror-xml": ["codemirror"]
      "codemirror-css": ["codemirror"]
      "jquery.cookie": ["jquery"]

    config:
      loader:
        modules: [
          name: "chat"
          icon: "comments-alt"
          title: "Chat"
          section: "chatting"
          active: true
        ,
          name: "code"
          icon: "code"
          title: "Code"
          section: "coding"
        ,
          name: "draw"
          icon: "pencil"
          title: "Draw"
          section: "drawing"
        ,
          name: "call"
          icon: "phone"
          title: "Call"
          section: "calling"
        ]


  # Expose to the rest of the world
  if typeof module isnt "undefined"
    module.exports = config # For nodejs
  else if typeof require.config isnt "undefined"
    require.config config # For requirejs
    #Bootstrap our main application, and start
    require ["main"]

  # revert (for node-webkit)
  window.require = window.requireNode  if typeof window isnt "undefined" and window.requireNode
)()
