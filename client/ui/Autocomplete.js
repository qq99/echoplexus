// object: given a string A, returns a string B iff A is a substring of B
//  transforms A,B -> lowerCase for the comparison
//      TODO: use a scheme involving something like l-distance instead
<<<<<<< HEAD
define(['underscore'],function(_){
    return function () {
        "use strict";
        //The pool
        var pool = [],
            candidates = [], //The candidates
            lastStub = null, //The last stub
            result = null, //The last result
            nID = 0; //The last NID
        //http://www.merriampark.com/ld.htm, http://www.mgilleland.com/ld/ldjavascript.htm, Damerau–Levenshtein distance (Wikipedia)
        var levDist = function(s, t) {
            var d = []; //2d matrix

            // Step 1
            var n = s.length;
            var m = t.length;

            if (n == 0) return m;
            if (m == 0) return n;

            //Create an array of arrays in javascript (a descending loop is quicker)
            for (var i = n; i >= 0; i--) d[i] = [];

            // Step 2
            for (var i = n; i >= 0; i--) d[i][0] = i;
            for (var j = m; j >= 0; j--) d[0][j] = j;

            // Step 3
            for (var i = 1; i <= n; i++) {
                var s_i = s.charAt(i - 1);

                // Step 4
                for (var j = 1; j <= m; j++) {

                    //Check the jagged ld total so far
                    if (i == j && d[i][j] > 4) return n;

                    var t_j = t.charAt(j - 1);
                    var cost = (s_i == t_j) ? 0 : 1; // Step 5

                    //Calculate the minimum
                    var mi = d[i - 1][j] + 1;
                    var b = d[i][j - 1] + 1;
                    var c = d[i - 1][j - 1] + cost;

                    if (b < mi) mi = b;
                    if (c < mi) mi = c;

                    d[i][j] = mi; // Step 6

                    //Damerau transposition
                    if (i > 1 && j > 1 && s_i == t.charAt(j - 2) && s.charAt(i - 2) == t_j) {
                        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + cost);
                    }
                }
            }

            // Step 7
            return d[n][m];
        };
        this.setPool = function (arr) {
            pool = arr;
            candidates = [];
            lastStub = null;
            candidates = null;
            result = null;
            nID = 0;
        };
        this.next = function (stub) {
            if (!pool.length) return "";
            stub = stub.toLowerCase(); // transform the stub -> lcase
            if (stub === lastStub){
                return result;
            } else if (stub === result){
                nID++;
                result = candidates[nID];
                return result;
            } else { // update memoized candidates
                candidates = _.chain(pool).sortBy(function(n){
                    return levDist(stub,n);
                }).value();
                result = _.first(candidates);
                if (_.isUndefined(result) || _.isEmpty(result)) return "";
                nID = 0;
                return result;
            }
        };
        return this;
    }

});
=======
function Autocomplete () {
    "use strict";

    var pool = [], // client names to select from
        candidates = [], //The candidates
        result = null, //The last result
        nID = 0; //The last NID

    this.setPool = function (arr) {
        pool = _.uniq(arr); // e.g., don't bother having "Anonymous" in the pool twice
        candidates = pool;
        result = "";
        nID = 0;
    };

    this.next = function (stub) {
        var self = this;

        if (!pool.length) return "";

        stub = stub.toLowerCase(); // transform the stub -> lcase
        if (stub === "" ||
            stub === result.toLowerCase()){

            // scroll around the memoized array of candidates:
            nID+=1;
            nID%= candidates.length;

            result = "@" + candidates[nID];

        } else { // update memoized candidates
            nID = 0; // start with the highest score (at pos 0)

            candidates = _.chain(pool).sortBy(function(n){
                return self.levDist(stub,n.substring(0,stub.length).toLowerCase());
            }).value();

            // pick the closest match
            result = "@" + candidates[0];
        }

        return result;
    };

    return this;
}

//http://www.merriampark.com/ld.htm, http://www.mgilleland.com/ld/ldjavascript.htm, Damerau–Levenshtein distance (Wikipedia)
Autocomplete.prototype.levDist = function(s, t) {
    var d = []; //2d matrix

    // Step 1
    var n = s.length;
    var m = t.length;

    if (n == 0) return m;
    if (m == 0) return n;

    //Create an array of arrays in javascript (a descending loop is quicker)
    for (var i = n; i >= 0; i--) d[i] = [];

    // Step 2
    for (var i = n; i >= 0; i--) d[i][0] = i;
    for (var j = m; j >= 0; j--) d[0][j] = j;

    // Step 3
    for (var i = 1; i <= n; i++) {
        var s_i = s.charAt(i - 1);

        // Step 4
        for (var j = 1; j <= m; j++) {

            //Check the jagged ld total so far
            if (i == j && d[i][j] > 4) return n;

            var t_j = t.charAt(j - 1);
            var cost = (s_i == t_j) ? 0 : 1; // Step 5

            //Calculate the minimum
            var mi = d[i - 1][j] + 1;
            var b = d[i][j - 1] + 1;
            var c = d[i - 1][j - 1] + cost;

            if (b < mi) mi = b;
            if (c < mi) mi = c;

            d[i][j] = mi; // Step 6

            //Damerau transposition
            if (i > 1 && j > 1 && s_i == t.charAt(j - 2) && s.charAt(i - 2) == t_j) {
                d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + cost);
            }
        }
    }

    // Step 7
    return d[n][m];
};
>>>>>>> master
