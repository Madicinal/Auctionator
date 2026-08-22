All credits to this original fork: https://github.com/Sleepywalker69/Auctionator-CoA-Ascension
My changes are notated toward the very bottom, all made with GPT. I'm not a programmer and it's possible that it may have bugs. Works fine so far for me.

# Installation
This fork is intended to replace Ascension's bundled Auctionator, not install alongside it.

In the Ascension Launcher, under the Addons section disable and remove the original Auctionator addon.
Open your WoW Interface\AddOns folder and make sure the launcher's original Auctionator folder is no longer present. If it is, remove it.
Download this repository and extract it.
Copy the three folders beginning with **CoAuctionator** into your Interface\AddOns folder.
Launch the game and make sure the three CoAuctionator addons are enabled at the character-select AddOns screen.

If the Ascension Launcher restores its own Auctionator folder, make sure Auctionator is still disabled in the launcher. The three CoAuctionator folders are the only ones from this fork that you need.


# CoAuctionator (3.3.5 fork) from SleepyWalker69 — Scanning & Selling Overhaul
Based on **Auctionator** by Zirco (and the Borjamacare v3.2.6 WoD branch). Scanning reliability patterns modeled on **TradeSkillMaster v2** by Sapu94 et al. Fork maintained for WotLK 3.3.5 private servers.

## Commands

| Command | Effect |
|---|---|
| `/atr fsc N` | Full-scan analysis chunk size (rows per frame, default 50) |
| `/atr uidebug` | Print button geometry/state for skin-conflict diagnosis |
| `/atr clear fullscandb` | Wipe the scan price database |
| `/atr clear posthistory` | Wipe your posting history |
| `/atr mem` | Addon memory usage |

## Madicinal fork additions

**Changes below are additions made after the Sleepywalker69 CoA fork base:**

- **Independent `CoAuctionator` package identity** — the core addon and both companion data addons use the `CoAuctionator*` naming scheme so the Ascension launcher can manage its own `Auctionator` package without overwriting this fork.
- **Individual Buy Multiple picker** — adds a separate **Buy Multiple** button for grouped auction results. It expands the selected group into individual live AH rows so the user can choose exactly which auction to purchase, while all protected purchasing, exact item/link/rarity validation, acknowledgement, stale-row handling, retries, and scan updates remain in the upstream CoA buy engine.
- **Blizzard-style dialog behavior** — the Buy Multiple picker closes with Escape and automatically closes/clears its active buy state when the Auction House closes.
- **Classic Auctionator UI shell** — restores the preserved pre-fork Auctionator frame artwork and legacy search-row geometry over the newer CoA functionality, including the original compact `+` Advanced Search button, while retaining CoA-only controls such as Exact Match, Chain Buy, and the newer scanning/inventory systems.

Legacy pre-migration code is preserved in the `legacy-ascension-multidirect` branch.


<img width="2328" height="728" alt="image" src="https://github.com/user-attachments/assets/71d92c3c-defe-4695-8c02-f2c5c9d5c09c" />
<img width="1578" height="732" alt="image" src="https://github.com/user-attachments/assets/ddd49e65-4100-4961-8cd7-54750fb276e7" />
<img width="1306" height="723" alt="image" src="https://github.com/user-attachments/assets/7fe70446-e4cd-4a88-a89c-f58d0e234894" />



