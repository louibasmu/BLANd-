class_name BlandCard
extends RefCounted
## One card: a pair card (A-10), a special card, or a Joker.

enum Kind { PAIR, SPECIAL, JOKER }
enum Special { SKIP, REVERSE, GIVE, FREEZE, ANGEL, VISION }

const SUITS := ["clubs", "diamonds", "hearts", "spades"]

const SPECIAL_NAMES := {
	Special.SKIP: "Skip",
	Special.REVERSE: "Reverse",
	Special.GIVE: "Give",
	Special.FREEZE: "Freeze",
	Special.ANGEL: "Angel",
	Special.VISION: "Vision",
}

const SPECIAL_HELP := {
	Special.SKIP: "Next player loses their turn",
	Special.REVERSE: "Flip the turn order",
	Special.GIVE: "Give 1 card to any player",
	Special.FREEZE: "A player misses 2 turns",
	Special.ANGEL: "Ask: does a player hold a Joker?",
	Special.VISION: "Peek at a card, then take it or leave it",
}

# Placeholder colours for special cards until Ash's art is in.
const SPECIAL_COLORS := {
	Special.SKIP: Color(0.85, 0.35, 0.1),
	Special.REVERSE: Color(0.15, 0.45, 0.85),
	Special.GIVE: Color(0.15, 0.6, 0.25),
	Special.FREEZE: Color(0.2, 0.7, 0.9),
	Special.ANGEL: Color(0.75, 0.6, 0.05),
	Special.VISION: Color(0.85, 0.3, 0.55),
}

static var _next_id: int = 0

var id: int
var kind: Kind = Kind.PAIR
var rank: int = 0          # 1 (Ace) .. 10, pair cards only
var suit: String = ""      # pair cards only
var special: Special = Special.SKIP


func _init() -> void:
	_next_id += 1
	id = _next_id


static func make_pair(p_rank: int, p_suit: String) -> BlandCard:
	var c := BlandCard.new()
	c.kind = Kind.PAIR
	c.rank = p_rank
	c.suit = p_suit
	return c


static func make_special(p_special: Special) -> BlandCard:
	var c := BlandCard.new()
	c.kind = Kind.SPECIAL
	c.special = p_special
	return c


static func make_joker() -> BlandCard:
	var c := BlandCard.new()
	c.kind = Kind.JOKER
	return c


func is_pair_card() -> bool:
	return kind == Kind.PAIR


func is_special() -> bool:
	return kind == Kind.SPECIAL


func is_joker() -> bool:
	return kind == Kind.JOKER


func matches(other: BlandCard) -> bool:
	return other != self and kind == Kind.PAIR and other.kind == Kind.PAIR and rank == other.rank


func is_red() -> bool:
	return suit == "hearts" or suit == "diamonds"


func rank_name() -> String:
	return "A" if rank == 1 else str(rank)


func rank_plural() -> String:
	return "Aces" if rank == 1 else "%ds" % rank


func display_name() -> String:
	match kind:
		Kind.PAIR:
			return "%s of %s" % [("Ace" if rank == 1 else str(rank)), suit.capitalize()]
		Kind.SPECIAL:
			return SPECIAL_NAMES[special]
		_:
			return "Joker"


func special_name() -> String:
	return SPECIAL_NAMES.get(special, "")


## File name inside res://Sprites/Card Assets/
func texture_file() -> String:
	match kind:
		Kind.PAIR:
			var r := "A" if rank == 1 else "%02d" % rank
			return "card_%s_%s.png" % [suit, r]
		Kind.SPECIAL:
			return "card_empty.png"   # text is drawn on top for now
		_:
			return "card_joker_black.png"


## Sort key so the human's hand is grouped: pairs by rank, then specials, then Jokers.
func sort_key() -> int:
	match kind:
		Kind.PAIR:
			return rank * 10 + SUITS.find(suit)
		Kind.SPECIAL:
			return 1000 + int(special)
		_:
			return 2000
