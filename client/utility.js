/*
utility:
	useful extensions to global objects, if they must be made, should be made here
*/


// extend the local storage protoype if it exists
define(function(){
	if (window.Storage) {
		Storage.prototype.setObj = function(key, obj) {
			return this.setItem(key, JSON.stringify(obj));
		};
		Storage.prototype.getObj = function(key) {
			return JSON.parse(this.getItem(key));
		};
	}
});