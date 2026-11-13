# BLANd’s Game Design Document (GDD)

## 1. Game Concept

### &nbsp; 1.1 Working Title
> 1.1.1. Death’s Doorstep

### &nbsp; 1.2. Genre:
> 1.2.1. Turn-Based Strategy Card Game

### &nbsp; 1.3. Platform(s):
> 1.3.1. PC, Mac, & Linux. Godot (cross-platform game engine)

### &nbsp; 1.4. Elevator Pitch:
> 1.4.1. A play on the card shedding game “Old Maid” with the goal of obtaining the most points at the end of N rounds. The player obtains points by creating pairs of cards within their own hand. There is a list of special cards that can give the player an advantage. The game plays with a deck that has 13 special cards, 40 pair cards, and a changing number of joker cards. The entire deck is dealt to each player evenly with one person receiving at least one joker card.

### &nbsp; 1.5. Target Audience:
> 1.5.1. The target audience are players of any age who enjoy the thrill of a group game but don’t have the opportunity to play with others. The target audience is the type of player that enjoys a more casual and arcade-like gaming experience.

## 2. Core Loop
>2.1. The core loop of Death’s Doorstep repeats at the beginning of each round. This is where the entire deck is dealt evenly to all four players. The number of pair cards, special cards, and Jokers is random as the deck is shuffled to be random. The players take turns taking a single card from another player or playing a special card thatallows them to complete an action that will provide an advantage. The player istrying to create as many pairs as possible without having the Joker (Hades) by the end of the round. The player(s) that finish a round with the Joker card will lose the number of potential points/number of players which is 4 points.Each round is themed around the 7 deadly sins. The player may opt to play less rounds, but this means they will bypass other sins. The player can choose the number of rounds and Jokers as represented **in the chart below:**

|Round #|# of Jokers|# of Jokers|# of Jokers|# of Jokers|# of Jokers| 
|-|-|-|-|-|-|
|1|1|1|1|1|1|
|2|1|1|1|1|2|
|3|1|2|2|2|3|
|4|1|2|2|3| |
|5|2|3|3| | |
|6|2|3| | | |
|7|3| | | | |

---
## 3. Game Mechanics
### &nbsp; 3.1. Player Actions:
> 3.1.1. Each player is dealt with an evenly split number of cards at the start of each round. Players can first identify any pair in their hand and set them aside. On their turn, the player can choose to play a special card or take one card from another player. If the chosen card matches one of their own, the player
discards the pair and goes again. The player may continue their turn if they create a pair with the card they took during their turn. taking cards from
other players until they cannot make another pair. If the player plays a special card, then they end their turn once they utilize the special card’s feature.
Once the round finishes for the player, points are counted for each player
depending on the number of pairs they have collected and number of jokers
they end up with.

> 3.1.2. *Win Condition(s)* - The player wins once all their cards have been played, and they do not have the Joker.

> 3.1.3. *Lose Condition(s)* - Each player/bot collects their points throughout the whole game with the number of rounds chosen by the player. The player loses if their points at the end of the game are the least among all 4 players.

### &nbsp; 3.2.Interactions:
> 3.2.1. The player interacts with the game by clicking on the cards. A cue will be displayed when it’s their turn. A chosen pair of cards will appear on display but will be only visible to the player. Special cards will be displayed to everyone when they are played.

### &nbsp; 3.3. Rules:
> 3.3.1. The rules are simple in this game. Player plays against 3 bots. They choose the number of rounds before the game begins. Each player plays on their turn, going clockwise. Once a card has been selected and seen, the action cannot be undone.

### &nbsp; 3.4. Rewards:
> 3.4.1. After each round, points are counted for each player. Players with the greatest number of pairs and least number of jokers get the most points. After all the rounds, points are added for each player, making the final placement. The player with the most points has beaten the Joker/Devil/Hades.

### &nbsp; 3.5. Feedback:
> 3.5.1. The game notifies a successful match by showing the pair on display as matched and cueing the player to go again. Sound effects will be included.
---
## 4. Story & Narrative
### &nbsp; 4.1. Premise:
> 4.1.1. You wake up in a dark room, tied to a chair; strangers sit around a table with you. A masked man enters and explains that you will play this game for a chance to be forgiven for your sins. But there’s a catch: only one person survives; others die. Pay for your greed and sins. This world is outside of the human realm and is associated with whomever is above the gods. The cards are the gods who will be played by the sin. The figure that is organizing the game is the maker of the gods who is unnamed.

