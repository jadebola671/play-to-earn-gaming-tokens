# Play-to-Earn Gaming Tokens

A comprehensive smart contract system for play-to-earn gaming built on the Stacks blockchain using Clarity. This project implements a dual-token architecture with achievement-based rewards and a native gaming token.

## 🎮 Overview

This project provides the foundational smart contracts for a play-to-earn gaming ecosystem, featuring:

- **Achievement System**: Track and reward player accomplishments across games
- **Gaming Token Economy**: Native fungible tokens for in-game transactions
- **Reward Distribution**: Automated reward distribution based on achievement completion
- **Player Progression**: Comprehensive player progress tracking and analytics

## 🏗️ Architecture

### Core Smart Contracts

#### 1. Achievement Rewards Contract (`achievement-rewards.clar`)
- **Purpose**: Manages game achievements, player progress tracking, and reward distribution
- **Key Features**:
  - Achievement definition and management
  - Player progress tracking
  - Reward calculation and distribution
  - Admin controls for achievement configuration
  - Anti-fraud measures and validation

#### 2. Game Token Contract (`game-token.clar`)
- **Purpose**: Implements a SIP-010 compliant fungible token for the gaming ecosystem
- **Key Features**:
  - Standard token transfer and allowance functionality
  - Minting and burning capabilities
  - Admin controls for token supply management
  - Event emission for transaction tracking
  - Safe arithmetic operations

## 💰 Tokenomics

### Game Token (GTK)
- **Symbol**: GTK
- **Decimals**: 6
- **Initial Supply**: 1,000,000,000 GTK (1 billion tokens)
- **Use Cases**:
  - In-game purchases and transactions
  - Staking for premium features
  - Trading and marketplace activities
  - Achievement reward payouts

### Achievement Rewards
- **Reward Types**: GTK tokens, NFT achievements, experience points
- **Distribution**: Automated upon achievement completion verification
- **Categories**: Combat, exploration, crafting, social, special events
- **Scalability**: Support for unlimited achievement types and reward structures

## 📁 Project Structure

```
play-to-earn-gaming-tokens/
├── contracts/
│   ├── achievement-rewards.clar    # Achievement management and rewards
│   └── game-token.clar            # SIP-010 fungible token implementation
├── tests/
│   ├── achievement-rewards_test.ts # Achievement contract tests
│   └── game-token_test.ts         # Token contract tests
├── settings/
│   ├── Devnet.toml               # Development network configuration
│   ├── Testnet.toml              # Testnet configuration
│   └── Mainnet.toml              # Mainnet configuration
├── Clarinet.toml                 # Project configuration
├── package.json                  # Node.js dependencies
├── tsconfig.json                 # TypeScript configuration
└── vitest.config.js             # Test configuration
```

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) - Smart contract development toolkit
- [Node.js](https://nodejs.org/) (v16 or higher)
- [Git](https://git-scm.com/)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/jadebola671/play-to-earn-gaming-tokens.git
   cd play-to-earn-gaming-tokens
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Check contract syntax:
   ```bash
   clarinet check
   ```

4. Run tests:
   ```bash
   clarinet test
   ```

## 🧪 Development

### Contract Development
- Contracts are located in the `contracts/` directory
- Use `clarinet check` to validate syntax
- Use `clarinet test` to run the test suite
- Use `clarinet console` for interactive development

### Testing
- Tests are written in TypeScript using Vitest
- Integration tests verify contract interactions
- Unit tests cover individual function behavior
- Run tests with `npm test` or `clarinet test`

## 🔒 Security Features

### Access Control
- Admin-only functions for critical operations
- Multi-signature support for high-value transactions
- Time-locked administrative actions
- Role-based permission system

### Validation
- Input sanitization and validation
- Overflow/underflow protection
- Reentrancy guards
- Rate limiting for sensitive operations

### Auditing
- Comprehensive event logging
- Transaction history tracking
- Achievement verification trails
- Supply change monitoring

## 🌐 Deployment

### Development (Devnet)
```bash
clarinet deployments apply --devnet
```

### Testnet
```bash
clarinet deployments apply --testnet
```

### Mainnet
```bash
clarinet deployments apply --mainnet
```

## 📊 Usage Examples

### Creating an Achievement
```javascript
// Admin creates a new achievement
(contract-call? .achievement-rewards add-achievement 
  "first-kill" 
  "Defeat your first enemy" 
  u1000000)  // 1 GTK reward
```

### Completing an Achievement
```javascript
// Player completes an achievement
(contract-call? .achievement-rewards complete-achievement 
  "first-kill" 
  'SP1PLAYER123...)
```

### Token Transfer
```javascript
// Transfer GTK tokens
(contract-call? .game-token transfer 
  u1000000      // 1 GTK
  tx-sender 
  'SP1RECIPIENT123... 
  (some "Payment for items"))
```

## 🤝 Contributing

We welcome contributions to improve the gaming ecosystem! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Clarity best practices
- Maintain comprehensive test coverage
- Document all public functions
- Use descriptive variable names
- Implement proper error handling

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet/)
- [SIP-010 Fungible Token Standard](https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md)

## 🆘 Support

For support and questions:
- Create an [Issue](https://github.com/jadebola671/play-to-earn-gaming-tokens/issues)
- Join our [Discord](https://discord.gg/gaming-tokens)
- Follow us on [Twitter](https://twitter.com/gaming_tokens)

---

**Built with ❤️ for the Stacks gaming ecosystem**
