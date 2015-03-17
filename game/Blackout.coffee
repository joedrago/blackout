MIN_PLAYERS = 3
MAX_LOG_LINES = 7
OK = 'OK'
State =
  LOBBY: 'lobby'
  BID: 'bid'
  TRICK: 'trick'
  ROUNDSUMMARY: 'roundSummary'
  POSTGAMESUMMARY: 'postGameSummary'

Suit =
  NONE: -1
  CLUBS: 0
  DIAMONDS: 1
  HEARTS: 2
  SPADES: 3

SuitName = ['Clubs', 'Diamonds', 'Hearts', 'Spades']
ShortSuitName = ['C', 'D', 'H', 'S']

# ---------------------------------------------------------------------------------------------------------------------------
# AI Name Generator

aiCharacterList = [
  { id: "mario",    name: "Mario",      sprite: "mario",    brain: "normal" }
  { id: "luigi",    name: "Luigi",      sprite: "luigi",    brain: "chaos" }
  { id: "peach",    name: "Peach",      sprite: "peach",    brain: "normal" }
  { id: "daisy",    name: "Daisy",      sprite: "daisy",    brain: "conservativeMoron" }
  { id: "yoshi",    name: "Yoshi",      sprite: "yoshi",    brain: "normal" }
  { id: "toad",     name: "Toad",       sprite: "toad",     brain: "normal" }
  { id: "bowser",   name: "Bowser",     sprite: "bowser",   brain: "aggressiveMoron" }
  { id: "bowserjr", name: "Bowser Jr",  sprite: "bowserjr", brain: "normal" }
  { id: "koopa",    name: "Koopa",      sprite: "koopa",    brain: "normal" }
  { id: "rosalina", name: "Rosalina",   sprite: "rosalina", brain: "normal" }
  { id: "shyguy",   name: "Shyguy",     sprite: "shyguy",   brain: "normal" }
  { id: "toadette", name: "Toadette",   sprite: "toadette", brain: "normal" }
]

aiCharacters = {}
for character in aiCharacterList
  aiCharacters[character.id] = character

randomCharacter = ->
  r = Math.floor(Math.random() * aiCharacterList.length)
  return aiCharacterList[r]

# ---------------------------------------------------------------------------------------------------------------------------
# Card

class Card
  constructor: (x) ->
    @suit  = Math.floor(x / 13)
    @value = Math.floor(x % 13)
    switch @value
      when 9  then @valueName = 'J'
      when 10 then @valueName = 'Q'
      when 11 then @valueName = 'K'
      when 12 then @valueName = 'A'
      else         @valueName = String(@value + 2)

    @name = @valueName + ShortSuitName[@suit]

cardBeats = (challengerX, championX, currentSuit) ->
  challenger = new Card(challengerX)
  champion = new Card(championX)

  if challenger.suit == champion.suit
    # Easy case... same suit, just test value
    return (challenger.value > champion.value)
  else
    if challenger.suit == Suit.SPADES
      # Trump guaranteed win
      return true
    else
      # Dump guaranteed loss
      return false

  return false

# ---------------------------------------------------------------------------------------------------------------------------
# Deck

class ShuffledDeck
  constructor: ->
    # dat inside-out shuffle!
    @cards = [ 0 ]
    for i in [1...52]
      j = Math.floor(Math.random() * i)
      @cards.push(@cards[j])
      @cards[j] = i

# ---------------------------------------------------------------------------------------------------------------------------
# Blackout

