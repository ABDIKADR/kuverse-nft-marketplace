// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {KuverseNFT} from "../src/KuverseNFT.sol";
import {KuverseMarketplace} from "../src/KuverseMarketplace.sol";

/**
 * @title DeployKuverse
 * @dev Script to deploy Kuverse contracts with default parameters
 */
contract DeployKuverse is Script {
    // Default values for NFT collection
    string public constant DEFAULT_NFT_NAME = "Kuverse NFT Collection";
    string public constant DEFAULT_NFT_SYMBOL = "KNFT";
    uint256 public constant DEFAULT_MAX_SUPPLY = 10000;
    uint256 public constant DEFAULT_ROYALTY_BASIS_POINTS = 250; // 2.5%
    string public constant DEFAULT_BASE_URI = "https://api.kuverse.app/nft/";

    // Default values for marketplace
    uint256 public constant DEFAULT_MARKETPLACE_FEE = 250; // 2.5%

    function run() public {
        vm.startBroadcast();

        // Deploy NFT collection
        KuverseNFT nft = new KuverseNFT(
            DEFAULT_NFT_NAME, DEFAULT_NFT_SYMBOL, DEFAULT_MAX_SUPPLY, DEFAULT_ROYALTY_BASIS_POINTS, DEFAULT_BASE_URI
        );

        // Deploy marketplace
        KuverseMarketplace marketplace = new KuverseMarketplace(DEFAULT_MARKETPLACE_FEE);

        // Mint a sample NFT
        nft.mint(
            msg.sender,
            "Sample NFT",
            "This is a sample NFT for demonstration",
            "https://ipfs.io/ipfs/QmaKSmVLDBMXXmgxRc9YDVJYfGiDGxnTrUPPcVrg8hKpgz"
        );

        vm.stopBroadcast();

        console.log("Kuverse NFT deployed at:", address(nft));
        console.log("Kuverse Marketplace deployed at:", address(marketplace));
    }
}

/**
 * @title DeployKuverseWithCustomParams
 * @dev Script to deploy Kuverse contracts with custom parameters
 */
contract DeployKuverseWithCustomParams is Script {
    /**
     * @dev Deploy Kuverse contracts with custom parameters
     * @param nftName Name of the NFT collection
     * @param nftSymbol Symbol for the NFT collection
     * @param maxSupply Maximum supply of NFTs
     * @param royaltyBasisPoints Royalty percentage in basis points (e.g., 250 = 2.5%)
     * @param baseURI Base URI for token metadata
     * @param marketplaceFee Marketplace fee percentage in basis points (e.g., 250 = 2.5%)
     */
    function run(
        string memory nftName,
        string memory nftSymbol,
        uint256 maxSupply,
        uint256 royaltyBasisPoints,
        string memory baseURI,
        uint256 marketplaceFee
    ) public {
        vm.startBroadcast();

        // Deploy NFT collection
        KuverseNFT nft = new KuverseNFT(nftName, nftSymbol, maxSupply, royaltyBasisPoints, baseURI);

        // Deploy marketplace
        KuverseMarketplace marketplace = new KuverseMarketplace(marketplaceFee);

        vm.stopBroadcast();

        console.log("Kuverse NFT deployed at:", address(nft));
        console.log("Kuverse Marketplace deployed at:", address(marketplace));
    }
}
