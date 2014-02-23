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
        return value.private
    "#pgp-armored-public":
      observe: 'armored_keypair'
      onGet: (value, options) ->
        return value.public
    ".pgp-user-id": "user_id"

  events:
    "click button.generate-keypair": -> @changeSection("generate-keypair")
    "click button.view-key-information": -> @changeSection("pgp-keypair-information")
    "click button.finalize-generate-keypair": "generateKeypair"
    "click .close-button": "destroy"

  initialize: (opts) ->
    _.bindAll this
    _.extend this, opts
    @$el.html @template(opts)



    if @pgp_settings.get("armored_keypair")
      @changeSection 'pgp-options'

    this.stickit(@pgp_settings)

    $("body").append @$el

  destroy: ->
    @$el.remove()

  changeSection: (section) ->
    console.log 'showing section', section
    @$el.find("section").removeClass("active")
    @$el.find("section.#{section}").addClass("active")

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

        @changeSection("pgp-options")

    catch e
      console.error "Something went wrong in generating PGP keypair! #{e}"
