class_name BlandCard
extends RefCounted
## One card: a pair card (A-10), a special card, or a Joker.
##
## Cards are plain data objects (not scene nodes). The game logic (bland_game.gd)
## moves BlandCard instances between hands, and the table (game_table.gd) turns them into
## pictures and text using helpers such as texture_file() and display_name().

# The three families of card in the deck:
#   PAIR    - the scoring cards (Ace-10 in four suits). Two with the same rank make a pair.
#   SPECIAL - action cards with a one-off effect (see Special below).
#   JOKER   - the "Old Maid": it can never be paired, and costs points if you still hold it at round end.
enum Kind { PAIR, SPECIAL, JOKER }

# The six special-card effects. What each one does is described in SPECIAL_HELP below;
# the actual rules are implemented in bland_game.gd (play_skip, play_reverse, ...).
enum Special { SKIP, REVERSE, GIVE, FREEZE, ANGEL, VISION }


# ============================================================================
# CONSTANTS (lookup tables)
# ============================================================================

# Suit order matters: sort_key() uses each suit's position in this list to break ties
# between cards of the same rank, so a sorted hand is always in a predictable order.
const SUITS := ["clubs", "diamonds", "hearts", "spades"]

# Short name shown on the card face and in the game log.
const SPECIAL_NAMES := {
	Special.SKIP: "Skip",
	Special.REVERSE: "Reverse",
	Special.GIVE: "Give",
	Special.FREEZE: "Freeze",
	Special.ANGEL: "Angel",
	Special.VISION: "Vision",
}

const PAIR_TEXTURES := {
	1: "Ace.png",
	2: "two.png",
	3: "three.png",
	4: "Four.png",
	5: "five.png",
	6: "Six.png",
	7: "seven.png",
	8: "eight.png",
	9: "nine.png",
	10: "Ten.png",
}

const SPECIAL_TEXTURES := {
	Special.SKIP: "sloth_card.png",
	Special.REVERSE: "wrath_card.png",
	Special.GIVE: "greed_card.png",
	Special.FREEZE: "gluttony_card.png",
	Special.ANGEL: "pride_card.png",
	Special.VISION: "envy_card.png",
}

# One-line description of each special, used for tooltips / the card info text.
const SPECIAL_HELP := {
	Special.SKIP: "Next player loses their turn",
	Special.REVERSE: "Flip the turn order",
	Special.GIVE: "Give 1 card to any player",
	Special.FREEZE: "A player misses 2 turns",
	Special.ANGEL: "Ask: does a player hold a Joker?",
	Special.VISION: "Peek at a card, then take it or leave it",
}

# Fallback colours used if a special-card illustration is unavailable.
const SPECIAL_COLORS := {
	Special.SKIP: Color(0.85, 0.35, 0.1),
	Special.REVERSE: Color(0.15, 0.45, 0.85),
	Special.GIVE: Color(0.15, 0.6, 0.25),
	Special.FREEZE: Color(0.2, 0.7, 0.9),
	Special.ANGEL: Color(0.75, 0.6, 0.05),
	Special.VISION: Color(0.85, 0.3, 0.55),
}


# ============================================================================
# PROPERTIES
# ============================================================================

# Shared counter that hands out a new unique id to every card ever created.
# `static` means one counter for the whole class, not one per card.
static var _next_id: int = 0

# Unique id for this card. Several cards can look the same (e.g. there are multiple copies of
# each special), so the id gives other code a way to tell individual cards apart.
var id: int
# Which family this card belongs to. Defaults to PAIR; the make_* helpers set it properly.
var kind: Kind = Kind.PAIR
# Only meaningful when kind == PAIR (ignored for specials and Jokers).
var rank: int = 0          # 1 (Ace) .. 10, pair cards only
var suit: String = ""      # pair cards only
# Only meaningful when kind == SPECIAL (ignored for pair cards and Jokers).
var special: Special = Special.SKIP
# PSEUDO:
#   EACH card has:
#       id       (unique)
#       kind     = PAIR
#       rank     = 0        # pair cards only
#       suit     = ""       # pair cards only
#       special  = SKIP     # special cards only

# ============================================================================
# CREATION
# ============================================================================
# Runs automatically on BlandCard.new(): stamps the card with the next free id.
# PSEUDO:
#   WHEN a card is created:
#       next_id = next_id + 1
#       this.id = next_id
func _init() -> void:
	_next_id += 1
	id = _next_id

# Factory helpers. They exist so callers write `BlandCard.make_pair(5, "hearts")`
# instead of creating a blank card and then filling in several fields by hand.
# PSEUDO:
#   FUNCTION make_pair(rank, suit):
#       card = new card
#       card.kind = PAIR, card.rank = rank, card.suit = suit
#       RETURN card
static func make_pair(p_rank: int, p_suit: String) -> BlandCard:
	var c := BlandCard.new()
	c.kind = Kind.PAIR
	c.rank = p_rank
	c.suit = p_suit
	return c

# PSEUDO:
#   FUNCTION make_special(special):
#       card = new card
#       card.kind = SPECIAL, card.special = special
#       RETURN card
static func make_special(p_special: Special) -> BlandCard:
	var c := BlandCard.new()
	c.kind = Kind.SPECIAL
	c.special = p_special
	return c

