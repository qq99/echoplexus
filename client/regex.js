(function(root, factory) {
  // Set up Backbone appropriately for the environment.
  if (typeof exports !== 'undefined') {
    // Node/CommonJS, no need for jQuery in that case.
    factory(exports);
  } else if (typeof define === 'function' && define.amd) {
    // AMD
    define(['exports'], function(exports) {
      // Export global even in AMD case in case this script is loaded with
      // others that may still expect a global Backbone.
      return factory(exports);
    });
  }
})(this,function( exports ) {
    // utility: a container of useful regexes arranged into some a rough taxonomy
	exports.REGEXES = {
		urls: {
			image: /(\b(https?|http):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|].(jpg|png|bmp|gif|svg))/gi,
			youtube: /((https?:\/\/)?(www\.)?youtu((?=\.)\.be\/|be\.com\/watch.*v=)([\w\d\-_]*))/gi,
			all_others: /(\b(https?|http):(\/\/|&#x2F;&#x2F;)[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/gi
		},
		users: {
			mentions: /(@[^\b\s]*)/gi
		},
		commands: {
			nick: /^\/(nick|n) /,
			register: /^\/register/,
			identify: /^\/(identify|id)/,
			topic: /^\/(topic)/,
			failed_command: /^\//,
			private: /^\/private/,
			public: /^\/public/,
			password: /^\/(password|pw)/,
			private_message: /^\/(pm|w|whisper|t|tell) /,
			join: /^\/(join|j)/,
			pull_logs: /^\/(pull|p|sync|s) /,
			set_color: /^\/(color|c) /,
			edit: /^(\/edit) #?(\d*) /
		},
		colors: {
			hex: /^#?([a-f0-9]{6}|[a-f0-9]{3})$/i, // matches 3 and 6-digit hex colour codes, optional #
		},
		phantomjs: {
			delimiter: /!!!/g,
			parameter: /!!!\w+!!!/,
		}
	};

});
