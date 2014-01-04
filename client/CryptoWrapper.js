define(['AES'],function(AES) {

    var JsonFormatter = {
        stringify: function (cipherParams) {
            // create json object with ciphertext
            var jsonObj = {
                ct: cipherParams.ciphertext.toString(CryptoJS.enc.Base64)
            };

            // optionally add iv and salt
            if (cipherParams.iv) {
                jsonObj.iv = cipherParams.iv.toString();
            }
            if (cipherParams.salt) {
                jsonObj.s = cipherParams.salt.toString();
            }

            // stringify json object
            return JSON.stringify(jsonObj);
        },

        parse: function (jsonStr) {
            // parse json string
            var jsonObj = JSON.parse(jsonStr);

            // extract ciphertext from json object, and create cipher params object
            var cipherParams = CryptoJS.lib.CipherParams.create({
                ciphertext: CryptoJS.enc.Base64.parse(jsonObj.ct)
            });

            // optionally extract iv and salt
            if (jsonObj.iv) {
                cipherParams.iv = CryptoJS.enc.Hex.parse(jsonObj.iv)
            }
            if (jsonObj.s) {
                cipherParams.salt = CryptoJS.enc.Hex.parse(jsonObj.s)
            }

            return cipherParams;
        }
    };

	var encryptObject = function (plaintextObj, key) {
		if (typeof plaintextObj === "undefined" ||
			typeof key === "undefined" ||
			key === "") {

			throw "encryptObject: missing a parameter.";
		}

		if (typeof plaintextObj === "object") { // CryptoJS only takes strings
			plaintextObj = JSON.stringify(plaintextObj);
		}

		var enciphered = CryptoJS.AES.encrypt(plaintextObj, key, { format: JsonFormatter });
		return JSON.parse(enciphered.toString()); // format it back into an object for sending over socket.io
	};

	var decryptObject = function (encipheredObj, key) {
		if (typeof encipheredObj === "undefined") {

			throw "decryptObject: missing a parameter.";
		}

		if (typeof key === "undefined") { // if we have no key, display the ct
			return encipheredObj.ct;
		}

		var decipheredString, decipheredObj;

		// attempt to decrypt the result:
		try {
			decipheredObj = CryptoJS.AES.decrypt(JSON.stringify(encipheredObj), key, { format: JsonFormatter });
			decipheredString = decipheredObj.toString(CryptoJS.enc.Utf8);
		} catch (e) { // if it fails nastily, output the ciphertext
			decipheredString = encipheredObj.ct;
		}

		if (decipheredString === "") { // if it failed gracefully, output the ciphertext
			decipheredString = encipheredObj.ct;
		}

		return decipheredString; // it may not always be a stringified representation of an object, so we'll just return the string
	};

	return {
		encryptObject: encryptObject,
		decryptObject: decryptObject
	}

});