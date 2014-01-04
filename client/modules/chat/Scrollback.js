// object: a stack-like data structure supporting only:
//	- an index representing the currently looked-at element
//  - peeking at an element before/after the current stack pointer, and modifying that pointer
//	- adding new elements to the top of the stack
//	- emptying the stack
//  - replacing an element in the stack with another element
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
			replace: function (prevObj, newObj) {
				var start = buffer.length - 1; // start at the end of the array as this will be the most common case

				for (var i = start; i >= 0; i--) {
					if (buffer[i] === prevObj) {
						buffer[i] = newObj;
						return true;
					}
				}
				return false; // no match
			},
			reset: function () {
				position = buffer.length;
			}
		};
	}
});