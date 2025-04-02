// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {KuverseNFT} from "../src/KuverseNFT.sol";

contract KuverseNFTTest is Test {
    KuverseNFT private nft;
    address private deployer;
    address private user1;
    address private user2;

    // Test parameters
    string constant NFT_NAME = "Kuverse NFT Collection";
    string constant NFT_SYMBOL = "KNFT";
    uint256 constant MAX_SUPPLY = 100;
    uint256 constant ROYALTY_BASIS_POINTS = 250; // 2.5%
    string constant BASE_URI = "https://api.kuverse.app/nft/";

    event NFTMinted(address indexed to, uint256 indexed tokenId, string name, string description, string imageURI);

    function setUp() public {
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(deployer);
        nft = new KuverseNFT(NFT_NAME, NFT_SYMBOL, MAX_SUPPLY, ROYALTY_BASIS_POINTS, BASE_URI);
        vm.stopPrank();
    }

    function test_NFTInitialization() public view {
        assertEq(nft.name(), NFT_NAME);
        assertEq(nft.symbol(), NFT_SYMBOL);
        assertEq(nft.maxSupply(), MAX_SUPPLY);
        assertEq(nft.royaltyBasisPoints(), ROYALTY_BASIS_POINTS);
    }

    function test_MintNFT() public {
        string memory name = "Test NFT";
        string memory description = "Test Description";
        string memory imageURI = "https://example.com/image.jpg";

        vm.startPrank(deployer);

        vm.expectEmit(true, true, false, true);
        emit NFTMinted(user1, 0, name, description, imageURI);

        uint256 tokenId = nft.mint(user1, name, description, imageURI);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), user1);

        // Check metadata
        KuverseNFT.NFTMetadata memory metadata = nft.getMetadata(tokenId);
        assertEq(metadata.name, name);
        assertEq(metadata.description, description);
        assertEq(metadata.imageURI, imageURI);

        vm.stopPrank();
    }

    function test_MintOwnNFT() public {
        string memory name = "Self-Minted NFT";
        string memory description = "Test Description";
        string memory imageURI = "https://example.com/image.jpg";

        vm.startPrank(user1);

        vm.expectEmit(true, true, false, true);
        emit NFTMinted(user1, 0, name, description, imageURI);

        uint256 tokenId = nft.mintOwn(name, description, imageURI);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), user1);

        vm.stopPrank();
    }

    function test_RevertWhenMaxSupplyReached() public {
        vm.startPrank(deployer);

        // Mint MAX_SUPPLY NFTs
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            nft.mint(user1, "NFT", "Description", "image.jpg");
        }

        // Trying to mint one more should revert
        vm.expectRevert("Max supply reached");
        nft.mint(user1, "One Too Many", "Description", "image.jpg");

        vm.stopPrank();
    }

    function test_RoyaltyInfo() public {
        vm.startPrank(deployer);
        uint256 tokenId = nft.mint(user1, "NFT", "Description", "image.jpg");
        vm.stopPrank();

        uint256 salePrice = 1 ether;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, deployer);
        assertEq(royaltyAmount, (salePrice * ROYALTY_BASIS_POINTS) / 10000);
    }

    function test_UpdateRoyaltyBasisPoints() public {
        uint256 newRoyaltyBasisPoints = 500; // 5%

        vm.startPrank(deployer);
        nft.setRoyaltyBasisPoints(newRoyaltyBasisPoints);
        vm.stopPrank();

        assertEq(nft.royaltyBasisPoints(), newRoyaltyBasisPoints);
    }

    function test_RevertOnInvalidRoyalty() public {
        vm.startPrank(deployer);

        vm.expectRevert("Royalty too high");
        nft.setRoyaltyBasisPoints(1001); // > 10%

        vm.stopPrank();
    }

    function test_UpdateBaseURI() public {
        string memory newBaseURI = "https://new-api.kuverse.app/nft/";

        vm.startPrank(deployer);
        nft.setBaseURI(newBaseURI);
        vm.stopPrank();

        // Mint a token to check if base URI is updated
        vm.startPrank(deployer);
        uint256 tokenId = nft.mint(user1, "NFT", "Description", "image.jpg");
        vm.stopPrank();

        string memory tokenURI = nft.tokenURI(tokenId);
        assertTrue(bytes(tokenURI).length > 0);
    }

    function test_OnlyOwnerCanUpdateRoyalty() public {
        vm.startPrank(user1);

        vm.expectRevert();
        nft.setRoyaltyBasisPoints(500);

        vm.stopPrank();
    }

    function test_OnlyOwnerCanUpdateBaseURI() public {
        vm.startPrank(user1);

        vm.expectRevert();
        nft.setBaseURI("https://new-api.kuverse.app/nft/");

        vm.stopPrank();
    }

    function test_TransferNFT() public {
        vm.startPrank(deployer);
        uint256 tokenId = nft.mint(user1, "NFT", "Description", "image.jpg");
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), user1);

        vm.startPrank(user1);
        nft.transferFrom(user1, user2, tokenId);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), user2);
    }
}
