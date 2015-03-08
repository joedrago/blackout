require=(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({"Animation":[function(require,module,exports){
var Animation, calcSign;

calcSign = function(v) {
  if (v === 0) {
    return 0;
  } else if (v < 0) {
    return -1;
  }
  return 1;
};

Animation = (function() {
  function Animation(data) {
    var k, v;
    this.speed = data.speed;
    this.req = {};
    this.cur = {};
    for (k in data) {
      v = data[k];
      if (k !== 'speed') {
        this.req[k] = v;
        this.cur[k] = v;
      }
    }
  }

  Animation.prototype.warp = function() {
    if (this.cur.r != null) {
      this.cur.r = this.req.r;
    }
    if ((this.cur.x != null) && (this.cur.y != null)) {
      this.cur.x = this.req.x;
      return this.cur.y = this.req.y;
    }
  };

  Animation.prototype.animating = function() {
    if (this.cur.r != null) {
      if (this.req.r !== this.cur.r) {
        return true;
      }
    }
    if ((this.cur.x != null) && (this.cur.y != null)) {
      if ((this.req.x !== this.cur.x) || (this.req.y !== this.cur.y)) {
        return true;
      }
    }
    return false;
  };

  Animation.prototype.update = function(dt) {
    var dist, dr, maxDist, negTwoPi, sign, twoPi, updated, vecX, vecY;
    updated = false;
    if (this.cur.r != null) {
      if (this.req.r !== this.cur.r) {
        updated = true;
        twoPi = Math.PI * 2;
        negTwoPi = -1 * twoPi;
        while (this.req.r >= twoPi) {
          this.req.r -= twoPi;
        }
        while (this.req.r <= negTwoPi) {
          this.req.r += twoPi;
        }
        dr = this.req.r - this.cur.r;
        dist = Math.abs(dr);
        sign = calcSign(dr);
        if (dist > Math.PI) {
          dist = twoPi - dist;
          sign *= -1;
        }
        maxDist = dt * this.speed.r / 1000;
        if (dist < maxDist) {
          this.cur.r = this.req.r;
        } else {
          this.cur.r += maxDist * sign;
        }
      }
    }
    if ((this.cur.x != null) && (this.cur.y != null)) {
      if ((this.req.x !== this.cur.x) || (this.req.y !== this.cur.y)) {
        updated = true;
        vecX = this.req.x - this.cur.x;
        vecY = this.req.y - this.cur.y;
        dist = Math.sqrt((vecX * vecX) + (vecY * vecY));
        maxDist = dt * this.speed.t / 1000;
        if (dist < maxDist) {
          this.cur.x = this.req.x;
          this.cur.y = this.req.y;
        } else {
          this.cur.x += (vecX / dist) * maxDist;
          this.cur.y += (vecY / dist) * maxDist;
        }
      }
    }
    return updated;
  };

  return Animation;

})();

module.exports = Animation;



},{}],"Blackout":[function(require,module,exports){
var Blackout, Card, MAX_LOG_LINES, MIN_PLAYERS, OK, ShortSuitName, ShuffledDeck, State, Suit, SuitName, aiNames, cardBeats, highestIndexInSuit, highestValueIndexInSuitLowerThan, highestValueNonSpadeIndex, lowestIndexInSuit, lowestValueIndex, randomName, stringifyCards, valuesOfSuit;

MIN_PLAYERS = 3;

MAX_LOG_LINES = 7;

OK = 'OK';

State = {
  LOBBY: 'lobby',
  BID: 'bid',
  TRICK: 'trick',
  ROUNDSUMMARY: 'roundSummary',
  POSTGAMESUMMARY: 'postGameSummary'
};

Suit = {
  NONE: -1,
  CLUBS: 0,
  DIAMONDS: 1,
  HEARTS: 2,
  SPADES: 3
};

SuitName = ['Clubs', 'Diamonds', 'Hearts', 'Spades'];

ShortSuitName = ['C', 'D', 'H', 'S'];

aiNames = ["Mario", "Luigi", "Toad", "Peach"];

randomName = function() {
  var r;
  r = Math.floor(Math.random() * aiNames.length);
  return aiNames[r];
};

Card = (function() {
  function Card(x) {
    this.suit = Math.floor(x / 13);
    this.value = Math.floor(x % 13);
    switch (this.value) {
      case 9:
        this.valueName = 'J';
        break;
      case 10:
        this.valueName = 'Q';
        break;
      case 11:
        this.valueName = 'K';
        break;
      case 12:
        this.valueName = 'A';
        break;
      default:
        this.valueName = String(this.value + 2);
    }
    this.name = this.valueName + ShortSuitName[this.suit];
  }

  return Card;

})();

cardBeats = function(challengerX, championX, currentSuit) {
  var challenger, champion;
  challenger = new Card(challengerX);
  champion = new Card(championX);
  if (challenger.suit === champion.suit) {
    return challenger.value > champion.value;
  } else {
    if (challenger.suit === Suit.SPADES) {
      return true;
    } else {
      return false;
    }
  }
  return false;
};

ShuffledDeck = (function() {
  function ShuffledDeck() {
    var i, j, l;
    this.cards = [0];
    for (i = l = 1; l < 52; i = ++l) {
      j = Math.floor(Math.random() * i);
      this.cards.push(this.cards[j]);
      this.cards[j] = i;
    }
  }

  return ShuffledDeck;

})();

Blackout = (function() {
  function Blackout(game, params) {
    var data, err, i, k, l, ref, v;
    this.game = game;
    if (!params) {
      return;
    }
    if (params.json) {
      try {
        data = JSON.parse(params.json);
      } catch (_error) {
        err = _error;
        this.game.log("JSON parse error: " + err);
      }
      if (data) {
        for (k in data) {
          v = data[k];
          if (data.hasOwnProperty(k)) {
            this[k] = data[k];
          }
        }
      }
    } else {
      this.id = params.id;
      this.state = State.LOBBY;
      this.players = params.players;
      this.counter = 0;
      this.log = [];
      this.rounds = params.rounds.split("|");
      this.maxPlayers = 5;
      for (i = l = 0, ref = this.rounds.length; 0 <= ref ? l < ref : l > ref; i = 0 <= ref ? ++l : --l) {
        this.rounds[i] = Number(this.rounds[i]);
        if (this.rounds[i] > 10) {
          this.maxPlayers = 4;
        }
      }
      this.players[0].bid = 0;
      this.players[0].tricks = 0;
      this.players[0].score = 0;
      this.output(this.players[0].name + ' creates game');
    }
  }

  Blackout.prototype.findPlayer = function(id) {
    var l, len, player, ref;
    ref = this.players;
    for (l = 0, len = ref.length; l < len; l++) {
      player = ref[l];
      if (player.id === id) {
        return player;
      }
    }
    return void 0;
  };

  Blackout.prototype.findOwner = function() {
    return this.players[0];
  };

  Blackout.prototype.currentPlayer = function() {
    return this.players[this.turn];
  };

  Blackout.prototype.currentSuit = function() {
    var card;
    if (this.pile.length === 0) {
      return Suit.NONE;
    }
    card = new Card(this.pile[0]);
    return card.suit;
  };

  Blackout.prototype.rename = function(id, name) {
    var player;
    player = this.findPlayer(id);
    if (player) {
      this.output(player.name + ' renamed to ' + name);
      return player.name = name;
    }
  };

  Blackout.prototype.playerHasSuit = function(player, suit) {
    var card, l, len, ref, v;
    ref = player.hand;
    for (l = 0, len = ref.length; l < len; l++) {
      v = ref[l];
      card = new Card(v);
      if (card.suit === suit) {
        return true;
      }
    }
    return false;
  };

  Blackout.prototype.playerHasOnlySpades = function(player) {
    var card, l, len, ref, v;
    ref = player.hand;
    for (l = 0, len = ref.length; l < len; l++) {
      v = ref[l];
      card = new Card(v);
      if (card.suit !== Suit.SPADES) {
        return false;
      }
    }
    return true;
  };

  Blackout.prototype.playerCanWinInSuit = function(player, championCard) {
    var card, l, len, ref, v;
    ref = player.hand;
    for (l = 0, len = ref.length; l < len; l++) {
      v = ref[l];
      card = new Card(v);
      if (card.suit === championCard.suit) {
        if (card.value > championCard.value) {
          return true;
        }
      }
    }
    return false;
  };

  Blackout.prototype.bestInPile = function() {
    var best, currentSuit, i, l, ref;
    if (this.pile.length === 0) {
      return -1;
    }
    currentSuit = this.currentSuit();
    best = 0;
    for (i = l = 1, ref = this.pile.length; 1 <= ref ? l < ref : l > ref; i = 1 <= ref ? ++l : --l) {
      if (cardBeats(this.pile[i], this.pile[best], currentSuit)) {
        best = i;
      }
    }
    return best;
  };

  Blackout.prototype.playerAfter = function(index) {
    return (index + 1) % this.players.length;
  };

  Blackout.prototype.output = function(text) {
    this.log.push(text);
    if (this.log.length > MAX_LOG_LINES) {
      return this.log.shift();
    }
  };

  Blackout.prototype.reset = function(params) {
    var l, len, player, ref;
    if (this.players.length < MIN_PLAYERS) {
      return 'notEnoughPlayers';
    }
    ref = this.players;
    for (l = 0, len = ref.length; l < len; l++) {
      player = ref[l];
      player.score = 0;
      player.hand = [];
    }
    this.counter = 0;
    this.nextRound = 0;
    this.trumpBroken = false;
    this.output('Blackout reset. (' + this.players.length + ' players, ' + this.rounds.length + ' rounds)');
    this.startBid();
    return OK;
  };

  Blackout.prototype.startBid = function(params) {
    var deck, j, l, len, m, player, ref, ref1;
    if (this.nextRound >= this.rounds.length) {
      return 'gameOver';
    }
    this.tricks = this.rounds[this.nextRound];
    this.nextRound++;
    deck = new ShuffledDeck();
    ref = this.players;
    for (l = 0, len = ref.length; l < len; l++) {
      player = ref[l];
      player.bid = -1;
      player.tricks = 0;
      player.hand = [];
      for (j = m = 0, ref1 = this.tricks; 0 <= ref1 ? m < ref1 : m > ref1; j = 0 <= ref1 ? ++m : --m) {
        player.hand.push(deck.cards.shift());
      }
      player.hand.sort(function(a, b) {
        return a - b;
      });
    }
    this.dealer = Math.floor(Math.random() * this.players.length);
    this.state = State.BID;
    this.turn = this.playerAfter(this.dealer);
    this.bids = 0;
    this.pile = [];
    this.prev = [];
    this.lastTrickTaker = -1;
    this.output('Round ' + this.nextRound + ' begins ' + this.players[this.turn].name + ' bids first');
    return OK;
  };

  Blackout.prototype.endBid = function() {
    var i, l, lowestCard, lowestPlayer, player, ref;
    lowestPlayer = 0;
    lowestCard = this.players[0].hand[0];
    for (i = l = 1, ref = this.players.length; 1 <= ref ? l < ref : l > ref; i = 1 <= ref ? ++l : --l) {
      player = this.players[i];
      if (player.hand[0] < lowestCard) {
        lowestPlayer = i;
        lowestCard = player.hand[0];
      }
    }
    this.lowestRequired = true;
    this.turn = lowestPlayer;
    this.trumpBroken = false;
    return this.startTrick({});
  };

  Blackout.prototype.startTrick = function(params) {
    this.prev = this.pile;
    this.pile = [];
    this.trickTaker = -1;
    this.state = State.TRICK;
    return OK;
  };

  Blackout.prototype.endTrick = function() {
    var l, len, overUnder, penaltyPoints, player, ref, step, taker;
    taker = this.players[this.trickTaker];
    taker.tricks++;
    this.output(taker.name + ' pockets the trick [' + taker.tricks + ']');
    this.lastTrickTaker = this.trickTaker;
    this.turn = this.trickTaker;
    if (this.players[0].hand.length > 0) {
      return this.startTrick();
    } else {
      this.output('Round ends [' + this.nextRound + '/' + this.rounds.length + ']');
      ref = this.players;
      for (l = 0, len = ref.length; l < len; l++) {
        player = ref[l];
        overUnder = player.bid - player.tricks;
        if (overUnder < 0) {
          overUnder *= -1;
        }
        penaltyPoints = 0;
        step = 1;
        while (overUnder > 0) {
          penaltyPoints += step++;
          overUnder--;
        }
        player.score += penaltyPoints;
        player.lastWent = String(player.tricks) + '/' + String(player.bid);
        player.lastPoints = penaltyPoints;
      }
      if (this.nextRound >= this.rounds.length) {
        return this.state = State.POSTGAMESUMMARY;
      } else {
        return this.state = State.ROUNDSUMMARY;
      }
    }
  };

  Blackout.prototype.quit = function(params) {
    this.state = State.POSTGAMESUMMARY;
    return this.output('Someone quit Blackout over');
  };

  Blackout.prototype.next = function(params) {
    switch (this.state) {
      case State.LOBBY:
        return this.reset(params);
      case State.BIDSUMMARY:
        return this.startTrick();
      case State.ROUNDSUMMARY:
        return this.startBid();
      case State.POSTGAMESUMMARY:
        return 'gameOver';
      default:
        return 'noNext';
    }
    return 'nextIsConfused';
  };

  Blackout.prototype.bid = function(params) {
    var currentPlayer;
    if (this.state !== State.BID) {
      return 'notBiddingNow';
    }
    currentPlayer = this.currentPlayer();
    if (params.id !== currentPlayer.id) {
      return 'notYourTurn';
    }
    params.bid = Number(params.bid);
    if ((params.bid < 0) || (params.bid > this.tricks)) {
      return 'bidOutOfRange';
    }
    if (this.turn === this.dealer) {
      if ((this.bids + params.bid) === this.tricks) {
        return 'dealerFucked';
      }
      this.endBid();
    } else {
      this.turn = this.playerAfter(this.turn);
    }
    currentPlayer.bid = params.bid;
    this.bids += currentPlayer.bid;
    this.output(currentPlayer.name + " bids " + currentPlayer.bid);
    if (this.state !== State.BID) {
      this.output('Bidding ends ' + this.bids + '/' + this.tricks + ' ' + this.players[this.turn].name + ' throws first');
    }
    return OK;
  };

  Blackout.prototype.addPlayer = function(player) {
    player.bid = 0;
    player.tricks = 0;
    player.score = 0;
    if (!player.ai) {
      player.ai = false;
    }
    this.players.push(player);
    return this.output(player.name + " joins game (" + this.players.length + ")");
  };

  Blackout.prototype.namePresent = function(name) {
    var l, len, player, ref;
    ref = this.players;
    for (l = 0, len = ref.length; l < len; l++) {
      player = ref[l];
      if (player.name === name) {
        return true;
      }
    }
    return false;
  };

  Blackout.prototype.addAI = function() {
    var ai, name;
    if (this.players.length >= this.maxPlayers) {
      return 'tooManyPlayers';
    }
    while (true) {
      name = randomName();
      if (!this.namePresent(name)) {
        break;
      }
    }
    ai = {
      name: name,
      id: 'ai' + String(this.players.length),
      ai: true
    };
    this.addPlayer(ai);
    this.game.log("added AI player");
    return OK;
  };

  Blackout.prototype.play = function(params) {
    var bestIndex, card, chosenCard, chosenCardX, currentPlayer, currentWinningCard, currentWinningCardX, forcedSuit, i, l, len, msg, ref;
    if (this.state !== State.TRICK) {
      return 'notInTrick';
    }
    currentPlayer = this.currentPlayer();
    if (params.id !== currentPlayer.id) {
      return 'notYourTurn';
    }
    if (params.hasOwnProperty('which')) {
      params.which = Number(params.which);
      params.index = -1;
      ref = currentPlayer.hand;
      for (i = l = 0, len = ref.length; l < len; i = ++l) {
        card = ref[i];
        if (card === params.which) {
          params.index = i;
          break;
        }
      }
      if (params.index === -1) {
        return 'doNotHave';
      }
    } else {
      params.index = Number(params.index);
    }
    if ((params.index < 0) || (params.index >= currentPlayer.hand.length)) {
      return 'indexOutOfRange';
    }
    if (this.lowestRequired && (params.index !== 0)) {
      return 'lowestCardRequired';
    }
    chosenCardX = currentPlayer.hand[params.index];
    chosenCard = new Card(chosenCardX);
    if ((!this.trumpBroken) && (this.pile.length === 0) && (chosenCard.suit === Suit.SPADES) && (!this.playerHasOnlySpades(currentPlayer))) {
      return 'trumpNotBroken';
    }
    bestIndex = this.bestInPile();
    forcedSuit = this.currentSuit();
    if (forcedSuit !== Suit.NONE) {
      if (this.playerHasSuit(currentPlayer, forcedSuit)) {
        if (chosenCard.suit !== forcedSuit) {
          return 'forcedInSuit';
        }
        currentWinningCardX = this.pile[bestIndex];
        currentWinningCard = new Card(currentWinningCardX);
        if (currentWinningCard.suit === forcedSuit) {
          if ((!cardBeats(chosenCardX, currentWinningCardX, forcedSuit)) && (this.playerCanWinInSuit(currentPlayer, currentWinningCard))) {
            return 'forcedHigherInSuit';
          }
        }
      } else {
        forcedSuit = Suit.NONE;
      }
    }
    this.lowestRequired = false;
    this.pile.push(currentPlayer.hand[params.index]);
    currentPlayer.hand.splice(params.index, 1);
    bestIndex = this.bestInPile();
    if (bestIndex === (this.pile.length - 1)) {
      this.trickTaker = this.turn;
    }
    if (this.pile.length === 1) {
      msg = currentPlayer.name + " leads with " + chosenCard.name;
    } else {
      if (this.trickTaker === this.turn) {
        msg = currentPlayer.name + " claims the trick with " + chosenCard.name;
      } else {
        msg = currentPlayer.name + " dumps " + chosenCard.name;
      }
    }
    if ((!this.trumpBroken) && (chosenCard.suit === Suit.SPADES)) {
      msg += " (trump broken)";
      this.trumpBroken = true;
    }
    this.output(msg);
    if (this.pile.length === this.players.length) {
      this.endTrick();
    } else {
      this.turn = this.playerAfter(this.turn);
    }
    return OK;
  };

  Blackout.prototype.action = function(params) {
    var reply;
    if ((params.action !== 'quit') && (this.state !== State.BID) && (this.state !== State.TRICK) && (params.id !== this.findOwner().id)) {
      return 'ownerOnly';
    }
    if (!this[params.action]) {
      return 'unknownAction';
    }
    if (this.counter !== params.counter) {
      return 'staleCounter';
    }
    reply = this[params.action](params);
    if (reply === OK) {
      this.counter++;
    }
    return reply;
  };

  Blackout.prototype.aiLogBid = function(i, why) {
    var card, currentPlayer;
    currentPlayer = this.currentPlayer();
    if (!currentPlayer.ai) {
      return false;
    }
    card = new Card(currentPlayer.hand[i]);
    return this.aiLog('potential winner: ' + card.name + ' [' + why + ']');
  };

  Blackout.prototype.aiLogPlay = function(i, why) {
    var card, currentPlayer;
    if (i === -1) {
      return;
    }
    currentPlayer = this.currentPlayer();
    if (!currentPlayer.ai) {
      return false;
    }
    card = new Card(currentPlayer.hand[i]);
    return this.aiLog('bestPlay: ' + card.name + ' [' + why + ']');
  };

  Blackout.prototype.bestBid = function(currentPlayer) {
    var bid, card, clubValues, cr, handSize, i, l, len, partialFaces, partialSpades, ref;
    handSize = currentPlayer.hand.length;
    cr = this.players.length * handSize;
    bid = 0;
    partialSpades = 0;
    partialFaces = 0;
    ref = currentPlayer.hand;
    for (i = l = 0, len = ref.length; l < len; i = ++l) {
      card = ref[i];
      if (card.suit === Suit.SPADES) {
        if (cr > 40) {
          if (card.value >= 6) {
            bid++;
            this.aiLogBid(i, '8S or bigger');
            continue;
          } else {
            partialSpades++;
            if (partialSpades > 1) {
              bid++;
              this.aiLogBid(i, 'a couple of low spades');
              partialSpades = 0;
              continue;
            }
          }
        } else {
          bid++;
          this.aiLogBid(i, 'spade');
          continue;
        }
      } else {
        if ((card.value >= 9) && (card.value <= 11)) {
          partialFaces++;
          if (partialFaces > 2) {
            partialFaces = 0;
            this.aiLogBid(i, 'a couple JQK non-spades');
            continue;
          }
        }
      }
      if (cr > 40) {
        if ((card.value >= 11) && (card.suit !== Suit.CLUBS)) {
          bid++;
          this.aiLogBid(i, 'non-club ace or king');
          continue;
        }
      }
    }
    if (handSize >= 6) {
      clubValues = valuesOfSuit(currentPlayer.hand, Suit.CLUBS);
      if (clubValues.length > 0) {
        if (clubValues[clubValues.length - 1] === 12) {
          if (clubValues[0] > 0) {
            bid++;
            this.aiLogBid(0, 'AC with no 2C');
          }
        }
      }
    }
    return bid;
  };

  Blackout.prototype.aiBid = function(currentPlayer, i) {
    var reply;
    reply = this.action({
      'counter': this.counter,
      'id': currentPlayer.id,
      'action': 'bid',
      'bid': i
    });
    if (reply === OK) {
      this.game.log("AI: " + currentPlayer.name + " bids " + String(i));
      return true;
    }
    return false;
  };

  Blackout.prototype.aiPlay = function(currentPlayer, i) {
    var card, reply;
    card = new Card(currentPlayer.hand[i]);
    reply = this.action({
      'counter': this.counter,
      'id': currentPlayer.id,
      'action': 'play',
      'index': i
    });
    if (reply === OK) {
      this.game.log("AI: " + currentPlayer.name + " plays " + card.name);
      return true;
    } else {
      if (reply === 'dealerFucked') {
        this.output(currentPlayer.name + ' says "I hate being the dealer."');
      }
    }
    return false;
  };

  Blackout.prototype.aiPlayLow = function(currentPlayer, startingPoint) {
    var i, l, m, ref, ref1, ref2;
    for (i = l = ref = startingPoint, ref1 = currentPlayer.hand.length; ref <= ref1 ? l < ref1 : l > ref1; i = ref <= ref1 ? ++l : --l) {
      if (this.aiPlay(currentPlayer, i)) {
        return true;
      }
    }
    for (i = m = 0, ref2 = startingPoint; 0 <= ref2 ? m < ref2 : m > ref2; i = 0 <= ref2 ? ++m : --m) {
      if (this.aiPlay(currentPlayer, i)) {
        return true;
      }
    }
    return false;
  };

  Blackout.prototype.aiPlayHigh = function(currentPlayer, startingPoint) {
    var i, l, m, ref, ref1, ref2;
    for (i = l = ref = startingPoint; l >= 0; i = l += -1) {
      if (this.aiPlay(currentPlayer, i)) {
        return true;
      }
    }
    for (i = m = ref1 = currentPlayer.hand.length - 1, ref2 = startingPoint; m > ref2; i = m += -1) {
      if (this.aiPlay(currentPlayer, i)) {
        return true;
      }
    }
    return false;
  };

  Blackout.prototype.aiLog = function(text) {
    var currentPlayer;
    currentPlayer = this.currentPlayer();
    if (!currentPlayer.ai) {
      return false;
    }
    return this.game.log('AI[' + currentPlayer.name + ' ' + currentPlayer.tricks + '/' + currentPlayer.bid + ']: hand:' + stringifyCards(currentPlayer.hand) + ' pile:' + stringifyCards(this.pile) + ' ' + text);
  };

  Blackout.prototype.aiTick = function() {
    var bestBid, bestPlay, currentPlayer, currentSuit, i, l, lastCard, ref, startingPoint, tricksNeeded, wantToWin, winningCard, winningIndex;
    if ((this.state !== State.BID) && (this.state !== State.TRICK)) {
      return false;
    }
    currentPlayer = this.currentPlayer();
    if (!currentPlayer.ai) {
      return false;
    }
    if (this.state === State.BID) {
      bestBid = this.bestBid(currentPlayer);
      this.aiLog('bestBid:' + String(bestBid));
      if (this.aiBid(currentPlayer, bestBid)) {
        return true;
      }
      if (this.aiBid(currentPlayer, bestBid - 1)) {
        return true;
      }
      if (this.aiBid(currentPlayer, bestBid + 1)) {
        return true;
      }
      if (this.aiBid(currentPlayer, bestBid - 2)) {
        return true;
      }
      if (this.aiBid(currentPlayer, bestBid + 2)) {
        return true;
      }
      for (i = l = 0, ref = currentPlayer.hand.length; 0 <= ref ? l < ref : l > ref; i = 0 <= ref ? ++l : --l) {
        if (this.aiBid(currentPlayer, i)) {
          this.aiLog('gave up and bid:' + String(i));
          return true;
        }
      }
    }
    if (this.state === State.TRICK) {
      tricksNeeded = currentPlayer.bid - currentPlayer.tricks;
      wantToWin = tricksNeeded > 0;
      bestPlay = -1;
      currentSuit = this.currentSuit();
      winningIndex = this.bestInPile();
      if (this.pile.length === this.players.length) {
        currentSuit = Suit.NONE;
        winningIndex = -1;
      }
      winningCard = false;
      if (winningIndex !== -1) {
        winningCard = new Card(this.pile[winningIndex]);
      }
      if (wantToWin) {
        if (currentSuit === Suit.NONE) {
          bestPlay = highestValueNonSpadeIndex(currentPlayer.hand, Suit.NONE);
          this.aiLogPlay(bestPlay, 'highest non-spade (trying to win)');
          if (bestPlay === -1) {
            bestPlay = 0;
            this.aiLogPlay(bestPlay, 'lowest spade (trying to win bleeding the table for a future win)');
          }
        } else {
          if (this.playerHasSuit(currentPlayer, currentSuit)) {
            if (this.playerCanWinInSuit(currentPlayer, winningCard)) {
              bestPlay = highestIndexInSuit(currentPlayer.hand, winningCard.suit);
              this.aiLogPlay(bestPlay, 'highest in suit (trying to win forced in suit)');
              if (bestPlay !== -1) {
                return this.aiPlayHigh(currentPlayer, bestPlay);
              }
            } else {
              bestPlay = lowestIndexInSuit(currentPlayer.hand, winningCard.suit);
              this.aiLogPlay(bestPlay, 'lowest in suit (trying to win forced in suit, cant win)');
              if (bestPlay !== -1) {
                return this.aiPlayLow(currentPlayer, bestPlay);
              }
            }
          }
          if (bestPlay === -1) {
            lastCard = new Card(currentPlayer.hand[currentPlayer.hand.length - 1]);
            if (lastCard.suit === Suit.SPADES) {
              bestPlay = currentPlayer.hand.length - 1;
              this.aiLogPlay(bestPlay, 'trump (trying to win)');
            } else {
              bestPlay = lowestValueIndex(currentPlayer.hand, Suit.NONE);
              this.aiLogPlay(bestPlay, 'dump (trying to win, throwing lowest)');
            }
          }
        }
      } else {
        if (currentSuit === Suit.NONE) {
          bestPlay = lowestValueIndex(currentPlayer.hand, Suit.SPADES);
          this.aiLogPlay(bestPlay, 'lowest value (trying to lose avoiding spades)');
        } else {
          if (this.playerHasSuit(currentPlayer, currentSuit)) {
            if (this.playerCanWinInSuit(currentPlayer, winningCard)) {
              bestPlay = lowestIndexInSuit(currentPlayer.hand, winningCard.suit);
              this.aiLogPlay(bestPlay, 'lowest in suit (trying to lose forced to win)');
              if (bestPlay !== -1) {
                return this.aiPlayLow(currentPlayer, bestPlay);
              }
            } else {
              bestPlay = highestIndexInSuit(currentPlayer.hand, winningCard.suit);
              this.aiLogPlay(bestPlay, 'highest in suit (trying to lose forced in suit, but cant win)');
              if (bestPlay !== -1) {
                return this.aiPlayHigh(currentPlayer, bestPlay);
              }
            }
          }
          if (bestPlay === -1) {
            if ((currentSuit !== Suit.SPADES) && (winningCard.suit === Suit.SPADES)) {
              bestPlay = highestValueIndexInSuitLowerThan(currentPlayer.hand, winningCard);
              this.aiLogPlay(bestPlay, 'trying to lose highest dumpable spade');
            }
          }
          if (bestPlay === -1) {
            bestPlay = highestValueNonSpadeIndex(currentPlayer.hand, winningCard.suit);
            this.aiLogPlay(bestPlay, 'trying to lose highest dumpable non-spade');
          }
        }
      }
      if (bestPlay !== -1) {
        if (this.aiPlay(currentPlayer, bestPlay)) {
          return true;
        } else {
          this.aiLog('not allowed to play my best play');
        }
      }
      this.aiLog('picking random card to play');
      startingPoint = Math.floor(Math.random() * currentPlayer.hand.length);
      return this.aiPlayLow(currentPlayer, startingPoint);
    }
    return false;
  };

  return Blackout;

})();

module.exports = {
  Card: Card,
  Blackout: Blackout,
  State: State,
  OK: OK
};

valuesOfSuit = function(hand, suit) {
  var card, l, len, v, values;
  values = [];
  for (l = 0, len = hand.length; l < len; l++) {
    v = hand[l];
    card = new Card(v);
    if (card.suit === suit) {
      values.push(card.value);
    }
  }
  return values;
};

stringifyCards = function(cards) {
  var card, l, len, t, v;
  t = '';
  for (l = 0, len = cards.length; l < len; l++) {
    v = cards[l];
    card = new Card(v);
    if (t) {
      t += ',';
    }
    t += card.name;
  }
  return '[' + t + ']';
};

lowestIndexInSuit = function(hand, suit) {
  var card, i, l, len, v;
  for (i = l = 0, len = hand.length; l < len; i = ++l) {
    v = hand[i];
    card = new Card(v);
    if (card.suit === suit) {
      return i;
    }
  }
  return -1;
};

highestIndexInSuit = function(hand, suit) {
  var card, i, l, v;
  for (i = l = hand.length - 1; l >= 0; i = l += -1) {
    v = hand[i];
    card = new Card(v);
    if (card.suit === suit) {
      return i;
    }
  }
  return -1;
};

lowestValueIndex = function(hand, avoidSuit) {
  var card, i, l, lowestIndex, lowestValue, ref;
  card = new Card(hand[0]);
  lowestIndex = 0;
  lowestValue = card.value;
  for (i = l = 1, ref = hand.length; 1 <= ref ? l < ref : l > ref; i = 1 <= ref ? ++l : --l) {
    card = new Card(hand[i]);
    if (card.suit !== avoidSuit) {
      if (card.value < lowestValue) {
        lowestValue = card.value;
        lowestIndex = i;
      }
    }
  }
  return lowestIndex;
};

highestValueNonSpadeIndex = function(hand, avoidSuit) {
  var card, highestIndex, highestValue, i, l, ref;
  highestIndex = -1;
  highestValue = -1;
  for (i = l = ref = hand.length - 1; l >= 0; i = l += -1) {
    card = new Card(hand[i]);
    if ((card.suit !== avoidSuit) && (card.suit !== Suit.SPADES)) {
      if (card.value > highestValue) {
        highestValue = card.value;
        highestIndex = i;
      }
    }
  }
  return highestIndex;
};

highestValueIndexInSuitLowerThan = function(hand, winningCard) {
  var card, i, l, ref;
  for (i = l = ref = hand.length - 1; l >= 0; i = l += -1) {
    card = new Card(hand[i]);
    if ((card.suit === winningCard.suit) && (card.value < winningCard.value)) {
      return i;
    }
  }
  return -1;
};



},{}],"FontRenderer":[function(require,module,exports){
var FontRenderer, fontmetrics;

fontmetrics = require('fontmetrics');

FontRenderer = (function() {
  function FontRenderer(game) {
    this.game = game;
  }

  FontRenderer.prototype.render = function(font, height, str, x, y, anchorx, anchory, color, cb) {
    var anchorOffsetX, anchorOffsetY, ch, code, currX, glyph, i, j, k, len, len1, metrics, results, scale, totalHeight, totalWidth;
    metrics = fontmetrics[font];
    if (!metrics) {
      return;
    }
    scale = height / metrics.height;
    totalWidth = 0;
    totalHeight = metrics.height * scale;
    for (i = j = 0, len = str.length; j < len; i = ++j) {
      ch = str[i];
      code = ch.charCodeAt(0);
      glyph = metrics.glyphs[code];
      if (!glyph) {
        continue;
      }
      totalWidth += glyph.xadvance * scale;
    }
    anchorOffsetX = -1 * anchorx * totalWidth;
    anchorOffsetY = -1 * anchory * totalHeight;
    currX = x;
    if (!color) {
      color = {
        r: 1,
        g: 1,
        b: 1,
        a: 1
      };
    }
    results = [];
    for (i = k = 0, len1 = str.length; k < len1; i = ++k) {
      ch = str[i];
      code = ch.charCodeAt(0);
      glyph = metrics.glyphs[code];
      if (!glyph) {
        continue;
      }
      this.game.drawImage(font, glyph.x, glyph.y, glyph.width, glyph.height, currX + (glyph.xoffset * scale) + anchorOffsetX, y + (glyph.yoffset * scale) + anchorOffsetY, glyph.width * scale, glyph.height * scale, 0, 0, 0, color.r, color.g, color.b, color.a);
      results.push(currX += glyph.xadvance * scale);
    }
    return results;
  };

  return FontRenderer;

})();

module.exports = FontRenderer;



},{"fontmetrics":"fontmetrics"}],"Game":[function(require,module,exports){
var AI_TICK_RATE_MS, Animation, Blackout, FontRenderer, Game, Hand, LOG_FONT, OK, State, ref;

Animation = require('Animation');

FontRenderer = require('FontRenderer');

Hand = require('Hand');

ref = require('Blackout'), Blackout = ref.Blackout, State = ref.State, OK = ref.OK;

AI_TICK_RATE_MS = 1000;

LOG_FONT = "unispace";

Game = (function() {
  function Game(_native, width, height) {
    this["native"] = _native;
    this.width = width;
    this.height = height;
    this.log("Game constructed: " + this.width + "x" + this.height);
    this.fontRenderer = new FontRenderer(this);
    this.zones = [];
    this.nextAITick = AI_TICK_RATE_MS;
    this.colors = {
      red: {
        r: 1,
        g: 0,
        b: 0,
        a: 1
      },
      white: {
        r: 1,
        g: 1,
        b: 1,
        a: 1
      }
    };
    this.blackout = new Blackout(this, {
      rounds: "13|13|13|13",
      players: [
        {
          id: 1,
          name: 'joe'
        }
      ]
    });
    this.blackout.addAI();
    this.blackout.addAI();
    this.blackout.addAI();
    this.log("next: " + this.blackout.next());
    this.log("player 0's hand: " + JSON.stringify(this.blackout.players[0].hand));
    this.lastErr = '';
    this.renderCommands = [];
    this.hand = new Hand(this, this.width, this.height);
    this.hand.set(this.blackout.players[0].hand);
  }

  Game.prototype.log = function(s) {
    return this["native"].log(s);
  };

  Game.prototype.load = function(data) {
    return this.log("load: " + data);
  };

  Game.prototype.save = function() {
    this.log("save");
    return "{}";
  };

  Game.prototype.makeHand = function(index) {
    var j, results, v;
    results = [];
    for (v = j = 0; j < 13; v = ++j) {
      if (v === index) {
        results.push(this.hand[v] = 13);
      } else {
        results.push(this.hand[v] = v);
      }
    }
    return results;
  };

  Game.prototype.touchDown = function(x, y) {
    this.log("touchDown (CS) " + x + "," + y);
    return this.checkZones(x, y);
  };

  Game.prototype.touchMove = function(x, y) {
    return this.hand.move(x, y);
  };

  Game.prototype.touchUp = function(x, y) {
    return this.hand.up(x, y);
  };

  Game.prototype.play = function(cardToPlay, x, y, r) {
    var card, j, len, newCards, ref1, ret, v;
    this.log("(game) playing card " + cardToPlay);
    if (this.blackout.state === State.BID) {
      this.blackout.bid({
        id: 1,
        bid: 0,
        ai: false
      });
    }
    if (this.blackout.state === State.TRICK) {
      ret = this.blackout.play({
        id: 1,
        which: cardToPlay
      });
      this.lastErr = ret;
      if (ret === OK) {
        this.hand.set(this.blackout.players[0].hand);
      }
    }
    if (0) {
      newCards = [];
      ref1 = this.hand.cards;
      for (j = 0, len = ref1.length; j < len; j++) {
        card = ref1[j];
        if (card !== cardToPlay) {
          newCards.push(card);
        }
      }
      if (newCards.length === 0) {
        newCards = (function() {
          var k, results;
          results = [];
          for (v = k = 30; k <= 42; v = ++k) {
            results.push(v);
          }
          return results;
        })();
      }
      return this.hand.set(newCards);
    }
  };

  Game.prototype.update = function(dt) {
    var updated;
    this.zones.length = 0;
    updated = false;
    this.nextAITick -= dt;
    if (this.nextAITick <= 0) {
      this.nextAITick = AI_TICK_RATE_MS;
      if (this.blackout.aiTick()) {
        updated = true;
      }
    }
    if (this.hand.update(dt)) {
      updated = true;
    }
    return updated;
  };

  Game.prototype.render = function() {
    var headline, i, j, k, len, len1, line, player, ref1, ref2, textHeight, textPadding;
    this.renderCommands.length = 0;
    textHeight = this.height / 30;
    textPadding = textHeight / 2;
    headline = "State: " + this.blackout.state + ", Turn: " + this.blackout.players[this.blackout.turn].name + " Err: " + this.lastErr;
    this.fontRenderer.render(LOG_FONT, textHeight, headline, 0, 0, 0, 0, this.colors.red);
    ref1 = this.blackout.log;
    for (i = j = 0, len = ref1.length; j < len; i = ++j) {
      line = ref1[i];
      this.fontRenderer.render(LOG_FONT, textHeight, line, 0, (i + 1) * (textHeight + textPadding), 0, 0, this.colors.white);
    }
    ref2 = this.blackout.players;
    for (i = k = 0, len1 = ref2.length; k < len1; i = ++k) {
      player = ref2[i];
      this.fontRenderer.render(LOG_FONT, textHeight, player.name, this.width, i * (textHeight + textPadding), 1, 0, this.colors.red);
    }
    this.hand.render();
    return this.renderCommands;
  };

  Game.prototype.drawImage = function(texture, sx, sy, sw, sh, dx, dy, dw, dh, rot, anchorx, anchory, r, g, b, a, cb) {
    var anchorOffsetX, anchorOffsetY, zone;
    this.renderCommands.push([texture, sx, sy, sw, sh, dx, dy, dw, dh, rot, anchorx, anchory, r, g, b, a]);
    if (cb != null) {
      anchorOffsetX = -1 * anchorx * dw;
      anchorOffsetY = -1 * anchory * dh;
      zone = {
        cx: dx,
        cy: dy,
        rot: rot * -1,
        l: anchorOffsetX,
        t: anchorOffsetY,
        r: anchorOffsetX + dw,
        b: anchorOffsetY + dh,
        cb: cb
      };
      return this.zones.push(zone);
    }
  };

  Game.prototype.checkZones = function(x, y) {
    var j, localX, localY, ref1, unrotatedLocalX, unrotatedLocalY, zone;
    ref1 = this.zones;
    for (j = ref1.length - 1; j >= 0; j += -1) {
      zone = ref1[j];
      unrotatedLocalX = x - zone.cx;
      unrotatedLocalY = y - zone.cy;
      localX = unrotatedLocalX * Math.cos(zone.rot) - unrotatedLocalY * Math.sin(zone.rot);
      localY = unrotatedLocalX * Math.sin(zone.rot) + unrotatedLocalY * Math.cos(zone.rot);
      if ((localX < zone.l) || (localX > zone.r) || (localY < zone.t) || (localY > zone.b)) {
        continue;
      }
      zone.cb(x, y);
      return true;
    }
    return false;
  };

  return Game;

})();

module.exports = Game;



},{"Animation":"Animation","Blackout":"Blackout","FontRenderer":"FontRenderer","Hand":"Hand"}],"Hand":[function(require,module,exports){
var Animation, CARD_HAND_CURVE_DIST_FACTOR, CARD_HOLDING_ROT_ORDER, CARD_HOLDING_ROT_PLAY, CARD_IMAGE_ADV_X, CARD_IMAGE_ADV_Y, CARD_IMAGE_H, CARD_IMAGE_OFF_X, CARD_IMAGE_OFF_Y, CARD_IMAGE_W, CARD_PLAY_CEILING, CARD_RENDER_SCALE, Hand, NO_CARD, calcDistance, calcDistanceSquared, findAngle;

Animation = require('Animation');

CARD_IMAGE_W = 120;

CARD_IMAGE_H = 162;

CARD_IMAGE_OFF_X = 4;

CARD_IMAGE_OFF_Y = 4;

CARD_IMAGE_ADV_X = CARD_IMAGE_W;

CARD_IMAGE_ADV_Y = CARD_IMAGE_H;

CARD_RENDER_SCALE = 0.4;

CARD_HAND_CURVE_DIST_FACTOR = 1.5;

CARD_HOLDING_ROT_ORDER = Math.PI / 12;

CARD_HOLDING_ROT_PLAY = Math.PI / 2;

CARD_PLAY_CEILING = 0.45;

NO_CARD = -1;

findAngle = function(p0, p1, p2) {
  var a, b, c;
  a = Math.pow(p1.x - p2.x, 2) + Math.pow(p1.y - p2.y, 2);
  b = Math.pow(p1.x - p0.x, 2) + Math.pow(p1.y - p0.y, 2);
  c = Math.pow(p2.x - p0.x, 2) + Math.pow(p2.y - p0.y, 2);
  return Math.acos((a + b - c) / Math.sqrt(4 * a * b));
};

calcDistance = function(p0, p1) {
  return Math.sqrt(Math.pow(p1.x - p0.x, 2) + Math.pow(p1.y - p0.y, 2));
};

calcDistanceSquared = function(x0, y0, x1, y1) {
  return Math.pow(x1 - x0, 2) + Math.pow(y1 - y0, 2);
};

Hand = (function() {
  function Hand(game, screenWidth, screenHeight) {
    var arcMargin, arcVerticalBias, bottomLeft, bottomRight;
    this.game = game;
    this.screenWidth = screenWidth;
    this.screenHeight = screenHeight;
    this.cards = [];
    this.anims = {};
    this.positionCache = {};
    this.dragIndexStart = NO_CARD;
    this.dragIndexCurrent = NO_CARD;
    this.dragX = 0;
    this.dragY = 0;
    this.cardSpeed = {
      r: Math.PI * 2,
      s: 0.5,
      t: 2 * this.screenWidth
    };
    this.playCeiling = CARD_PLAY_CEILING * this.screenHeight;
    this.cardHeight = Math.floor(this.screenHeight * CARD_RENDER_SCALE);
    this.cardWidth = Math.floor(this.cardHeight * CARD_IMAGE_W / CARD_IMAGE_H);
    arcMargin = this.cardWidth / 1.5;
    arcVerticalBias = this.cardHeight / 50;
    bottomLeft = {
      x: arcMargin,
      y: arcVerticalBias + this.screenHeight
    };
    bottomRight = {
      x: this.screenWidth - arcMargin,
      y: arcVerticalBias + this.screenHeight
    };
    this.handCenter = {
      x: this.screenWidth / 2,
      y: arcVerticalBias + this.screenHeight + (CARD_HAND_CURVE_DIST_FACTOR * this.screenHeight)
    };
    this.handAngle = findAngle(bottomLeft, this.handCenter, bottomRight);
    this.handDistance = calcDistance(bottomLeft, this.handCenter);
    this.handAngleAdvance = this.handAngle / 13;
    this.game.log("Hand distance " + this.handDistance + ", angle " + this.handAngle + " (screen height " + this.screenHeight + ")");
  }

  Hand.prototype.set = function(cards) {
    this.cards = cards.slice(0);
    this.syncAnims();
    return this.warp();
  };

  Hand.prototype.syncAnims = function() {
    var anim, card, j, k, len, len1, ref, ref1, seen, toRemove;
    seen = {};
    ref = this.cards;
    for (j = 0, len = ref.length; j < len; j++) {
      card = ref[j];
      seen[card]++;
      if (!this.anims[card]) {
        this.anims[card] = new Animation({
          speed: this.cardSpeed,
          x: 0,
          y: 0,
          r: 0
        });
      }
    }
    toRemove = [];
    ref1 = this.anims;
    for (card in ref1) {
      anim = ref1[card];
      if (!seen.hasOwnProperty(card)) {
        toRemove.push(card);
      }
    }
    for (k = 0, len1 = toRemove.length; k < len1; k++) {
      card = toRemove[k];
      this.game.log("removing anim for " + card);
      delete this.anims[card];
    }
    return this.updatePositions();
  };

  Hand.prototype.calcDrawnHand = function() {
    var card, drawnHand, i, j, len, ref;
    drawnHand = [];
    ref = this.cards;
    for (i = j = 0, len = ref.length; j < len; i = ++j) {
      card = ref[i];
      if (i !== this.dragIndexStart) {
        drawnHand.push(card);
      }
    }
    if (this.dragIndexCurrent !== NO_CARD) {
      drawnHand.splice(this.dragIndexCurrent, 0, this.cards[this.dragIndexStart]);
    }
    return drawnHand;
  };

  Hand.prototype.wantsToPlayDraggedCard = function() {
    if (this.dragIndexStart === NO_CARD) {
      return false;
    }
    return this.dragY < this.playCeiling;
  };

  Hand.prototype.updatePositions = function() {
    var anim, card, desiredRotation, drawIndex, drawnHand, i, j, len, pos, positionCount, positions, results, wantsToPlay;
    drawnHand = this.calcDrawnHand();
    wantsToPlay = this.wantsToPlayDraggedCard();
    desiredRotation = CARD_HOLDING_ROT_ORDER;
    positionCount = drawnHand.length;
    if (wantsToPlay) {
      desiredRotation = CARD_HOLDING_ROT_PLAY;
      positionCount--;
    }
    positions = this.calcPositions(positionCount);
    drawIndex = 0;
    results = [];
    for (i = j = 0, len = drawnHand.length; j < len; i = ++j) {
      card = drawnHand[i];
      anim = this.anims[card];
      if (i === this.dragIndexCurrent) {
        anim.req.x = this.dragX;
        anim.req.y = this.dragY;
        anim.req.r = desiredRotation;
        if (!wantsToPlay) {
          results.push(drawIndex++);
        } else {
          results.push(void 0);
        }
      } else {
        pos = positions[drawIndex];
        anim.req.x = pos.x;
        anim.req.y = pos.y;
        anim.req.r = pos.r;
        results.push(drawIndex++);
      }
    }
    return results;
  };

  Hand.prototype.warp = function() {
    var anim, card, ref, results;
    ref = this.anims;
    results = [];
    for (card in ref) {
      anim = ref[card];
      results.push(anim.warp());
    }
    return results;
  };

  Hand.prototype.reorder = function() {
    var closestDist, closestIndex, dist, index, j, len, pos, positions;
    if (this.dragIndexStart === NO_CARD) {
      return;
    }
    if (this.cards.length < 2) {
      return;
    }
    positions = this.calcPositions(this.cards.length);
    closestIndex = 0;
    closestDist = this.screenWidth * this.screenHeight;
    for (index = j = 0, len = positions.length; j < len; index = ++j) {
      pos = positions[index];
      dist = calcDistanceSquared(pos.x, pos.y, this.dragX, this.dragY);
      if (closestDist > dist) {
        closestDist = dist;
        closestIndex = index;
      }
    }
    return this.dragIndexCurrent = closestIndex;
  };

  Hand.prototype.down = function(dragX, dragY, index) {
    this.dragX = dragX;
    this.dragY = dragY;
    this.up(this.dragX, this.dragY);
    this.game.log("picking up card index " + index);
    this.dragIndexStart = index;
    this.dragIndexCurrent = index;
    return this.updatePositions();
  };

  Hand.prototype.move = function(dragX, dragY) {
    this.dragX = dragX;
    this.dragY = dragY;
    if (this.dragIndexStart === NO_CARD) {
      return;
    }
    this.reorder();
    return this.updatePositions();
  };

  Hand.prototype.up = function(dragX, dragY) {
    var anim, card;
    this.dragX = dragX;
    this.dragY = dragY;
    if (this.dragIndexStart === NO_CARD) {
      return;
    }
    this.reorder();
    if (this.wantsToPlayDraggedCard()) {
      this.game.log("trying to play a " + this.cards[this.dragIndexStart] + " from index " + this.dragIndexStart);
      card = this.cards[this.dragIndexStart];
      anim = this.anims[card];
      this.dragIndexStart = NO_CARD;
      this.dragIndexCurrent = NO_CARD;
      this.game.play(card, anim.cur.x, anim.cur.y, anim.cur.r);
    } else {
      this.game.log("trying to reorder " + this.cards[this.dragIndexStart] + " into index " + this.dragIndexCurrent);
      this.cards = this.calcDrawnHand();
    }
    this.dragIndexStart = NO_CARD;
    this.dragIndexCurrent = NO_CARD;
    return this.updatePositions();
  };

  Hand.prototype.update = function(dt) {
    var anim, card, ref, updated;
    updated = false;
    ref = this.anims;
    for (card in ref) {
      anim = ref[card];
      if (anim.update(dt)) {
        updated = true;
      }
    }
    return updated;
  };

  Hand.prototype.render = function() {
    var anim, drawnHand, index, j, len, results, v;
    if (this.cards.length === 0) {
      return;
    }
    drawnHand = this.calcDrawnHand();
    results = [];
    for (index = j = 0, len = drawnHand.length; j < len; index = ++j) {
      v = drawnHand[index];
      if (v === NO_CARD) {
        continue;
      }
      anim = this.anims[v];
      results.push((function(_this) {
        return function(anim, index) {
          return _this.renderCard(v, anim.cur.x, anim.cur.y, anim.cur.r, function(clickX, clickY) {
            return _this.down(clickX, clickY, index);
          });
        };
      })(this)(anim, index));
    }
    return results;
  };

  Hand.prototype.renderCard = function(v, x, y, rot, cb) {
    var rank, suit;
    if (!rot) {
      rot = 0;
    }
    rank = Math.floor(v % 13);
    suit = Math.floor(v / 13);
    return this.game.drawImage("cards", CARD_IMAGE_OFF_X + (CARD_IMAGE_ADV_X * rank), CARD_IMAGE_OFF_Y + (CARD_IMAGE_ADV_Y * suit), CARD_IMAGE_W, CARD_IMAGE_H, x, y, this.cardWidth, this.cardHeight, rot, 0.5, 0.5, 1, 1, 1, 1, cb);
  };

  Hand.prototype.calcPositions = function(handSize) {
    var angleLeftover, angleSpread, currentAngle, i, j, positions, ref, x, y;
    if (this.positionCache.hasOwnProperty(handSize)) {
      return this.positionCache[handSize];
    }
    angleSpread = this.handAngleAdvance * handSize;
    angleLeftover = this.handAngle - angleSpread;
    currentAngle = -1 * (this.handAngle / 2);
    currentAngle += angleLeftover / 2;
    currentAngle += this.handAngleAdvance / 2;
    positions = [];
    for (i = j = 0, ref = handSize; 0 <= ref ? j < ref : j > ref; i = 0 <= ref ? ++j : --j) {
      x = this.handCenter.x - Math.cos((Math.PI / 2) + currentAngle) * this.handDistance;
      y = this.handCenter.y - Math.sin((Math.PI / 2) + currentAngle) * this.handDistance;
      currentAngle += this.handAngleAdvance;
      positions.push({
        x: x,
        y: y,
        r: currentAngle
      });
    }
    this.positionCache[handSize] = positions;
    return positions;
  };

  Hand.prototype.renderHand = function() {
    var index, j, len, ref, results, v;
    if (this.hand.length === 0) {
      return;
    }
    ref = this.hand;
    results = [];
    for (index = j = 0, len = ref.length; j < len; index = ++j) {
      v = ref[index];
      results.push((function(_this) {
        return function(index) {
          return _this.renderCard(v, x, y, currentAngle, function(clickX, clickY) {
            return _this.down(clickX, clickY, index);
          });
        };
      })(this)(index));
    }
    return results;
  };

  return Hand;

})();

module.exports = Hand;



},{"Animation":"Animation"}],"fontmetrics":[function(require,module,exports){
module.exports = {
  unispace: {
    height: 86,
    glyphs: {
      '97': {
        x: 8,
        y: 8,
        width: 44,
        height: 51,
        xoffset: 0,
        yoffset: 23,
        xadvance: 44
      },
      '98': {
        x: 8,
        y: 67,
        width: 43,
        height: 65,
        xoffset: 1,
        yoffset: 8,
        xadvance: 44
      },
      '99': {
        x: 8,
        y: 140,
        width: 41,
        height: 51,
        xoffset: 1,
        yoffset: 23,
        xadvance: 44
      },
      '100': {
        x: 8,
        y: 199,
        width: 43,
        height: 65,
        xoffset: 1,
        yoffset: 8,
        xadvance: 44
      },
      '101': {
        x: 57,
        y: 140,
        width: 43,
        height: 51,
        xoffset: 1,
        yoffset: 23,
        xadvance: 44
      },
      '102': {
        x: 59,
        y: 67,
        width: 42,
        height: 65,
        xoffset: 1,
        yoffset: 8,
        xadvance: 44
      },
      '103': {
        x: 8,
        y: 272,
        width: 43,
        height: 68,
        xoffset: 1,
        yoffset: 23,
        xadvance: 44
      },
      '104': {
        x: 8,
        y: 348,
        width: 43,
        height: 65,
        xoffset: 1,
        yoffset: 8,
        xadvance: 44
      },
      '105': {
        x: 8,
        y: 421,
        width: 42,
        height: 65,
        xoffset: 1,
        yoffset: 8,
        xadvance: 44
      },
      '106': {
        x: 58,
        y: 421,
        width: 33,
        height: 83,
        xoffset: 6,
        yoffset: 8,
        xadvance: 44
      },
      '107': {
        x: 59,
        y: 199,
        width: 43,
        height: 65,
        xoffset: 1,
        yoffset: 8,
        xadvance: 44
      },
      '108': {
        x: 59,
        y: 272,
        width: 42,
        height: 65,
        xoffset: 1,
        yoffset: 8,
        xadvance: 44
      },
      '109': {
        x: 108,
        y: 140,
        width: 44,
        height: 51,
        xoffset: 0,
        yoffset: 23,
        xadvance: 44
      },
      '110': {
        x: 60,
        y: 8,
        width: 43,
        height: 51,
        xoffset: 1,
        yoffset: 23,
        xadvance: 44
      },
      '111': {
        x: 109,
        y: 67,
        width: 45,
        height: 51,
        xoffset: 0,
        yoffset: 23,
        xadvance: 44
      },
      '112': {
        x: 59,
        y: 345,
        width: 44,
        height: 68,
        xoffset: 0,
        yoffset: 23,
        xadvance: 44
      },
      '113': {
        x: 99,
        y: 421,
        width: 43,
        height: 68,
        xoffset: 1,
        yoffset: 23,
        xadvance: 44
      },
      '114': {
        x: 111,
        y: 8,
        width: 40,
        height: 51,
        xoffset: 2,
        yoffset: 23,
        xadvance: 44
      },
      '115': {
        x: 159,
        y: 8,
        width: 45,
        height: 51,
        xoffset: 0,
        yoffset: 23,
        xadvance: 44
      },
      '116': {
        x: 109,
        y: 272,
        width: 42,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '117': {
        x: 110,
        y: 199,
        width: 43,
        height: 51,
        xoffset: 1,
        yoffset: 23,
        xadvance: 44
      },
      '118': {
        x: 160,
        y: 126,
        width: 45,
        height: 51,
        xoffset: 0,
        yoffset: 23,
        xadvance: 44
      },
      '119': {
        x: 162,
        y: 67,
        width: 47,
        height: 51,
        xoffset: -1,
        yoffset: 23,
        xadvance: 44
      },
      '120': {
        x: 212,
        y: 8,
        width: 44,
        height: 51,
        xoffset: 0,
        yoffset: 23,
        xadvance: 44
      },
      '121': {
        x: 111,
        y: 343,
        width: 46,
        height: 68,
        xoffset: -1,
        yoffset: 23,
        xadvance: 44
      },
      '122': {
        x: 159,
        y: 258,
        width: 40,
        height: 51,
        xoffset: 2,
        yoffset: 23,
        xadvance: 44
      },
      '65': {
        x: 161,
        y: 185,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '66': {
        x: 150,
        y: 419,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '67': {
        x: 165,
        y: 317,
        width: 40,
        height: 63,
        xoffset: 2,
        yoffset: 11,
        xadvance: 44
      },
      '68': {
        x: 202,
        y: 388,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '69': {
        x: 213,
        y: 126,
        width: 41,
        height: 63,
        xoffset: 2,
        yoffset: 11,
        xadvance: 44
      },
      '70': {
        x: 213,
        y: 197,
        width: 42,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '71': {
        x: 213,
        y: 268,
        width: 42,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '72': {
        x: 262,
        y: 67,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '73': {
        x: 253,
        y: 339,
        width: 41,
        height: 63,
        xoffset: 2,
        yoffset: 11,
        xadvance: 44
      },
      '74': {
        x: 253,
        y: 410,
        width: 41,
        height: 63,
        xoffset: 2,
        yoffset: 11,
        xadvance: 44
      },
      '75': {
        x: 263,
        y: 138,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '76': {
        x: 263,
        y: 209,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '77': {
        x: 302,
        y: 280,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '78': {
        x: 302,
        y: 351,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '79': {
        x: 302,
        y: 422,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '80': {
        x: 314,
        y: 8,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '81': {
        x: 314,
        y: 79,
        width: 44,
        height: 71,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '82': {
        x: 365,
        y: 8,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '83': {
        x: 314,
        y: 158,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '84': {
        x: 353,
        y: 229,
        width: 40,
        height: 63,
        xoffset: 2,
        yoffset: 11,
        xadvance: 44
      },
      '85': {
        x: 365,
        y: 158,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '86': {
        x: 366,
        y: 79,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '87': {
        x: 416,
        y: 8,
        width: 48,
        height: 63,
        xoffset: -2,
        yoffset: 11,
        xadvance: 44
      },
      '88': {
        x: 353,
        y: 300,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '89': {
        x: 401,
        y: 229,
        width: 45,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '90': {
        x: 416,
        y: 150,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '33': {
        x: 418,
        y: 79,
        width: 16,
        height: 63,
        xoffset: 14,
        yoffset: 11,
        xadvance: 44
      },
      '59': {
        x: 442,
        y: 79,
        width: 16,
        height: 52,
        xoffset: 14,
        yoffset: 35,
        xadvance: 44
      },
      '37': {
        x: 466,
        y: 79,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '58': {
        x: 213,
        y: 339,
        width: 16,
        height: 38,
        xoffset: 14,
        yoffset: 35,
        xadvance: 44
      },
      '63': {
        x: 472,
        y: 8,
        width: 42,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '42': {
        x: 217,
        y: 67,
        width: 36,
        height: 36,
        xoffset: 4,
        yoffset: 11,
        xadvance: 44
      },
      '40': {
        x: 354,
        y: 371,
        width: 28,
        height: 91,
        xoffset: 8,
        yoffset: 0,
        xadvance: 44
      },
      '41': {
        x: 390,
        y: 371,
        width: 28,
        height: 91,
        xoffset: 8,
        yoffset: 0,
        xadvance: 44
      },
      '95': {
        x: 150,
        y: 493,
        width: 49,
        height: 11,
        xoffset: -2,
        yoffset: 79,
        xadvance: 44
      },
      '43': {
        x: 354,
        y: 470,
        width: 37,
        height: 34,
        xoffset: 4,
        yoffset: 23,
        xadvance: 44
      },
      '45': {
        x: 8,
        y: 494,
        width: 41,
        height: 9,
        xoffset: 1,
        yoffset: 39,
        xadvance: 44
      },
      '61': {
        x: 202,
        y: 459,
        width: 34,
        height: 25,
        xoffset: 5,
        yoffset: 26,
        xadvance: 44
      },
      '46': {
        x: 165,
        y: 388,
        width: 14,
        height: 13,
        xoffset: 15,
        yoffset: 60,
        xadvance: 44
      },
      '44': {
        x: 399,
        y: 470,
        width: 16,
        height: 26,
        xoffset: 14,
        yoffset: 60,
        xadvance: 44
      },
      '47': {
        x: 404,
        y: 300,
        width: 41,
        height: 63,
        xoffset: 2,
        yoffset: 11,
        xadvance: 44
      },
      '124': {
        x: 426,
        y: 371,
        width: 11,
        height: 91,
        xoffset: 17,
        yoffset: 0,
        xadvance: 44
      },
      '34': {
        x: 244,
        y: 481,
        width: 24,
        height: 22,
        xoffset: 10,
        yoffset: 7,
        xadvance: 44
      },
      '39': {
        x: 276,
        y: 481,
        width: 11,
        height: 22,
        xoffset: 17,
        yoffset: 7,
        xadvance: 44
      },
      '64': {
        x: 445,
        y: 371,
        width: 41,
        height: 63,
        xoffset: 2,
        yoffset: 23,
        xadvance: 44
      },
      '35': {
        x: 453,
        y: 300,
        width: 38,
        height: 63,
        xoffset: 3,
        yoffset: 11,
        xadvance: 44
      },
      '36': {
        x: 454,
        y: 221,
        width: 45,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '94': {
        x: 423,
        y: 470,
        width: 47,
        height: 30,
        xoffset: -1,
        yoffset: 11,
        xadvance: 44
      },
      '38': {
        x: 467,
        y: 150,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '123': {
        x: 494,
        y: 371,
        width: 31,
        height: 91,
        xoffset: 7,
        yoffset: 0,
        xadvance: 44
      },
      '125': {
        x: 507,
        y: 221,
        width: 32,
        height: 91,
        xoffset: 6,
        yoffset: 0,
        xadvance: 44
      },
      '91': {
        x: 518,
        y: 79,
        width: 28,
        height: 91,
        xoffset: 8,
        yoffset: 0,
        xadvance: 44
      },
      '93': {
        x: 533,
        y: 320,
        width: 28,
        height: 91,
        xoffset: 8,
        yoffset: 0,
        xadvance: 44
      },
      '48': {
        x: 522,
        y: 8,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '49': {
        x: 533,
        y: 419,
        width: 42,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '50': {
        x: 547,
        y: 178,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '51': {
        x: 547,
        y: 249,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '52': {
        x: 569,
        y: 320,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '53': {
        x: 554,
        y: 79,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '54': {
        x: 573,
        y: 8,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '55': {
        x: 583,
        y: 391,
        width: 44,
        height: 63,
        xoffset: 0,
        yoffset: 11,
        xadvance: 44
      },
      '56': {
        x: 598,
        y: 150,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 11,
        xadvance: 44
      },
      '57': {
        x: 606,
        y: 79,
        width: 43,
        height: 63,
        xoffset: 1,
        yoffset: 10,
        xadvance: 44
      },
      '32': {
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        xoffset: 1,
        yoffset: 10,
        xadvance: 44
      }
    }
  },
  square: {
    height: 73,
    glyphs: {
      '97': {
        x: 8,
        y: 8,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '98': {
        x: 8,
        y: 61,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '99': {
        x: 8,
        y: 114,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 43
      },
      '100': {
        x: 8,
        y: 167,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 44
      },
      '101': {
        x: 8,
        y: 220,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 43
      },
      '102': {
        x: 8,
        y: 273,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 43
      },
      '103': {
        x: 8,
        y: 326,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 44
      },
      '104': {
        x: 8,
        y: 379,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '105': {
        x: 8,
        y: 432,
        width: 11,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 12
      },
      '106': {
        x: 27,
        y: 432,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '107': {
        x: 61,
        y: 8,
        width: 46,
        height: 45,
        xoffset: -2,
        yoffset: 18,
        xadvance: 45
      },
      '108': {
        x: 61,
        y: 61,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 43
      },
      '109': {
        x: 61,
        y: 114,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '110': {
        x: 61,
        y: 167,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '111': {
        x: 61,
        y: 220,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '112': {
        x: 61,
        y: 273,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 44
      },
      '113': {
        x: 61,
        y: 326,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '114': {
        x: 61,
        y: 379,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 44
      },
      '115': {
        x: 80,
        y: 432,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 44
      },
      '116': {
        x: 114,
        y: 61,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 43
      },
      '117': {
        x: 115,
        y: 8,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '118': {
        x: 114,
        y: 114,
        width: 46,
        height: 45,
        xoffset: -3,
        yoffset: 19,
        xadvance: 43
      },
      '119': {
        x: 167,
        y: 61,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '120': {
        x: 168,
        y: 8,
        width: 46,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 45
      },
      '121': {
        x: 114,
        y: 167,
        width: 46,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 43
      },
      '122': {
        x: 114,
        y: 220,
        width: 45,
        height: 45,
        xoffset: -2,
        yoffset: 19,
        xadvance: 44
      },
      '65': {
        x: 114,
        y: 273,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '66': {
        x: 114,
        y: 343,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '67': {
        x: 133,
        y: 413,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 64
      },
      '68': {
        x: 168,
        y: 114,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 61
      },
      '69': {
        x: 168,
        y: 184,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 64
      },
      '70': {
        x: 222,
        y: 8,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 64
      },
      '71': {
        x: 184,
        y: 254,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 63
      },
      '72': {
        x: 184,
        y: 324,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 63
      },
      '73': {
        x: 203,
        y: 394,
        width: 13,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 14
      },
      '74': {
        x: 224,
        y: 394,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '75': {
        x: 238,
        y: 78,
        width: 64,
        height: 63,
        xoffset: -2,
        yoffset: 1,
        xadvance: 61
      },
      '76': {
        x: 292,
        y: 8,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '77': {
        x: 238,
        y: 149,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '78': {
        x: 254,
        y: 219,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '79': {
        x: 308,
        y: 149,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '80': {
        x: 310,
        y: 78,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '81': {
        x: 362,
        y: 8,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '82': {
        x: 254,
        y: 289,
        width: 62,
        height: 63,
        xoffset: -2,
        yoffset: 1,
        xadvance: 61
      },
      '83': {
        x: 294,
        y: 360,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 61
      },
      '84': {
        x: 294,
        y: 430,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '85': {
        x: 324,
        y: 219,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '86': {
        x: 378,
        y: 148,
        width: 63,
        height: 62,
        xoffset: -3,
        yoffset: 1,
        xadvance: 61
      },
      '87': {
        x: 380,
        y: 78,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '88': {
        x: 432,
        y: 8,
        width: 64,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '89': {
        x: 324,
        y: 289,
        width: 63,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '90': {
        x: 394,
        y: 218,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '33': {
        x: 449,
        y: 148,
        width: 10,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 10
      },
      '59': {
        x: 450,
        y: 78,
        width: 16,
        height: 50,
        xoffset: -2,
        yoffset: 24,
        xadvance: 16
      },
      '37': {
        x: 364,
        y: 359,
        width: 64,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 60
      },
      '58': {
        x: 203,
        y: 464,
        width: 16,
        height: 39,
        xoffset: -2,
        yoffset: 24,
        xadvance: 16
      },
      '63': {
        x: 395,
        y: 288,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '42': {
        x: 227,
        y: 464,
        width: 28,
        height: 27,
        xoffset: -2,
        yoffset: 1,
        xadvance: 28
      },
      '40': {
        x: 364,
        y: 429,
        width: 16,
        height: 65,
        xoffset: -2,
        yoffset: 0,
        xadvance: 15
      },
      '41': {
        x: 388,
        y: 429,
        width: 16,
        height: 65,
        xoffset: -2,
        yoffset: 0,
        xadvance: 16
      },
      '95': {
        x: 464,
        y: 218,
        width: 31,
        height: 62,
        xoffset: 3,
        yoffset: 1,
        xadvance: 36
      },
      '43': {
        x: 467,
        y: 136,
        width: 39,
        height: 39,
        xoffset: -2,
        yoffset: 12,
        xadvance: 37
      },
      '45': {
        x: 254,
        y: 360,
        width: 27,
        height: 9,
        xoffset: -2,
        yoffset: 25,
        xadvance: 27
      },
      '61': {
        x: 467,
        y: 183,
        width: 39,
        height: 27,
        xoffset: -2,
        yoffset: 19,
        xadvance: 38
      },
      '46': {
        x: 8,
        y: 485,
        width: 16,
        height: 16,
        xoffset: -2,
        yoffset: 47,
        xadvance: 17
      },
      '44': {
        x: 220,
        y: 78,
        width: 10,
        height: 22,
        xoffset: -2,
        yoffset: 45,
        xadvance: 11
      },
      '47': {
        x: 412,
        y: 429,
        width: 64,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '124': {
        x: 436,
        y: 358,
        width: 31,
        height: 62,
        xoffset: 3,
        yoffset: 1,
        xadvance: 36
      },
      '34': {
        x: 474,
        y: 78,
        width: 27,
        height: 22,
        xoffset: -2,
        yoffset: 1,
        xadvance: 29
      },
      '39': {
        x: 32,
        y: 485,
        width: 9,
        height: 16,
        xoffset: -2,
        yoffset: 1,
        xadvance: 10
      },
      '64': {
        x: 504,
        y: 8,
        width: 31,
        height: 62,
        xoffset: 3,
        yoffset: 1,
        xadvance: 36
      },
      '35': {
        x: 509,
        y: 78,
        width: 39,
        height: 39,
        xoffset: -2,
        yoffset: 14,
        xadvance: 38
      },
      '36': {
        x: 543,
        y: 8,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '94': {
        x: 465,
        y: 288,
        width: 31,
        height: 62,
        xoffset: 3,
        yoffset: 1,
        xadvance: 36
      },
      '38': {
        x: 503,
        y: 218,
        width: 31,
        height: 62,
        xoffset: 3,
        yoffset: 1,
        xadvance: 36
      },
      '123': {
        x: 475,
        y: 358,
        width: 31,
        height: 62,
        xoffset: 3,
        yoffset: 1,
        xadvance: 36
      },
      '125': {
        x: 504,
        y: 288,
        width: 31,
        height: 62,
        xoffset: 3,
        yoffset: 1,
        xadvance: 36
      },
      '91': {
        x: 484,
        y: 428,
        width: 27,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 26
      },
      '93': {
        x: 514,
        y: 358,
        width: 27,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 27
      },
      '48': {
        x: 519,
        y: 428,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '49': {
        x: 514,
        y: 125,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '50': {
        x: 542,
        y: 195,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '51': {
        x: 543,
        y: 265,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '52': {
        x: 549,
        y: 335,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 61
      },
      '53': {
        x: 589,
        y: 405,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '54': {
        x: 584,
        y: 78,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '55': {
        x: 613,
        y: 8,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '56': {
        x: 612,
        y: 148,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '57': {
        x: 654,
        y: 78,
        width: 62,
        height: 62,
        xoffset: -2,
        yoffset: 1,
        xadvance: 62
      },
      '32': {
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        xoffset: -2,
        yoffset: 1,
        xadvance: 22
      }
    }
  }
};



},{}]},{},[]);
// Generated by CoffeeScript 1.9.1
var Game, game_, load, render, save, shutdown, startup, touchDown, touchMove, touchUp, update;

Game = require('Game');

game_ = null;

startup = function(width, height) {
  var nativeApp;
  nativeApp = {
    log: nativeLog
  };
  game_ = new Game(nativeApp, width, height);
};

shutdown = function() {};

update = function(dt) {
  return game_.update(dt);
};

render = function() {
  return game_.render();
};

load = function(data) {
  game_.load(data);
};

save = function() {
  return game_.save();
};

touchDown = function(x, y) {
  game_.touchDown(x, y);
};

touchMove = function(x, y) {
  game_.touchMove(x, y);
};

touchUp = function(x, y) {
  game_.touchUp(x, y);
};
