# BLANd – Base Game (from the 10/5 meeting)

A playable first version of BLANd: you vs. 3 bots, 3–7 rounds, 6 special cards plus Jokers.
Open the project in Godot 4.7 and press Play. The main scene is now `BaseGame/main_menu.tscn`
(it used to be `Sprites/main.tscn`; change it under Project Settings → Application → Run if needed).

## Files

| File | What it does |
|---|---|
| `game_settings.gd` | **All the tunable numbers**: Joker penalty, special-card counts, Joker schedule, freeze length, specials per turn, rules text. Start here to change the rules. |
| `bland_card.gd` | One card: pair (A–10), special, or Joker. Special-card names and placeholder colours. |
| `bland_player.gd` | A seat: hand, score, pairs this round, frozen turns. |
| `bland_game.gd` | The rules engine. No UI code, so it can run headless. |
| `bot_brain.gd` | Bot decisions. Two styles: **Random** and **Basic strategy**. |
| `main_menu.gd/.tscn` | Start menu: number of rounds, bot style, how-to-play. |
| `game_table.gd/.tscn` | The table UI (built in code), log, prompts, popups, pause menu. |
| `turn_compass.gd` | The turn-direction diagram next to the log. |
| `tools/simulate.gd` | Plays thousands of bot-only games for balancing. |
| `IDEAS.md` | Side list of possible future cards and mechanics. |

## Rules as implemented

- 4 players always (you + 3 bots). Nobody is knocked out between rounds.
- Deck = 40 pair cards (A–10 × 4 suits) + 12 specials + that round's Jokers. Everything is dealt.
- Starting pairs are discarded and scored right away. Each pair is worth 1 point.
- On your turn you either **draw** a face-down card from **any other player who still has cards** (click "Draw from <player>", then the card), or **play a special** from your hand.
  - **Make a pair → go again.**
  - **Draw a special** → you may play it right away, or keep it (keeping it ends your turn).
  - **Play a special and don't make a pair → turn over.** (Only Vision can make a pair: take the peeked card and it matches.)
  - **Exception: Skip and Reverse.** After playing one you still take a card, but you can't play another special before drawing. That draw follows the normal rules (pair = go again, special = may play it).
  - Draw anything else → turn over.
- Specials (default counts): Skip ×3, Reverse ×3, Give ×2, Freeze ×2 (target misses 2 turns), Angel ×1 (yes/no Joker check), Vision ×1 (peek at a card position, then take it or leave it).
- **Special Cards Setup** (main menu) sets how many of each special go in the deck (0–6). Jokers aren't affected.
- **Rarity** follows the count: 1 = Rare (purple border), 2 = Uncommon (green), 3+ = Common (light blue). It's shown on the card border, the tooltip and the "You drew…" popup.
- Opponents' cards show position numbers (1, 2, 3…) so Vision can name a card.
- A player who empties their hand is **out for the round and safe from the Joker**. They can't be given cards, targeted, or drawn from, and they don't rejoin until the next round. If a Give empties your hand, your turn ends with no draw.
- Once **you** are out of cards, the rest of the round fast-forwards (`FAST_FORWARD_DELAY`).
- The round ends when every pair card has been matched. Each Joker still in a hand costs **4 points**.
- Jokers per round follow the chart in `likelihood_for_card_nums.xlsx` (e.g. 5 rounds = 1, 1, 2, 2, 3).

## Choices made where the notes were open (easy to change)

- **Deck size:** the notes say "53 + jokers", but 40 + 3+3+2+2+1+1 = **52 + jokers**. The code builds 52 + jokers. If a 13th special card was meant, add it to `SPECIAL_COUNTS`.
- **Freeze "two rounds"** is taken to mean the next 2 *turns*.
- Bots also pick any player to draw from (randomly; Basic bots use what they saw with Vision).
- Specials you draw go into your hand and can be played on a later turn.
- **Hand order:** hands are dealt in random order (never sorted). Before each round there's an *Arrange* step: drag cards, or click a card and then click where it should go, or press Shuffle. Press "Lock hand & start round" and the order is locked for the rest of the round. Bots keep their dealt order.
- Any card taken or received (draw, Vision, Give) goes to the **last position** of the hand. When a pair is discarded, the other cards close the gap but keep their order.
- Vision: taking the card counts as your action. Leaving it ends your turn (no pair made). A special taken with Vision can't be played straight away.
- Give can hand away any card, Jokers included.

## Following along

- Bot speed is chosen on the menu: Slow / Normal / Fast (`BOT_SPEEDS`). Before a bot draws, the card it's taking is highlighted for a moment.
- When a bot's move affects you (takes your card, gives you a card, freezes or skips you, uses Angel or Vision on you, reverses play), an alert pops up in the middle of the screen. Alerts come from the `affected` signal in `bland_game.gd`.
- **Turn direction:** a compass next to the log shows the four seats laid out like the table, with arrows pointing the way play is moving (it pulses when someone plays Reverse). Gold = playing now, orange ring = next. Each box also shows a PLAYING / NEXT tag, and the top bar says "Next up: …" (taking a pending Skip into account).
- Each player's box shows the pairs they've made this round ("Pairs made: 7 7, A A…"). Each number is coloured like its card: red for hearts/diamonds, black for clubs/spades. Hover a chip to see the exact cards.
- **Card Tracker** (button or the T key): for each rank A–10, shows how many have been paired, how many you hold, and how many are still in opponents' hands. It also shows how many special cards have been played.

## Bots (for the "questions for later")

- **Random:** every choice is a coin flip.
- **Basic:** gives a Joker away when it can, uses Vision/Angel on the player it draws from, freezes the leader, and after a Vision peek it avoids a Joker or grabs a known match.
Smarter or difficulty-scaled bots can go in `bot_brain.gd` without touching the rules or the UI.

## Simulation (for probability / difficulty curve work)

From the `game-dev-seminar` folder:

```
godot --headless -s res://BaseGame/tools/simulate.gd -- --games=500 --rounds=5 --style=basic
```

It prints average turns per round, how many players get stuck with a Joker per round, average final score and wins by seat.

## Art hooks

Card faces come from `res://Sprites/Card Assets/` (`card_<suit>_<A|02..10>.png`, `card_joker_black.png`, `card_back.png`).
For now, special cards use `card_empty.png` with a coloured label. Swap in real art by changing `BlandCard.texture_file()`.