# PSEUDO:
#   FUNCTION make_joker():
#       card = new card
#       card.kind = JOKER
#       RETURN card
static func make_joker() -> BlandCard:
	var c := BlandCard.new()
	c.kind = Kind.JOKER
	return c

# ============================================================================
# TYPE CHECKS
# ============================================================================

# Quick "what is this card?" checks, so other code reads `if c.is_joker()` instead of
# comparing `kind` to an enum value everywhere.
# PSEUDO:
#   FUNCTION is_pair_card(): RETURN kind == PAIR
#   FUNCTION is_special():   RETURN kind == SPECIAL
#   FUNCTION is_joker():     RETURN kind == JOKER
func is_pair_card() -> bool:
	return kind == Kind.PAIR

func is_special() -> bool:
	return kind == Kind.SPECIAL

func is_joker() -> bool:
	return kind == Kind.JOKER

# ============================================================================
# PAIRING RULE
# ============================================================================

# True if `other` forms a pair with this card: both must be pair cards of the same rank.
# `other != self` stops a card from "matching" itself when scanning a hand.
# Specials and Jokers never match anything.
# PSEUDO:
#   FUNCTION matches(other):
#       IF other is this same card:       RETURN false
#       IF this is not a PAIR card:       RETURN false
#       IF other is not a PAIR card:      RETURN false
#       RETURN (this.rank == other.rank)          # suit does not matter
func matches(other: BlandCard) -> bool:
	return other != self and kind == Kind.PAIR and other.kind == Kind.PAIR and rank == other.rank


# ============================================================================
# DISPLAY HELPERS
# ============================================================================

# Hearts and diamonds are drawn in red, clubs and spades in black (used for pair colouring on the table).
# PSEUDO:
#   FUNCTION is_red():
#       RETURN suit is hearts OR suit is diamonds
func is_red() -> bool:
	return suit == "hearts" or suit == "diamonds"

# "A" for the Ace, otherwise the number ("7"). Used for the small label on the card.
# PSEUDO:
#   FUNCTION rank_name():
#       IF rank == 1: RETURN "A"
#       ELSE:         RETURN rank as text          # "7"
func rank_name() -> String:
	return "A" if rank == 1 else str(rank)

# Plural form for messages, e.g. "Aces" or "7s".
# PSEUDO:
#   FUNCTION rank_plural():
#       IF rank == 1: RETURN "Aces"
#       ELSE:         RETURN rank + "s"            # "7s"
func rank_plural() -> String:
	return "Aces" if rank == 1 else "%ds" % rank

# Full human-readable name for log messages, e.g. "7 of Hearts", "Skip", "Joker".
# PSEUDO:
#   FUNCTION display_name():
#       IF kind == PAIR:
#           name = "Ace" if rank == 1 else rank as text
#           RETURN name + " of " + capitalize(suit)       # "7 of Hearts"
#       IF kind == SPECIAL:
#           RETURN SPECIAL_NAMES[special]                 # "Skip"
#       ELSE:
#           RETURN "Joker"
func display_name() -> String:
	match kind:
		Kind.PAIR:
			return "%s of %s" % [("Ace" if rank == 1 else str(rank)), suit.capitalize()]
		Kind.SPECIAL:
			return SPECIAL_NAMES[special]
		_:
			return "Joker"

# Name of the special effect, or "" if this card isn't a special (the .get default).
# PSEUDO:
#   FUNCTION special_name():
#       RETURN SPECIAL_NAMES[special], or "" if not found
func special_name() -> String:
	return SPECIAL_NAMES.get(special, "")

# ============================================================================
# TEXTURE FILE
# ============================================================================

## File name inside the card art folders. Pair faces use the custom rank images;
## specials and Jokers use their themed illustrations.
func texture_file() -> String:
	match kind:
		Kind.PAIR:
			if PAIR_TEXTURES.has(rank):
				return str(PAIR_TEXTURES[rank])
			var r := "A" if rank == 1 else "%02d" % rank
			return "card_%s.png" % r
		Kind.SPECIAL:
			return str(SPECIAL_TEXTURES.get(special, "card_empty.png"))
		_:
			return "joker_card.png"

# ============================================================================
# SORTING
# ============================================================================

## Sort key so the human's hand is grouped: pairs by rank, then specials, then Jokers.
## Hands are sorted by this number. Pairs get rank*10 + suit position (so 3 of clubs = 30,
## 3 of diamonds = 31, ...), which groups equal ranks together and keeps the suit order stable.
## Specials get 1000+ and the Joker 2000, so they always land after every pair card.
# PSEUDO:
#   FUNCTION sort_key():
#       IF kind == PAIR:
#           RETURN rank * 10 + index_of(suit in SUITS)
#       IF kind == SPECIAL:
#           RETURN 1000 + special_enum_number
#       ELSE:
#           RETURN 2000
func sort_key() -> int:
	match kind:
		Kind.PAIR:
			return rank * 10 + SUITS.find(suit)
		Kind.SPECIAL:
			return 1000 + int(special)
		_:
			return 2000
