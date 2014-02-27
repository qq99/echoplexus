pgpModalTemplate        = require("./templates/pgpModalTemplate.html")

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
    _.bindAll this
    _.extend this, opts

    my_keys = {}
    for key, val of KEYSTORE.list()
      if val.armored_private_key
        my_keys[key] = val

    @$el.html @template(_.extend(opts, {
      my_keys: my_keys
    }))



    if @pgp_settings.get("armored_keypair")
      @changeSection 'pgp-options'

    this.stickit(@pgp_settings)

    $("body").append @$el

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

    priv = openpgp.key.readArmored(priv)
    if priv.err.length
      $error_area.append("<p>Invalid armored private key</p>")

    pub = openpgp.key.readArmored(pub)
    if pub.err.length
      $error_area.append("<p>Invalid armored public key</p>")

    if !priv.err.length and !pub.err.length
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
