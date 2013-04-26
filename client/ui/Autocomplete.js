// object: given a string A, returns a string B iff A is a substring of B
//	transforms A,B -> lowerCase for the comparison
//		TODO: use a scheme involving something like l-distance instead
function Autocomplete () {
	"use strict";
	var pool = [],
		cur = 0,
		lastStub,
		candidates;

	return {
		setPool: function (arr) {
			pool = arr;
			candidates = [];
			lastStub = null;
		},
		next: function (stub) {
			if (!pool.length) return "";

			stub = stub.toLowerCase(); // transform the stub -> lcase
			if (stub !== lastStub) { // update memoized candidates
				candidates = pool.filter(function (element, index, array) {
					return (element.toLowerCase().indexOf(stub) !== -1);
				});
			}

			if (!candidates.length) return "";

			cur += 1;
			cur = cur % candidates.length;
			name = candidates[cur];
			
			return name;
		}
	};
}