class Blackout
  constructor: (@game, params) ->
    return if not params

    if params.state
      for k,v of params.state
        if params.state.hasOwnProperty(k)
          this[k] = params.state[k]

      # this can be removed at some point
      for player in @players
        if player.character
          player.charID = player.character.sprite
          delete player["character"]
    else
      # new game
      @state = State.LOBBY
      @players = params.players
      @log = []
      if params.rounds == 'M'
        # marathon mode!
        @rounds = ['M']
      else
        @rounds = (Number(v) for v in params.rounds.split("|"))

      @players[0].bid = 0
      @players[0].tricks = 0
      @players[0].score = 0
      @players[0].index = 0

      @output(@players[0].name + ' creates game')

  # ---------------------------------------------------------------------------------------------------------------------------
  # Blackout methods

  marathonMode: ->
    return (@rounds[0] == 'M')

  save: ->
    names = "bids dealer log lowestRequired nextRound pile pileWho players prev prevTrickTaker prevWho rounds state trickID trickTaker tricks trumpBroken turn".split(" ")
    state = {}
    for name in names
      state[name] = this[name]
    return state

  findPlayer: (id) ->
    for player in @players
      if player.id == id
        return player
    return undefined

  findOwner: ->
    return @players[0]

  currentPlayer: ->
    return @players[@turn]

  currentSuit: ->
    if @pile.length == 0
      return Suit.NONE

    card = new Card(@pile[0])
    return card.suit

  rename: (id, name) ->
    player = @findPlayer(id)
    if player
      @output(player.name + ' renamed to ' + name)
      player.name = name

  playerHasSuit: (player, suit) ->
    for v in player.hand
      card = new Card(v)
      if card.suit == suit
        return true
    return false

  playerHasOnlySpades: (player) ->
    for v in player.hand
      card = new Card(v)
      if card.suit != Suit.SPADES
        return false
    return true

  playerCanWinInSuit: (player, championCard) ->
    for v in player.hand
      card = new Card(v)
      if card.suit == championCard.suit
        if card.value > championCard.value
          return true
    return false

  bestInPile: ->
    if @pile.length == 0
      return -1
    currentSuit = @currentSuit()
    best = 0
    for i in [1...@pile.length]
      if cardBeats(@pile[i], @pile[best], currentSuit)
        best = i
    return best

  playerAfter: (index) ->
    return (index + 1) % @players.length

  output: (text) ->
    @log.push text
    if @log.length > MAX_LOG_LINES
      @log.shift()

  reset: (params) ->
    if @players.length < MIN_PLAYERS
      return 'notEnoughPlayers'

    for player in @players
      player.score = 0
      player.hand = []

    @nextRound = 0
    @trumpBroken = false
    @prev = []
    @pile = []
    @pileWho = []
    @prevWho = []
    @prevTrickTaker = -1

    if @marathonMode()
      roundCount = "Marathon mode"
    else
      roundCount = "#{@rounds.length} rounds"
    @output("New game! (#{@players.length} players, #{roundCount})")

    @startBid()

    return OK

  startBid: (params) ->
    if @marathonMode()
      if @players[0].score > 0
        return 'gameOver'
      @tricks = 13
    else
      if(@nextRound >= @rounds.length)
        return 'gameOver'
      @tricks = @rounds[@nextRound]

    @nextRound++

    if @prevTrickTaker == -1
      @dealer = Math.floor(Math.random() * @players.length)
      @output "Randomly assigning dealer to #{@players[@dealer].name}"
    else
      @dealer = @prevTrickTaker
      @output "#{@players[@dealer].name} claimed last trick, deals"

    deck = new ShuffledDeck()
    for player, i in @players
      player.bid = -1
      player.tricks = 0

      @game.log "dealing #{@tricks} cards to player #{i}"

      player.hand = []
      for j in [0...@tricks]
        player.hand.push(deck.cards.shift())

      player.hand.sort (a,b) -> return a - b

    @state = State.BID
    @turn = @playerAfter(@dealer)
    @bids = 0
    @pile = []
    @pileWho = []
    @prev = []
    @prevWho = []
    @prevTrickTaker = -1

    @output('Round ' + @nextRound + ' begins ' + @players[@turn].name + ' bids first')

    return OK

  endBid: ->
    lowestPlayer = 0
    lowestCard = @players[0].hand[0] # hand is sorted, therefore hand[0] is the lowest
    for i in [1...@players.length]
      player = @players[i]
      if player.hand[0] < lowestCard
        lowestPlayer = i
        lowestCard = player.hand[0]

    @lowestRequired = true # Next player is obligated to throw the lowest card
    @turn = lowestPlayer
    @trumpBroken = false
    @trickID = 0
    @startTrick()

  startTrick: () ->
    # @turn should already be correct, either from endBid (lowest club) or endTrick (last trickTaker)

    @trickTaker = -1
    @state = State.TRICK

    return OK

  endTrick: ->
    taker = @players[@trickTaker]
    taker.tricks++

    @output(taker.name + ' pockets the trick [' + taker.tricks + ']')
    @prevTrickTaker = @trickTaker
    @turn = @trickTaker
    @prev = @pile
    @prevWho = @pileWho
    @pile = []
    @pileWho = []
    @trickID++

    if @players[0].hand.length > 0
      @startTrick()
    else
      roundCount = @rounds.length
      if @marathonMode()
        roundCount = "M"
      @output('Round ends [' + @nextRound + '/' + roundCount + ']')

      for player in @players
        overUnder = player.bid - player.tricks
        if overUnder < 0
          overUnder *= -1

        penaltyPoints = 0
        step = 1
        while overUnder > 0
          penaltyPoints += step++ # dat quadratic
          overUnder--

        player.score += penaltyPoints

        player.lastWent = String(player.tricks) + '/' + String(player.bid)
        player.lastPoints = penaltyPoints

      gameEnding = false
      if @marathonMode()
        gameEnding = (@players[0].score > 0)
      else
        gameEnding = (@nextRound >= @rounds.length)

      if gameEnding
        @state = State.POSTGAMESUMMARY
      else
        @state = State.ROUNDSUMMARY

  # ---------------------------------------------------------------------------------------------------------------------------
  # Blackout actions

  quit: (params) ->
    @state = State.POSTGAMESUMMARY
    @output('Someone quit Blackout over')

  next: (params) ->
    switch @state
      when State.LOBBY           then return @reset(params)
      when State.BIDSUMMARY      then return @startTrick()
      when State.ROUNDSUMMARY    then return @startBid()
      when State.POSTGAMESUMMARY then return 'gameOver'
      else                       return 'noNext'
    return 'nextIsConfused'

  bid: (params) ->
    if @state != State.BID
      return 'notBiddingNow'

    currentPlayer = @currentPlayer()
    if params.id != currentPlayer.id
      return 'notYourTurn'

    params.bid = Number(params.bid)

    if (params.bid < 0) || (params.bid > @tricks)
      return 'bidOutOfRange'

    if @turn == @dealer
      if (@bids + params.bid) == @tricks
        return 'dealerFucked'

      @endBid()
    else
      @turn = @playerAfter(@turn)

    currentPlayer.bid = params.bid
    @bids += currentPlayer.bid
    @output(currentPlayer.name + " bids " + currentPlayer.bid)

    if @state != State.BID
      # Bidding ended
      @output('Bidding ends ' + @bids + '/' + @tricks + ' ' + @players[@turn].name + ' throws first')

    return OK

  addPlayer: (player) ->
    player.bid = 0
    player.tricks = 0
    player.score = 0
    if not player.ai
      player.ai = false

    @players.push player
    player.index = @players.length - 1
    # @output(player.name + " joins game (" + @players.length + ")")

  namePresent: (name) ->
    for player in @players
      if player.name == name
        return true

    return false

  addAI: ->
    loop
      character = randomCharacter()
      if not @namePresent(character.name)
        break

    ai =
      charID: character.id
      name: character.name
      id: 'ai' + String(@players.length)
      ai: true

    @addPlayer(ai)

    @game.log("added AI player")
    return OK

  canPlay: (params) ->
    if @state != State.TRICK
      return 'notInTrick'

    currentPlayer = @currentPlayer()
    if params.id != currentPlayer.id
      return 'notYourTurn'

    if params.hasOwnProperty('which')
      params.which = Number(params.which)
      params.index = -1
      for card, i in currentPlayer.hand
        if card == params.which
          params.index = i
          break

      if params.index == -1
        return 'doNotHave'
    else
      params.index = Number(params.index)

    if (params.index < 0) || (params.index >= currentPlayer.hand.length)
      return 'indexOutOfRange'

    if @lowestRequired && (params.index != 0)
      return 'lowestCardRequired'

    chosenCardX = currentPlayer.hand[params.index]
    chosenCard = new Card(chosenCardX)

    if((!@trumpBroken) &&                    # Ensure that trump is broken
    (@pile.length == 0) &&                   # before allowing someone to lead
    (chosenCard.suit == Suit.SPADES) &&      # with spades
    (!@playerHasOnlySpades(currentPlayer)))  # unless it is all they have
      return 'trumpNotBroken'

    bestIndex = @bestInPile()
    forcedSuit = @currentSuit()
    if forcedSuit != Suit.NONE # safe to assume (bestIndex != -1) in this block
      if @playerHasSuit(currentPlayer, forcedSuit)
        # You must throw in-suit if you have one of that suit
        if chosenCard.suit != forcedSuit
          return 'forcedInSuit'

        # If the current winner is winning in-suit, you must try to beat them in-suit
        currentWinningCardX = @pile[bestIndex]
        currentWinningCard = new Card(currentWinningCardX)
        if currentWinningCard.suit == forcedSuit
          if((!cardBeats(chosenCardX, currentWinningCardX, forcedSuit)) &&
          (@playerCanWinInSuit(currentPlayer, currentWinningCard)))
            return 'forcedHigherInSuit'
      else
        # Current player doesn't have that suit, don't bother
        forcedSuit = Suit.NONE

    return OK

  play: (params) ->
    canPlayCard = @canPlay(params)
    if canPlayCard != OK
      return canPlayCard

    currentPlayer = @currentPlayer()

    if params.hasOwnProperty('which')
      params.which = Number(params.which)
      params.index = -1
      for card, i in currentPlayer.hand
        if card == params.which
          params.index = i
          break

      if params.index == -1
        return 'doNotHave'
    else
      params.index = Number(params.index)

    chosenCardX = currentPlayer.hand[params.index]
    chosenCard = new Card(chosenCardX)

    # If you get here, you can throw whatever you want, and it
    # will either put you in the lead, trump, or dump.

    @lowestRequired = false

    # Throw the card on the pile, advance the turn
    @pile.push(currentPlayer.hand[params.index])
    @pileWho.push(@turn)
    currentPlayer.hand.splice(params.index, 1)

    # Recalculate best index
    bestIndex = @bestInPile()
    if bestIndex == (@pile.length - 1)
      # The card this player just threw is the best card. Claim the trick.
      @trickTaker = @turn

    if @pile.length == 1
      msg = currentPlayer.name + " leads with " + chosenCard.name
    else
      if @trickTaker == @turn
        msg = currentPlayer.name + " claims the trick with " + chosenCard.name
      else
        msg = currentPlayer.name + " dumps " + chosenCard.name

    if((!@trumpBroken) && (chosenCard.suit == Suit.SPADES))
      msg += " (trump broken)"
      @trumpBroken = true

    @output(msg)

    if @pile.length == @players.length
      @endTrick()
    else
      @turn = @playerAfter(@turn)

    return OK

  # ---------------------------------------------------------------------------------------------------------------------------
  # AI

  # Helper function to bid reasoning for bidding i tricks
  aiLogBid: (i, why) ->
    currentPlayer = @currentPlayer()
    if not currentPlayer.ai
      return false

    card = new Card(currentPlayer.hand[i])
    @aiLog('potential winner: ' + card.name + ' [' + why + ']')

  # Helper function to bid reasoning for playing card index i
  aiLogPlay: (i, why) ->
    if i == -1
      return

    currentPlayer = @currentPlayer()
    if not currentPlayer.ai
      return false

    card = new Card(currentPlayer.hand[i])
    @aiLog('bestPlay: ' + card.name + ' [' + why + ']')

  # Attempts to bid i tricks
  aiBid: (currentPlayer, i) ->
    reply = @bid({'id':currentPlayer.id, 'bid':i})
    if reply == OK
      @game.log("AI: " + currentPlayer.name + " bids " + String(i))
      return true
    return false

  # Attempts to play card index i
  aiPlay: (currentPlayer, i) ->
    card = new Card(currentPlayer.hand[i])
    # @game.log "aiPlay: #{i}"
    reply = @play({'id':currentPlayer.id, 'index':i})
    if reply == OK
      @game.log("AI: " + currentPlayer.name + " plays " + card.name)
      return true
    else
      if reply == 'dealerFucked'
        @output(currentPlayer.name + ' says "I hate being the dealer."')
    return false

  # Tries to play lowest cards first (moves right)
  aiPlayLow: (currentPlayer, startingPoint) ->
    for i in [startingPoint...currentPlayer.hand.length]
      if @aiPlay(currentPlayer, i)
        return true
    for i in [0...startingPoint]
      if @aiPlay(currentPlayer, i)
        return true
    return false

  # Tries to play highest cards first (moves left)
  aiPlayHigh: (currentPlayer, startingPoint) ->
    for i in [startingPoint..0] by -1
      if(@aiPlay(currentPlayer, i))
        return true
    for i in [currentPlayer.hand.length-1...startingPoint] by -1
      if @aiPlay(currentPlayer, i)
        return true
    return false

  # Generic logging function; prepends current AI player's guts before printing text
  aiLog: (text) ->
    currentPlayer = @currentPlayer()
    if not currentPlayer.ai
      return false

    character = aiCharacters[currentPlayer.charID]
    @game.log('AI['+currentPlayer.name+' '+currentPlayer.tricks+'/'+currentPlayer.bid+' '+character.brain+']: hand:'+stringifyCards(currentPlayer.hand)+' pile:'+stringifyCards(@pile)+' '+text)

  # Detects if the current player is AI during a BID or TRICK phase and acts according to their 'brain'
  aiTick: ->
    if (@state != State.BID) && (@state != State.TRICK)
      return false

    currentPlayer = @currentPlayer()
    if not currentPlayer.ai
      return false

    # ------------------------------------------------------------
    # Bidding

    if @state == State.BID
      @aiLog("about to call brain.bid")
      character = aiCharacters[currentPlayer.charID]
      bid = @brains[character.brain].bid.apply(this, [currentPlayer])

      # Try to bid as close as you can to the 'best bid'
      @aiLog('bid:'+String(bid))
      if @aiBid(currentPlayer, bid)
        return true
      if @aiBid(currentPlayer, bid-1)
        return true
      if @aiBid(currentPlayer, bid+1)
        return true
      if @aiBid(currentPlayer, bid-2)
        return true
      if @aiBid(currentPlayer, bid+2)
        return true

      # Give up and bid whatever is allowed
      for i in [0...currentPlayer.hand.length]
        if @aiBid(currentPlayer, i)
          @aiLog('gave up and bid:'+String(i))
          return true

    # ------------------------------------------------------------
    # Playing

    if @state == State.TRICK
      @aiLog("about to call brain.play")
      character = aiCharacters[currentPlayer.charID]
      playedCard = @brains[character.brain].play.apply(this, [currentPlayer])
      if playedCard
        return true
      else
        @aiLog('brain failed to play card: picking random card to play')
        startingPoint = Math.floor(Math.random() * currentPlayer.hand.length)
        return @aiPlayLow(currentPlayer, startingPoint)

    return false

