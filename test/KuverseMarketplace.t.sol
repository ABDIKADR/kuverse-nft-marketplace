// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {KuverseNFT} from "../src/KuverseNFT.sol";
import {KuverseMarketplace} from "../src/KuverseMarketplace.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract KuverseMarketplaceTest is Test {
    KuverseNFT private nft;
    KuverseMarketplace private marketplace;
    ERC20Mock private paymentToken;

    address private deployer;
    address private seller;
    address private buyer;

    // Test parameters
    uint256 constant MARKETPLACE_FEE = 250; // 2.5%
    uint256 constant NFT_PRICE = 1 ether;

    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken
    );
    event ListingSold(uint256 indexed listingId, address indexed buyer, uint256 price);

    function setUp() public {
        deployer = makeAddr("deployer");
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");

        // Give ETH to buyer for purchasing
        vm.deal(buyer, 10 ether);

        vm.startPrank(deployer);

        // Deploy NFT contract
        nft = new KuverseNFT("Kuverse NFT Collection", "KNFT", 100, 250, "https://api.kuverse.app/nft/");

        // Deploy marketplace contract
        marketplace = new KuverseMarketplace(MARKETPLACE_FEE);

        // Deploy mock payment token
        paymentToken = new ERC20Mock("Test Token", "TEST");

        // Add payment token to supported tokens
        marketplace.setPaymentTokenStatus(address(paymentToken), true);

        vm.stopPrank();
    }

    function test_MarketplaceInitialization() public view {
        assertEq(marketplace.marketplaceFee(), MARKETPLACE_FEE);
        assertTrue(marketplace.supportedPaymentTokens(address(0))); // ETH should be supported by default
        assertTrue(marketplace.supportedPaymentTokens(address(paymentToken)));
    }

    function _mintAndApproveNFT() internal returns (uint256 tokenId) {
        vm.startPrank(deployer);
        tokenId = nft.mint(seller, "Test NFT", "Test Description", "https://example.com/image.jpg");
        vm.stopPrank();

        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        vm.stopPrank();
    }

    function test_CreateListing() public {
        uint256 tokenId = _mintAndApproveNFT();

        vm.startPrank(seller);

        vm.expectEmit(true, true, true, true);
        emit ListingCreated(0, seller, address(nft), tokenId, NFT_PRICE, address(0));

        uint256 listingId = marketplace.createListing(address(nft), tokenId, NFT_PRICE, address(0));

        assertEq(listingId, 0);

        // Check listing details
        KuverseMarketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.seller, seller);
        assertEq(listing.nftContract, address(nft));
        assertEq(listing.tokenId, tokenId);
        assertEq(listing.price, NFT_PRICE);
        assertEq(listing.paymentToken, address(0));
        assertTrue(listing.isActive);

        vm.stopPrank();
    }

    function test_BuyNFTWithETH() public {
        uint256 tokenId = _mintAndApproveNFT();

        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(address(nft), tokenId, NFT_PRICE, address(0));
        vm.stopPrank();

        uint256 sellerBalanceBefore = seller.balance;

        vm.startPrank(buyer);

        vm.expectEmit(true, true, false, true);
        emit ListingSold(listingId, buyer, NFT_PRICE);

        marketplace.buyNFT{value: NFT_PRICE}(listingId);

        // Check NFT ownership
        assertEq(nft.ownerOf(tokenId), buyer);

        // Check seller payment
        uint256 fee = (NFT_PRICE * MARKETPLACE_FEE) / 10000;
        uint256 sellerAmount = NFT_PRICE - fee;
        assertEq(seller.balance, sellerBalanceBefore + sellerAmount);

        // Check marketplace fee
        assertEq(address(marketplace).balance, fee);

        // Check listing status
        KuverseMarketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.isActive);

        vm.stopPrank();
    }

    function test_BuyNFTWithERC20() public {
        uint256 tokenId = _mintAndApproveNFT();

        // Mint payment tokens to buyer
        vm.startPrank(deployer);
        paymentToken.mint(buyer, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(address(nft), tokenId, NFT_PRICE, address(paymentToken));
        vm.stopPrank();

        vm.startPrank(buyer);
        paymentToken.approve(address(marketplace), NFT_PRICE);

        marketplace.buyNFT(listingId);

        // Check NFT ownership
        assertEq(nft.ownerOf(tokenId), buyer);

        // Check seller payment
        uint256 fee = (NFT_PRICE * MARKETPLACE_FEE) / 10000;
        uint256 sellerAmount = NFT_PRICE - fee;
        assertEq(paymentToken.balanceOf(seller), sellerAmount);

        // Check marketplace fee
        assertEq(paymentToken.balanceOf(address(marketplace)), fee);

        vm.stopPrank();
    }

    function test_UpdateListing() public {
        uint256 tokenId = _mintAndApproveNFT();

        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(address(nft), tokenId, NFT_PRICE, address(0));

        uint256 newPrice = 2 ether;
        marketplace.updateListing(listingId, newPrice);

        KuverseMarketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.price, newPrice);

        vm.stopPrank();
    }

    function test_CancelListing() public {
        uint256 tokenId = _mintAndApproveNFT();

        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(address(nft), tokenId, NFT_PRICE, address(0));

        marketplace.cancelListing(listingId);

        KuverseMarketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.isActive);

        vm.stopPrank();
    }

    function test_CreateAndAcceptOffer() public {
        uint256 tokenId = _mintAndApproveNFT();

        // Create an offer with ETH
        vm.startPrank(buyer);
        uint256 offerId =
            marketplace.createOffer{value: NFT_PRICE}(address(nft), tokenId, NFT_PRICE, address(0), 1 days);
        vm.stopPrank();

        uint256 sellerBalanceBefore = seller.balance;

        // Accept the offer
        vm.startPrank(seller);
        marketplace.acceptOffer(offerId);
        vm.stopPrank();

        // Check NFT ownership
        assertEq(nft.ownerOf(tokenId), buyer);

        // Check seller payment
        uint256 fee = (NFT_PRICE * MARKETPLACE_FEE) / 10000;
        uint256 sellerAmount = NFT_PRICE - fee;
        assertEq(seller.balance, sellerBalanceBefore + sellerAmount);

        // Check marketplace fee
        assertEq(address(marketplace).balance, fee);
    }

    function test_CancelOffer() public {
        uint256 tokenId = _mintAndApproveNFT();

        uint256 buyerBalanceBefore = buyer.balance;

        // Create an offer with ETH
        vm.startPrank(buyer);
        uint256 offerId =
            marketplace.createOffer{value: NFT_PRICE}(address(nft), tokenId, NFT_PRICE, address(0), 1 days);

        marketplace.cancelOffer(offerId);
        vm.stopPrank();

        // Check buyer's ETH was refunded
        assertEq(buyer.balance, buyerBalanceBefore);

        // Check offer status
        KuverseMarketplace.Offer memory offer = marketplace.getOffer(offerId);
        assertFalse(offer.isActive);
    }

    function test_WithdrawFunds() public {
        uint256 tokenId = _mintAndApproveNFT();

        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(address(nft), tokenId, NFT_PRICE, address(0));
        vm.stopPrank();

        vm.startPrank(buyer);
        marketplace.buyNFT{value: NFT_PRICE}(listingId);
        vm.stopPrank();

        uint256 fee = (NFT_PRICE * MARKETPLACE_FEE) / 10000;
        assertEq(address(marketplace).balance, fee);

        uint256 deployerBalanceBefore = deployer.balance;

        vm.startPrank(deployer);
        marketplace.withdrawFunds();
        vm.stopPrank();

        assertEq(deployer.balance, deployerBalanceBefore + fee);
        assertEq(address(marketplace).balance, 0);
    }

    function test_WithdrawERC20() public {
        uint256 tokenId = _mintAndApproveNFT();

        // Mint payment tokens to buyer
        vm.startPrank(deployer);
        paymentToken.mint(buyer, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(seller);
        uint256 listingId = marketplace.createListing(address(nft), tokenId, NFT_PRICE, address(paymentToken));
        vm.stopPrank();

        vm.startPrank(buyer);
        paymentToken.approve(address(marketplace), NFT_PRICE);
        marketplace.buyNFT(listingId);
        vm.stopPrank();

        uint256 fee = (NFT_PRICE * MARKETPLACE_FEE) / 10000;
        assertEq(paymentToken.balanceOf(address(marketplace)), fee);

        vm.startPrank(deployer);
        marketplace.withdrawERC20(address(paymentToken));
        vm.stopPrank();

        assertEq(paymentToken.balanceOf(deployer), fee);
        assertEq(paymentToken.balanceOf(address(marketplace)), 0);
    }
}
