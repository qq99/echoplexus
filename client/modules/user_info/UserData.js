define(['jquery','underscore','backbone',
        'text!modules/user_info/templates/userPopup.html', 'events'
    ],
    function ($, _, Backbone, popupTemplate) {

    var UserDataPopup = Backbone.View.extend({

        className: "backdrop",

        template: _.template(popupTemplate),

        events: {
            "click": "remove"
        },

        initialize: function (opts) {
            _.bindAll(this);
            _.extend(this, opts);

            console.log(this.client.attributes);

            this.$el.html(this.template(this.client.attributes));

            $("body").append(this.$el);
        },

    });

    var UserData = Backbone.View.extend({
    	initialize: function () {

            console.log(popupTemplate);

    		window.events.on("view_profile", function (data) {
                console.log(data);
                var client = data.clients.findWhere({id: data.uID}),
                    modal = new UserDataPopup({
                        client: client
                    });
    		});

    		window.events.on("edit_profile", function (data) {
                console.log(data);
                var client = data.clients.findWhere({id: data.uID}),
                    modal = new UserDataPopup({
                        client: client,
                        editable: true
                    });
    		});
    	}
    });

    var userData = new UserData(); // singleton
});