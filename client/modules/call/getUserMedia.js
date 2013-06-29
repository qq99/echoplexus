define([], function () {
	var getUserMedia = navigator.getUserMedia ||
		navigator.webkitGetUserMedia ||
		navigator.mozGetUserMedia ||
		navigator.msGetUserMedia;

	return getUserMedia;
});
