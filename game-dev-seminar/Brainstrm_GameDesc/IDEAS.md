# BLANd – Ideas & Possible Mechanics (side list)

A parking lot for rules, cards and features the team might add later. Nothing here is in the game yet.
Suggested rarity uses the current rule: 1 copy = Rare, 2 = Uncommon, 3+ = Common.

---

## Proposed by the team

### Lock (special card)
Pick one card in your hand. Nobody else can take it: it can't be drawn, Vision-taken or Given away.
- Using Lock spends your turn (like other specials that don't make a pair).
- **Open questions**
  - How long does it last? The rest of the round, or N turns?
  - Can you lock a Joker? (That guarantees the penalty, so it's probably never chosen. Could be a "bluff lock".)
  - Should locked cards be visible to everyone (a lock icon on the slot)? Visible seems fairer and lets people play around it.
  - Can a player go "out" if their only remaining card is locked? It might need a rule that locked cards count as unplayable.
- Suggested rarity: Uncommon (2).

### Wild (special card)
Use it as the missing match for one of your pair cards, and score that pair. **Catch:** whoever holds a real matching card also gets a point for that rank.
- **Open questions**
  - Does the other player discard their matching card too, or keep it?
    - If they discard it, the rank is finished: 4 cards gone, 2 points split.
    - If they keep it, they still need a match.
  - If two other players hold that rank, who gets the point? Both? The next in turn order?
  - Can Wild pair a Joker? Suggested: no.
  - Does using Wild count as "made a pair" so you go again?
- Suggested rarity: Rare (1).

### Truth (special card, from the 10/5 notes)
Tells you how many cards of a chosen rank are still out there.
- Only makes sense with the "more copies per rank" variant below (6 of each rank, so pairs aren't guaranteed).
- The Card Tracker already shows this for the standard 4-copy deck.

### Start with all your specials
Specials (not Jokers) are handed out at the start of the round instead of being shuffled into the deck.

### More copies per rank (e.g. 6 instead of 4)
Not every card is guaranteed a match. This pairs well with Truth.

### Start-of-round reveal (memory)
Briefly show what pair cards each player holds, without revealing the Joker. Options discussed:
1. Show ranks only, not positions (recommended: no Joker leak).
2. Show positions, with specials and the Joker as "?" (more memory value, but it narrows where the Joker is).
3. Reveal two random pair cards per player.

Do it *after* hands are locked so positions matter. Bots would need memory to benefit.

---

## Recommended new special cards

| Card | What it does | Why it fits BLANd | Suggested rarity |
|---|---|---|---|
| **Scramble** | Shuffle one opponent's hand. | Hand order is locked and new cards go last, so players can track positions. Scramble is the counter to tracking. | Common (3) |
| **Shield** | Keep it in hand. It automatically blocks the next special played on you, then is discarded. | Gives a defence against Freeze, Give, Vision and Angel. It also makes holding cards a decision. | Uncommon (2) |
| **Mirror** | Like Shield, but bounces the special back onto whoever played it. | A stronger, rarer version of Shield, with big swing moments. | Rare (1) |
| **Thaw** | Remove all Freeze turns from yourself or any player. | A counter for Freeze. Freeze is strong now that specials end your turn. | Uncommon (2) |
| **Double Draw** | Your next draw takes 2 cards from the same player. Pairs from either card let you go again. | Speeds up rounds and is risky near the Joker. | Uncommon (2) |
| **Swap** | Trade one card of your choice for a random card from another player. | A way to dump the Joker without Give, but you take a blind card back. | Rare (1) |
| **Spotlight** | One player's hand is face-up to everyone until their next turn. | A strong memory and Joker-hunting tool that works well with locked hand order. | Rare (1) |
| **Census** | Learn how many specials (not which ones) each player holds. | Cheap information. It helps decide who is safe to draw from. | Common (3) |
| **Joker Hunt** | Name a player and a position. If it's the Joker, it moves to the back of their hand and they're Frozen 1 turn. | A skill-based use of position memory. | Rare (1) |

Balance notes:
- Because a special that doesn't make a pair now ends your turn, **reactive cards** (Shield, Mirror) are attractive: they're played on someone else's turn and don't cost you one.
- **Counter cards** (Scramble vs. tracking, Thaw vs. Freeze) keep any one strategy from dominating.
- Use `tools/simulate.gd` to check turns per round and how many players get stuck with a Joker after each change.

---

## Bots (questions for later)
- Memory: remember Angel results, Vision peeks and where cards went, since hand order is locked.
- Difficulty levels = how much the bot remembers and how often it uses that memory well.
- A smarter "Basic+" bot: hold Give until it holds a Joker, use Vision on players it knows got the Joker, avoid drawing from a player Angel confirmed has a Joker.

## User-friendliness ideas
- A short animation of the card sliding from one hand to another.
- Sound cues: your turn, a pair made, the Joker taken from you.
- Hover over a player to highlight which of their cards are known to you (memory aid).
- A first-game tutorial overlay that walks through one turn.
- Save the menu settings between sessions (rounds, bot style and speed, special counts).
- Real art for special cards and seat avatars (Ash).
