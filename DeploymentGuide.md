# Kuverse Smart Contract Deployment Guide

This guide will walk you through the process of deploying the Kuverse NFT and Marketplace contracts to a test network (Sepolia) using Foundry.

## Prerequisites

1. [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
2. An Ethereum wallet with private key
3. Some Sepolia ETH for gas fees (can be obtained from a [faucet](https://sepoliafaucet.com/))
4. API key from an Ethereum node provider like [Infura](https://infura.io/) or [Alchemy](https://www.alchemy.com/)

## Step 1: Set Up Environment Variables

Create a `.env` file in the root of your project with the following variables:

```
PRIVATE_KEY=your_private_key_here
INFURA_API_KEY=your_infura_api_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

Then, load the environment variables:

```bash
source .env
```

## Step 2: Compile the Contracts

Compile the smart contracts to ensure there are no errors:

```bash
forge build
```

## Step 3: Run Tests

Before deploying, run the tests to ensure everything works as expected:

```bash
forge test
```

## Step 4: Deploy to Sepolia Testnet

Using the provided deployment script, deploy the contracts to Sepolia:

```bash
forge script script/DeployKuverse.s.sol:DeployKuverse --rpc-url https://sepolia.infura.io/v3/$INFURA_API_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

You can also use the custom parameter deployment script:

```bash
forge script script/DeployKuverse.s.sol:DeployKuverseWithCustomParams --rpc-url https://sepolia.infura.io/v3/$INFURA_API_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv --sig "run(string,string,uint256,uint256,string,uint256)" "Custom Kuverse NFT" "CKNFT" 5000 300 "https://custom-api.kuverse.app/nft/" 300
```

## Step 5: Verify the Deployment

After deployment, note the contract addresses from the terminal output. You can verify these addresses on [Sepolia Etherscan](https://sepolia.etherscan.io/).

## Step 6: Interact with the Deployed Contracts

You can interact with the deployed contracts using Foundry's `cast` command:

### Mint a new NFT

```bash
cast send --private-key $PRIVATE_KEY --rpc-url https://sepolia.infura.io/v3/$INFURA_API_KEY $NFT_CONTRACT_ADDRESS "mintOwn(string,string,string)" "My NFT" "An amazing NFT" "https://ipfs.io/ipfs/QmaKSmVLDBMXXmgxRc9YDVJYfGiDGxnTrUPPcVrg8hKpgz"
```

### List an NFT for Sale

First, approve the marketplace to transfer your NFT:

```bash
cast send --private-key $PRIVATE_KEY --rpc-url https://sepolia.infura.io/v3/$INFURA_API_KEY $NFT_CONTRACT_ADDRESS "setApprovalForAll(address,bool)" $MARKETPLACE_CONTRACT_ADDRESS true
```

Then, create a listing:

```bash
cast send --private-key $PRIVATE_KEY --rpc-url https://sepolia.infura.io/v3/$INFURA_API_KEY $MARKETPLACE_CONTRACT_ADDRESS "createListing(address,uint256,uint256,address)" $NFT_CONTRACT_ADDRESS 0 1000000000000000000 0x0000000000000000000000000000000000000000
```

### Buy an NFT

```bash
cast send --private-key $PRIVATE_KEY --rpc-url https://sepolia.infura.io/v3/$INFURA_API_KEY $MARKETPLACE_CONTRACT_ADDRESS "buyNFT(uint256)" 0 --value 1000000000000000000
```

## Gas Optimization Recommendations

To optimize gas usage and reduce costs:

1. Batch mint NFTs when possible
2. Use EIP-2981 for royalty information instead of custom implementations
3. Consider implementing lazy minting for large collections
4. Use efficient data structures and avoid redundant storage
5. Optimize metadata storage by using IPFS or Arweave

## Security Considerations

1. Always audit contracts before mainnet deployment
2. Implement access control correctly
3. Test all functions thoroughly
4. Consider using a multisig wallet for contract ownership
5. Monitor contracts after deployment for any suspicious activity

Remember to replace the placeholder values with your actual contract addresses and API keys when running the commands.

## Troubleshooting

1. **Error: Insufficient funds for gas * price + value**
   - Ensure your wallet has enough ETH for gas fees

2. **Error: Nonce too high**
   - Reset your account's nonce in Metamask or run: `cast nonce --rpc-url https://sepolia.infura.io/v3/$INFURA_API_KEY $YOUR_ADDRESS`

3. **Error during contract verification**
   - Ensure your Etherscan API key is correct
   - Check that compiler versions match 