# ---------------------------------------------------------------------------------------------------------------------------
# AI Brains

  # Brains must have:
  # * id: internal identifier for the brain
  # * name: pretty name
  # * bid(currentPlayer) returns the bid value between [0 - handSize].
  # * play(currentPlayer) attempts to play a card by calling aiPlay(). Should return true if it successfully played a card (aiPlay() returned true)
  brains:

    # ------------------------------------------------------------
    # Normal: Intended to be used by most characters.
    #         Not too dumb, not too smart.
    normal:
      id:   "normal"
      name: "Normal"

      # normal
      bid: (currentPlayer) ->
        # Cards Represented (how many out of the deck are in play?)
        handSize = currentPlayer.hand.length
        cr = @players.length * handSize
        #crp = Math.floor((cr * 100) / 52)

        bid = 0
        partialSpades = 0
        partialFaces = 0 # non spade face cards
        for v, i in currentPlayer.hand
          card = new Card(v)
          if card.suit == Suit.SPADES
            if cr > 40 # Almost all cards in play
              if card.value >= 6 # 8S or higher
                bid++
                @aiLogBid(i, '8S or bigger')
                continue
              else
                partialSpades++
                if partialSpades > 1
                  bid++
                  @aiLogBid(i, 'a couple of low spades')
                  partialSpades = 0
                  continue
            else
              bid++
              @aiLogBid(i, 'spade')
              continue
          else
            if (card.value >= 9) && (card.value <= 11) # JQK of non spade
              partialFaces++
              if partialFaces > 2
                partialFaces = 0
                @aiLogBid(i, 'a couple JQK non-spades')
                continue

          if cr > 40
            # * Aces and Kings are probably winners
            if((card.value >= 11) &&   # Ace or King
            (card.suit != Suit.CLUBS)) # Not a club
              bid++
              @aiLogBid(i, 'non-club ace or king')
              continue

        if handSize >= 6
          # * The Ace of clubs is a winner unless you also have a low club
          clubValues = valuesOfSuit(currentPlayer.hand, Suit.CLUBS)
          if clubValues.length > 0 # has clubs
            if clubValues[clubValues.length - 1] == 12 # has AC
              if clubValues[0] > 0 # 2C not in hand
                bid++
                @aiLogBid(0, 'AC with no 2C')

        return bid

      # normal
      play: (currentPlayer) ->
        tricksNeeded = currentPlayer.bid - currentPlayer.tricks
        wantToWin = (tricksNeeded > 0)
        bestPlay = -1
        currentSuit = @currentSuit()
        winningIndex = @bestInPile()

        if @pile.length == @players.length
          currentSuit = Suit.NONE
          winningIndex = -1

        winningCard = false
        if winningIndex != -1
          winningCard = new Card(@pile[winningIndex])

        if wantToWin
          if currentSuit == Suit.NONE # Are you leading?
            # Lead with your highest non-spade
            play = highestValueNonSpadeIndex(currentPlayer.hand, Suit.NONE)
            @aiLogPlay(play, 'highest non-spade (trying to win)')

            if bestPlay == -1
              # Only spades left! Time to bleed the table.
              bestPlay = 0
              @aiLogPlay(bestPlay, 'lowest spade (trying to win bleeding the table for a future win)')
          else
            if @playerHasSuit(currentPlayer, currentSuit) # Are you stuck with forced play?
              if @playerCanWinInSuit(currentPlayer, winningCard) # Can you win?
                bestPlay = highestIndexInSuit(currentPlayer.hand, winningCard.suit)
                @aiLogPlay(bestPlay, 'highest in suit (trying to win forced in suit)')
                if bestPlay != -1
                  return @aiPlayHigh(currentPlayer, bestPlay)
              else
                bestPlay = lowestIndexInSuit(currentPlayer.hand, winningCard.suit)
                @aiLogPlay(bestPlay, 'lowest in suit (trying to win forced in suit, cant win)')
                if bestPlay != -1
                  return @aiPlayLow(currentPlayer, bestPlay)

            if bestPlay == -1
              lastCard = new Card(currentPlayer.hand[currentPlayer.hand.length - 1])
              if lastCard.suit == Suit.SPADES
                # Try to trump, hard
                bestPlay = currentPlayer.hand.length - 1
                @aiLogPlay(bestPlay, 'trump (trying to win)')
              else
                # No more spades left and none of this suit. Dump your lowest card.
                bestPlay = lowestValueIndex(currentPlayer.hand, Suit.NONE)
                @aiLogPlay(bestPlay, 'dump (trying to win, throwing lowest)')
        else
          # Plan: Try to dump something awesome

          if currentSuit == Suit.NONE # Are you leading?
            # Lead with your lowest value (try to not throw a spade if you can help it)
            bestPlay = lowestValueIndex(currentPlayer.hand, Suit.SPADES)
            @aiLogPlay(bestPlay, 'lowest value (trying to lose avoiding spades)')
          else
            if @playerHasSuit(currentPlayer, currentSuit) # Are you stuck with forced play?
              if @playerCanWinInSuit(currentPlayer, winningCard) # Are you stuck winning?
                bestPlay = lowestIndexInSuit(currentPlayer.hand, winningCard.suit)
                @aiLogPlay(bestPlay, 'lowest in suit (trying to lose forced to win)')
                if bestPlay != -1
                  return @aiPlayLow(currentPlayer, bestPlay)
              else
                bestPlay = highestIndexInSuit(currentPlayer.hand, winningCard.suit)
                @aiLogPlay(bestPlay, 'highest in suit (trying to lose forced in suit, but cant win)')
                if bestPlay != -1
                  return @aiPlayHigh(currentPlayer, bestPlay)

            if bestPlay == -1
              # Try to dump your highest spade, if you can throw anything
              if (currentSuit != Suit.SPADES) && (winningCard.suit == Suit.SPADES)
                # Current winner is trumping the suit. Throw your highest spade lower than the winner
                bestPlay = highestValueIndexInSuitLowerThan(currentPlayer.hand, winningCard)
                @aiLogPlay(bestPlay, 'trying to lose highest dumpable spade')

            if bestPlay == -1
              # Try to dump your highest non-spade
              bestPlay = highestValueNonSpadeIndex(currentPlayer.hand, winningCard.suit)
              @aiLogPlay(bestPlay, 'trying to lose highest dumpable non-spade')

        if bestPlay != -1
          if(@aiPlay(currentPlayer, bestPlay))
            return true
          else
            @aiLog('not allowed to play my best play')

        return false

    # ------------------------------------------------------------
    # Chaos: Completely random. Probably awful to play against.
    chaos:
      id:   "chaos"
      name: "Chaos"

      # chaos
      bid: (currentPlayer) ->
        # pick a bid somewhere in the first 50%
        return Math.floor(Math.random() * currentPlayer.hand.length * 0.5)

      # chaos
      play: (currentPlayer) ->
        legalIndices = []
        for v, i in currentPlayer.hand
          canPlayCard = @canPlay({ id: currentPlayer.id, index: i })
          if canPlayCard == OK
            legalIndices.push i
          # else
          #   @aiLog "canPlayCard #{i} returned #{canPlayCard}"
        randomIndex = Math.floor(Math.random() * legalIndices.length)
        @aiLog "legal indices: #{JSON.stringify(legalIndices)}, choosing index #{legalIndices[randomIndex]}"
        return @aiPlay(currentPlayer, legalIndices[randomIndex])

    # ------------------------------------------------------------
    # Conservative Moron: Bids spade count, and plays low cards.
    conservativeMoron:
      id:   "conservativeMoron"
      name: "Conservative Moron"

      # conservativeMoron
      bid: (currentPlayer) ->
        bid = 0
        for v in currentPlayer.hand
          card = new Card(v)
          bid++ if card.suit == Suit.SPADES
        @aiLog "I am a moron and I have #{bid} spades. Let's roll with it."
        return bid

      # conservativeMoron
      play: (currentPlayer) ->
        @aiLog "playing lowest possible card"
        return @aiPlayLow(currentPlayer, 0)

    # ------------------------------------------------------------
    # Aggressive Moron: Bids spades and aces, and plays high cards.
    aggressiveMoron:
      id:   "aggressiveMoron"
      name: "Aggressive Moron"

      # aggressiveMoron
      bid: (currentPlayer) ->
        bid = 0
        for v in currentPlayer.hand
          card = new Card(v)
          bid++ if (card.suit == Suit.SPADES) or (card.value == 12)
        @aiLog "I am a moron and I have #{bid} spades and/or aces. Fart."
        return bid

      # aggressiveMoron
      play: (currentPlayer) ->
        @aiLog "playing highest possible card"
        return @aiPlayHigh(currentPlayer, currentPlayer.hand.length - 1)

