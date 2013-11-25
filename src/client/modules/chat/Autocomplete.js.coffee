# object: given a string A, returns a string B iff A is a substring of B
#  transforms A,B -> lowerCase for the comparison
#      TODO: use a scheme involving something like l-distance instead

module.exports.Autocomplete = class Autocomplete
  constructor: ->
    @pool = [] # client names to select from
    @candidates = [] #The candidates
    @result = null #The last result
    @nID = 0 #The last NID

  setPool: (arr) ->
    @pool = _.uniq(arr) # e.g., don't bother having "Anonymous" in the pool twice
    @candidates = @pool
    @result = ""
    @nID = 0

  next: (stub) ->
    return ""  unless @pool.length
    stub = stub.toLowerCase() # transform the stub -> lcase
    if stub is "" or stub is @result.toLowerCase()

      # scroll around the memoized array of candidates:
      @nID += 1
      @nID %= @candidates.length
      @result = "@" + @candidates[@nID]
    else # update memoized candidates
      @nID = 0 # start with the highest score (at pos 0)
      @candidates = _.chain(@pool).sortBy((n) =>
        levDist stub, n.substring(0, stub.length).toLowerCase()
      ).value()

      # pick the closest match
      @result = "@" + @candidates[0]
    @result

  #http://www.merriampark.com/ld.htm, http://www.mgilleland.com/ld/ldjavascript.htm, Damerau–Levenshtein distance (Wikipedia)
  levDist = (s, t) ->
    d = [] #2d matrix

    # Step 1
    n = s.length
    m = t.length
    return m  if n is 0
    return n  if m is 0

    #Create an array of arrays in javascript (a descending loop is quicker)
    i = n

    while i >= 0
      d[i] = []
      i--

    # Step 2
    i = n

    while i >= 0
      d[i][0] = i
      i--
    j = m

    while j >= 0
      d[0][j] = j
      j--

    # Step 3
    i = 1

    while i <= n
      s_i = s.charAt(i - 1)

      # Step 4
      j = 1

      while j <= m

        #Check the jagged ld total so far
        return n  if i is j and d[i][j] > 4
        t_j = t.charAt(j - 1)
        cost = (if (s_i is t_j) then 0 else 1) # Step 5

        #Calculate the minimum
        mi = d[i - 1][j] + 1
        b = d[i][j - 1] + 1
        c = d[i - 1][j - 1] + cost
        mi = b  if b < mi
        mi = c  if c < mi
        d[i][j] = mi # Step 6

        #Damerau transposition
        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + cost)  if i > 1 and j > 1 and s_i is t.charAt(j - 2) and s.charAt(i - 2) is t_j
        j++
      i++

    # Step 7
    d[n][m]
