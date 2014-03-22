pgpModalTemplate        = require("./templates/pgpModalTemplate.html")

class PreviouslyUsedKey extends Backbone.Model


module.exports.PGPModal = class PGPModal extends Backbone.View
  className: "backdrop"
  template: pgpModalTemplate

  bindings:
    "#pgp-sign-outgoing": "sign?"
    "#pgp-encrypt-outgoing": "encrypt?"
    "#pgp-armored-private":
      observe: 'armored_keypair'
      onGet: (value, options) ->
        return value?.private
    "#pgp-armored-public":
      observe: 'armored_keypair'
      onGet: (value, options) ->
        return value?.public
    ".pgp-user-id": "user_id"
    ".pgp-fingerprint": "fingerprint"
    ".reusing-keys-section":
      observe: "my_keys"
      visible: -> @my_keys.length > 0
    "#key-to-reuse": {
      observe: "my_keys"
      selectOptions: {
        collection: -> @my_keys
        labelPath: "label"
        valuePath: "fingerprint"
      }
    }

  events:
    "click button.generate-keypair": -> @changeSection("generate-keypair")
    "click button.view-key-information": -> @changeSection("pgp-keypair-information")
    "click button.view-pgp-options": -> @changeSection("pgp-options")
    "click button.use-own": -> @changeSection("pgp-user-supplied")
    "click button.destroy-keypair": "destroyKeypair"
    "click button.finalize-generate-keypair": "generateKeypair"
    "click .close-button": "destroy"
    "click .use-key": "userSupplied"
    "click .re-use": "reuseOther"
    "click .stop-using": "clear"

  initialize: (opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    _.extend this, opts

    @getMyKeys()

    @$el.html @template()

    if @pgp_settings.get("armored_keypair")
      @changeSection 'pgp-options'

    this.stickit(@pgp_settings)

    $("body").append @$el

  getMyKeys: ->
    @my_keys = []
    @pgp_settings.set("my_keys", [])
    for key, val of KEYSTORE.list()
      if val.armored_private_key
        @my_keys.push {
          label: "#{key} (used " + moment(val.last_used_at).fromNow() + " in #{val.last_used_in} as #{val.last_used_by})"
          fingerprint: key
        }

    @pgp_settings.set("my_keys", @my_keys)

  clear: ->
    @pgp_settings.clear()
    @destroy()

  destroy: ->
    @$el.remove()

  changeSection: (section) ->
    console.log 'showing section', section
    @$el.find("section").removeClass("active")
    @$el.find("section.#{section}").addClass("active")

  destroyKeypair: ->
    @pgp_settings.destroy()
    @getMyKeys() # update list of previously used keys
    @changeSection("intro")

  generateKeypair: ->
    keytype    = 1
    keysize    = parseInt(@$el.find("#pgp-key-size").val(), 10) || 2048
    name       = @$el.find("#pgp-name").val() || @me.getNick()
    email      = @$el.find("#pgp-email").val() || "#{@me.getNick()}@echoplex.us"
    passphrase = @$el.find("#pgp-passphrase-challenge").val() || ""

    pgp_name = "#{name} <#{email}>"

    @changeSection("pgp-generating")
    try
      armored_keypair = openpgp.generateKeyPair keytype, keysize, pgp_name, passphrase, (err, result) =>
        @pgp_settings.set
          'armored_keypair': {
            private: result.privateKeyArmored
            public: result.publicKeyArmored
          }
          'sign?': true
          'encrypt?': false

        @changeSection("pgp-keypair-information")

    catch e
      console.error "Something went wrong in generating PGP keypair! #{e}"

  userSupplied: ->
    priv = $("#pgp-user-supplied-armored-private").val()?.trim()
    pub = $("#pgp-user-supplied-armored-public").val()?.trim()

    $error_area = $(".errors", @$el)
    $error_area.children().remove()

    priv_unarmored = openpgp.key.readArmored(priv)
    if priv_unarmored.err?.length
      $error_area.append("<p>Invalid armored private key</p>")

    pub_unarmored = openpgp.key.readArmored(pub)
    if pub_unarmored.err?.length
      $error_area.append("<p>Invalid armored public key</p>")

    if !priv_unarmored.err and !pub_unarmored.err
      @pgp_settings.set
        'armored_keypair': {
          private: priv
          public: pub
        }
        'sign?': true
        'encrypt?': false
      @changeSection("pgp-keypair-information")

  reuseOther: ->
    fingerprint = $("#key-to-reuse").val()

    other = KEYSTORE.get(fingerprint)
    @pgp_settings.set
      'armored_keypair': {
        private: other.armored_private_key
        public: other.armored_key
      }
      'sign?': true
      'encrypt?': false
    @changeSection("pgp-keypair-information")
