# Kuverse NFT Marketplace

A decentralized NFT marketplace enabling seamless creation, trading, and management of digital assets. Built with security and user experience in mind.

## Project Structure

```
├── kuverse-foundry/     # Smart contract implementation
│   ├── src/            # Solidity source files
│   ├── test/           # Contract test files
│   └── script/         # Deployment scripts
│
└── kuverse-ui/         # Frontend React application
    ├── src/            # React source code
    └── public/         # Static assets
```

## Features

- **NFT Minting & Trading**
  - Create and mint new NFTs with metadata
  - List NFTs for sale with custom pricing
  - Make and accept offers on NFTs
  - Support for ETH and ERC20 payments

- **Multi-Currency Support**
  - Native ETH transactions
  - ERC20 token support
  - Creator royalties

- **Security & Best Practices**
  - Comprehensive test coverage
  - Gas optimized contracts
  - Access control and pausability
  - Reentrancy protection

- **Modern UI/UX**
  - React-based frontend
  - Web3 wallet integration
  - Responsive design
  - Real-time updates

## Smart Contracts

The smart contract implementation includes:

- `KuverseNFT.sol`: ERC721 implementation with metadata and royalty support
- `KuverseMarketplace.sol`: NFT marketplace with listing and offer functionality

## Getting Started

### Prerequisites
- Node.js 14+
- Foundry for smart contract development
- MetaMask or another Web3 wallet

### Installation

1. Clone the repository:
```bash
git clone https://github.com/ABDIKADR/kuverse-nft-marketplace.git
cd kuverse-nft-marketplace
```

2. Install dependencies:
```bash
# Install Foundry dependencies
cd kuverse-foundry
forge install

# Install UI dependencies
cd ../kuverse-ui
npm install
```

3. Start the development server:
```bash
npm start
```

## Testing

```bash
# Run smart contract tests
cd kuverse-foundry
forge test

# Run UI tests
cd kuverse-ui
npm test
```

## License

MIT

## Author

ABDIKADR (https://github.com/ABDIKADR)