### &nbsp; 4.2. Main Characters:
> 4.2.1. The player will play as greed, and the bots are greedy people who are tangentially being held captive.

### &nbsp; 4.3. Conflict/Goal:
> 4.3.1. Fear of death the desire to survive and not be killed is what driving the players to play the game in this world. As a real person, the player is playing to see how long they can survive relying on their luck and intuition. The game deals with chance, luck, and strategy mixed in.

## 5. Level & World Design
### &nbsp; 5.1. Setting/Theme:
> 5.1.1. The table at which you play this high-stakes game for the battle of your life. There is a theme of repentance in order to absolve yourself from your wrongdoings. Imagery from Greek Mythology will also be used to be representative of this theme. For instance, Greek Gods such as Philargyria, who represents greed, will be used either as background imagery or be implemented in the card design. This means that this theme will also coincide with the art direction the game intends to take.

### &nbsp; 5.2. Level Structure:
> 5.2.1. This game will have different game modes that vary in difficulty. The player is essentially battling against the remaining players trying to survive. The odds of surviving are 1/7 but can change each round based on who is dealt the Joker card.

### &nbsp; 5.3. Tutorial/Onboarding:
> 5.3.1. Before each different game mode, there will be a brief and skippable tutorial showing the rules of the particular mode that was chosen.

### &nbsp; 5.4. Progression:
> 5.4.1. Difficulty varies depending on the game mode you are playing in as well as how many powerups/people are you willing to add in a game session. The difficulty doesn’t necessarily change; the different special cards being used may increase the likelihood of winning or losing. There may be an element of time added to increase the pressure on the player.

### &nbsp; 5.5.Exploration/Challenges/Puzzles:
> 5.5.1. The player must analyze which cards have been played and how to react when certain information is revealed on who has which cards.

### &nbsp; 5.6. Visual & Audio Style
> 5.6.1. Scary, more ambient style that uses elements to induce fear and suspense into the player.

### &nbsp; 5.7. Art Style Reference (pixel art, 3D, realistic, low poly, etc.):
> 5.7.1. Fantastical but realistic cards. The fantastical aspect comes with the art on each card as well as effects such as light, smoke, fire, etc. Furthermore, realistic and conventional card size/shapes. In addition, the usage of Greek Gods as images on cards.

### &nbsp; 5.8. Color Palette:
> 5.8.1. To fit the theme of Greek Mythology natural colors associated with worldly surrounding will be used. For example, the blue you associate with lighting striking in the air, dark brown like the color of dirt, etc. However, these colors will be less saturated and match the moody dark atmosphere.

### &nbsp; 5.9. Music/Audio Resources (to complement the theme of your game):
> 5.9.1. Orchestral and dark complemented with medieval tavern style music at less tense parts of the game.

## 6. User Interface (UI/UX)
### &nbsp; 6.1. HUD Elements:
> 6.1.1. HUD includes the number of pairs successfully matched, round(1,2,3...).

### &nbsp; 6.2. Menus:
> 6.2.1. Main menu includes start game, sound on/off option, disclaimer (if you hate the idea of devil/joker, death, we recommend you not to play this game.)

### &nbsp; 6.3. Accessibility Features (if any):
> 6.3.1. None planned for prototype of week 10
---

## 7. Technical Requirements
### &nbsp; 7.1. Engine:
>7.1.1. This game is built on Godot Engine 7

### &nbsp; 7.2. Programming Language(s):
>7.2.1. GDscript

### &nbsp; 7.3. Tools for Assets:
>7.3.1. PC

### &nbsp; 7.4. Deployment Platform:
>7.4.1. PC build, CS480/490 Webpage
---
## 8. Development Plan
|Week|Design/Mechanics|Art|Programming|Music/Sound|
|-|-|-|-|-|
|5|Game Design|{}|{}|{}|
|6|Game Design|{}|UI *(Menu, Settings, Results Screen)* + Game Mechanics|{}|  
|7|{}|Card Design|Game Mechanics|{}| 
|8|{}|Table Interface|Game Mechanics|Interactive Sound|   
|9|{}|Touchups|Testing Game Mechanics|Background Music|   
|10|{}|{}|{}|Touchups|   

*Note: {} indicates blank*