# ---------------------------------------------------------------------------------------------------------------------------
# AI card helpers

valuesOfSuit = (hand, suit) ->
  values = []
  for v in hand
    card = new Card(v)
    if card.suit == suit
      values.push(card.value)
  return values

stringifyCards = (cards) ->
  t = ''
  for v in cards
    card = new Card(v)
    if(t)
      t += ','
    t += card.name

  return '['+t+']'

lowestIndexInSuit = (hand, suit) ->
  for v,i in hand
    card = new Card(v)
    if card.suit == suit
      return i
  return -1

highestIndexInSuit = (hand, suit) ->
  for v,i in hand by -1
    card = new Card(v)
    if card.suit == suit
      return i
  return -1

lowestValueIndex = (hand, avoidSuit) -> # use Suit.NONE to return any suit
  card = new Card(hand[0])
  lowestIndex = 0
  lowestValue = card.value
  for i in [1...hand.length]
    card = new Card(hand[i])
    if card.suit != avoidSuit
      if card.value < lowestValue
        lowestValue = card.value
        lowestIndex = i
  return lowestIndex

highestValueNonSpadeIndex = (hand, avoidSuit) ->
  highestIndex = -1
  highestValue = -1
  for i in [hand.length-1..0] by -1
    card = new Card(hand[i])
    if (card.suit != avoidSuit) && (card.suit != Suit.SPADES)
      if card.value > highestValue
        highestValue = card.value
        highestIndex = i
  return highestIndex

highestValueIndexInSuitLowerThan = (hand, winningCard) ->
  for i in [hand.length-1..0] by -1
    card = new Card(hand[i])
    if (card.suit == winningCard.suit) && (card.value < winningCard.value)
      return i
  return -1

# ---------------------------------------------------------------------------------------------------------------------------
# Exports

module.exports =
  Card: Card
  Blackout: Blackout
  State: State
  OK: OK
  aiCharacters: aiCharacters

