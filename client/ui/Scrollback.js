// object: a stack-like data structure supporting only:
//	- an index representing the currently looked-at element
//	- adding new elements to the top of the stack
//	- emptying the stack
define(function(){
	return function() {
		"use strict";
		var buffer = [],
			position = 0;
		
		return {
			add: function (userInput) {
				buffer.push(userInput);
				position += 1;
			},
			prev: function () {
				if (position > 0) {
					position -= 1;
				}
				return buffer[position];
			},
			next: function () {
				if (position < buffer.length) {
					position += 1;
				}
				return buffer[position];
			},
			reset: function () {
				position = buffer.length;
			}
		};
	}
});