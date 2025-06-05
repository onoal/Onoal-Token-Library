# 🪙 Onoal Token Library (OTL)

**OTL** is the official Move package for tokenizing digital utilities on the Sui blockchain, developed by [Onoal](https://onoal.com).  
It enables seamless creation, management, and integration of assets like **tickets**, **utility tokens**, **festival credits**, **loyalty rewards**, and more — with built-in support for the [Sui Kiosk Framework](https://docs.sui.io/build/programming/kiosk).

---

## ✨ Features

- 🧱 Modular Move modules for:
  - Utility tokens
  - Event tickets (time-bound, transferable, or single-use)
  - Loyalty and point-based systems
- 🧩 Fully compatible with the Sui Kiosk Framework
- 🔐 Supports permissioned minting and transfer logic
- 📦 Structured metadata for each token/NFT standard
- ⚡️ Ready to integrate in dApps, marketplaces, and wallets

---

## 📦 Package Structure

/sources
├── token.move # Generic utility token module
├── ticket.move # Ticket-type asset module
├── metadata.move # Common metadata structure
├── kiosk_integration.move # Kiosk capabilities
└── utils.move # Internal helpers and constants

/tests
├── token.test.ts
└── ticket.test.ts

/Move.toml

yaml
Copy
Edit

---

## 🛠️ Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/onoal/onoal-token-library.git
cd onoal-token-library
2. Build the Package
bash
Copy
Edit
sui move build
3. Run Tests
bash
Copy
Edit
sui move test
🧪 Example Use Case: Create a Festival Token
move
Copy
Edit
use 0x1::sui::SUI;
use 0xOTL::token;

public entry fun mint_festival_token(admin: &signer, recipient: address) {
    token::mint(
        admin,
        recipient,
        "ONOALFEST 2025",
        "OFEST",
        1000,
        {
            description: "Festival tokens usable at all Onoal events in 2025.",
            image_url: "https://ipfs.io/ipfs/...",
            category: "festival"
        }
    );
}
🧰 Integrations
✅ Kiosk-based marketplaces

✅ Wallet-based mint & transfer flows

✅ Claim verification for identity-bound tokens (coming soon)

✅ Token-gated access flows for events or loyalty rewards

🧩 Built For:
Use Case	Description
🎟️ Tickets	Event entry tokens, QR-compatible
🪙 Tokens	Fungible tokens with custom logic
💎 Loyalty	Reward and reputation NFTs
🔒 Identity	Identity-linked assets (ZK integrations soon)

🧠 About Onoal
Onoal is building the most user-friendly Web3 infrastructure for payments, tokens, and identity — powering real-world use cases in events, commerce, and loyalty.
Visit us at onoal.com or follow @thiemmss for updates.

📜 License
MIT © 2025 Onoal Labs