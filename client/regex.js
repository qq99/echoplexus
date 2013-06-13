(function( exports ) {
    // utility: a container of useful regexes arranged into some a rough taxonomy
	exports.REGEXES = {
		urls: {
			image: /(\b(https?|http):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|].(jpg|png|bmp|gif|svg))/gi,
			youtube: /(\b(https?|http):\/\/(www.)*(youtube.com)[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/gi,
			all_others: /(\b(https?|http):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/gi
		},
		commands: {
			nick: /^\/(nick|n)/,
			register: /^\/register/,
			identify: /^\/(identify|id)/,
			topic: /^\/(topic)/,
			failed_command: /^\//,
			private: /^\/private/,
			public: /^\/public/,
			password: /^\/(password|pw)/,
			private_message: /^\/(pm|w|whisper|t|tell) /,
			join: /^\/(join|j)/
		},
		phantomjs: {
			delimiter: /!!!/g,
			parameter: /!!!\w+!!!/,
		}
	};

})(
  typeof exports === 'object' ? exports : this
);