// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title KuverseMarketplace
 * @dev Contract for trading NFTs with ETH or ERC20 tokens
 * @custom:security-contact security@kuverse.app
 */
contract KuverseMarketplace is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Listing structure
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address paymentToken; // address(0) for ETH
        bool isActive;
    }

    // Offer structure
    struct Offer {
        address buyer;
        address nftContract;
        uint256 tokenId;
        uint256 offerPrice;
        address paymentToken; // address(0) for ETH
        uint256 expiresAt;
        bool isActive;
    }

    // Marketplace fee in basis points (e.g., 250 = 2.5%)
    uint256 public marketplaceFee;

    // Maximum fee that can be set (5%)
    uint256 public constant MAX_FEE = 500;

    // Mapping from listing ID to listing details
    mapping(uint256 => Listing) public listings;
    uint256 private _nextListingId;

    // Mapping from offer ID to offer details
    mapping(uint256 => Offer) public offers;
    uint256 private _nextOfferId;

    // Mapping from NFT contract to token ID to current listing ID
    mapping(address => mapping(uint256 => uint256)) public activeListingByToken;

    // Mapping of supported payment tokens (address(0) is ETH)
    mapping(address => bool) public supportedPaymentTokens;

    // Events
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken
    );
    event ListingUpdated(uint256 indexed listingId, uint256 newPrice);
    event ListingCancelled(uint256 indexed listingId);
    event ListingSold(uint256 indexed listingId, address indexed buyer, uint256 price);
    event OfferCreated(
        uint256 indexed offerId,
        address indexed buyer,
        address indexed nftContract,
        uint256 tokenId,
        uint256 offerPrice,
        address paymentToken,
        uint256 expiresAt
    );
    event OfferAccepted(uint256 indexed offerId);
    event OfferCancelled(uint256 indexed offerId);
    event MarketplaceFeeUpdated(uint256 newFee);
    event PaymentTokenStatusUpdated(address paymentToken, bool supported);
    event FundsWithdrawn(address to, uint256 amount);

    /**
     * @dev Constructor to initialize the marketplace
     * @param initialMarketplaceFee The initial marketplace fee in basis points
     */
    constructor(uint256 initialMarketplaceFee) Ownable(msg.sender) {
        require(initialMarketplaceFee <= MAX_FEE, "Fee too high");
        marketplaceFee = initialMarketplaceFee;

        // ETH is always supported
        supportedPaymentTokens[address(0)] = true;
    }

    /**
     * @dev Create a new listing
     * @param nftContract The address of the NFT contract
     * @param tokenId The ID of the NFT
     * @param price The price of the NFT
     * @param paymentToken The address of the ERC20 token for payment (address(0) for ETH)
     * @return listingId The ID of the created listing
     */
    function createListing(address nftContract, uint256 tokenId, uint256 price, address paymentToken)
        external
        returns (uint256)
    {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not the owner");
        require(IERC721(nftContract).isApprovedForAll(msg.sender, address(this)), "Not approved");
        require(supportedPaymentTokens[paymentToken], "Payment token not supported");
        require(price > 0, "Price must be greater than zero");

        // Ensure any previous listing is removed
        uint256 existingListingId = activeListingByToken[nftContract][tokenId];
        if (existingListingId > 0 && listings[existingListingId].isActive) {
            listings[existingListingId].isActive = false;
            emit ListingCancelled(existingListingId);
        }

        uint256 listingId = _nextListingId++;

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            paymentToken: paymentToken,
            isActive: true
        });

        activeListingByToken[nftContract][tokenId] = listingId;

        emit ListingCreated(listingId, msg.sender, nftContract, tokenId, price, paymentToken);

        return listingId;
    }

    /**
     * @dev Update the price of a listing
     * @param listingId The ID of the listing
     * @param newPrice The new price
     */
    function updateListing(uint256 listingId, uint256 newPrice) external {
        Listing storage listing = listings[listingId];

        require(listing.isActive, "Listing not active");
        require(listing.seller == msg.sender, "Not the seller");
        require(newPrice > 0, "Price must be greater than zero");

        listing.price = newPrice;

        emit ListingUpdated(listingId, newPrice);
    }

    /**
     * @dev Cancel a listing
     * @param listingId The ID of the listing
     */
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];

        require(listing.isActive, "Listing not active");
        require(listing.seller == msg.sender, "Not the seller");

        listing.isActive = false;
        activeListingByToken[listing.nftContract][listing.tokenId] = 0;

        emit ListingCancelled(listingId);
    }

    /**
     * @dev Buy an NFT from a listing
     * @param listingId The ID of the listing
     */
    function buyNFT(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];

        require(listing.isActive, "Listing not active");
        require(IERC721(listing.nftContract).ownerOf(listing.tokenId) == listing.seller, "Seller no longer owns NFT");

        uint256 price = listing.price;
        address paymentToken = listing.paymentToken;

        // Calculate marketplace fee
        uint256 fee = (price * marketplaceFee) / 10000;
        uint256 sellerAmount = price - fee;

        // Handle payment
        if (paymentToken == address(0)) {
            // Payment in ETH
            require(msg.value == price, "Incorrect ETH amount");

            // Transfer ETH to seller
            (bool success,) = payable(listing.seller).call{value: sellerAmount}("");
            require(success, "ETH transfer to seller failed");
        } else {
            // Payment in ERC20
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), fee);
            IERC20(paymentToken).safeTransferFrom(msg.sender, listing.seller, sellerAmount);
        }

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        // Update listing
        listing.isActive = false;
        activeListingByToken[listing.nftContract][listing.tokenId] = 0;

        emit ListingSold(listingId, msg.sender, price);
    }

    /**
     * @dev Create an offer for an NFT
     * @param nftContract The address of the NFT contract
     * @param tokenId The ID of the NFT
     * @param offerPrice The offered price
     * @param paymentToken The address of the ERC20 token for payment (address(0) for ETH)
     * @param duration The duration of the offer in seconds
     * @return offerId The ID of the created offer
     */
    function createOffer(
        address nftContract,
        uint256 tokenId,
        uint256 offerPrice,
        address paymentToken,
        uint256 duration
    ) external payable returns (uint256) {
        require(duration > 0 && duration <= 30 days, "Invalid duration");
        require(supportedPaymentTokens[paymentToken], "Payment token not supported");
        require(offerPrice > 0, "Offer price must be greater than zero");
        require(IERC721(nftContract).ownerOf(tokenId) != address(0), "NFT does not exist");

        // Handle ETH payment
        if (paymentToken == address(0)) {
            require(msg.value == offerPrice, "Incorrect ETH amount");
        } else {
            // Check allowance for ERC20
            require(IERC20(paymentToken).allowance(msg.sender, address(this)) >= offerPrice, "Insufficient allowance");
        }

        uint256 offerId = _nextOfferId++;
        uint256 expiresAt = block.timestamp + duration;

        offers[offerId] = Offer({
            buyer: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            offerPrice: offerPrice,
            paymentToken: paymentToken,
            expiresAt: expiresAt,
            isActive: true
        });

        emit OfferCreated(offerId, msg.sender, nftContract, tokenId, offerPrice, paymentToken, expiresAt);

        return offerId;
    }

    /**
     * @dev Accept an offer
     * @param offerId The ID of the offer
     */
    function acceptOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];

        require(offer.isActive, "Offer not active");
        require(block.timestamp < offer.expiresAt, "Offer expired");
        require(IERC721(offer.nftContract).ownerOf(offer.tokenId) == msg.sender, "Not the NFT owner");

        // Ensure NFT is approved
        require(
            IERC721(offer.nftContract).isApprovedForAll(msg.sender, address(this))
                || IERC721(offer.nftContract).getApproved(offer.tokenId) == address(this),
            "Not approved"
        );

        uint256 price = offer.offerPrice;
        address paymentToken = offer.paymentToken;

        // Calculate marketplace fee
        uint256 fee = (price * marketplaceFee) / 10000;
        uint256 sellerAmount = price - fee;

        // Handle payment
        if (paymentToken == address(0)) {
            // Payment in ETH
            (bool success,) = payable(msg.sender).call{value: sellerAmount}("");
            require(success, "ETH transfer to seller failed");
        } else {
            // Payment in ERC20
            IERC20(paymentToken).safeTransferFrom(offer.buyer, address(this), fee);
            IERC20(paymentToken).safeTransferFrom(offer.buyer, msg.sender, sellerAmount);
        }

        // Transfer NFT
        IERC721(offer.nftContract).safeTransferFrom(msg.sender, offer.buyer, offer.tokenId);

        // Update offer
        offer.isActive = false;

        // Cancel any active listing for this NFT
        uint256 listingId = activeListingByToken[offer.nftContract][offer.tokenId];
        if (listingId > 0 && listings[listingId].isActive) {
            listings[listingId].isActive = false;
            emit ListingCancelled(listingId);
        }

        emit OfferAccepted(offerId);
    }

    /**
     * @dev Cancel an offer
     * @param offerId The ID of the offer
     */
    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];

        require(offer.isActive, "Offer not active");
        require(offer.buyer == msg.sender, "Not the buyer");

        offer.isActive = false;

        // Refund ETH if applicable
        if (offer.paymentToken == address(0)) {
            (bool success,) = payable(msg.sender).call{value: offer.offerPrice}("");
            require(success, "ETH refund failed");
        }

        emit OfferCancelled(offerId);
    }

    /**
     * @dev Update the marketplace fee
     * @param newFee The new marketplace fee in basis points
     */
    function setMarketplaceFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "Fee too high");
        marketplaceFee = newFee;
        emit MarketplaceFeeUpdated(newFee);
    }

    /**
     * @dev Set the status of a payment token
     * @param paymentToken The address of the payment token
     * @param supported Whether the token is supported
     */
    function setPaymentTokenStatus(address paymentToken, bool supported) external onlyOwner {
        supportedPaymentTokens[paymentToken] = supported;
        emit PaymentTokenStatusUpdated(paymentToken, supported);
    }

    /**
     * @dev Withdraw accumulated fees to the owner
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        (bool success,) = payable(owner()).call{value: balance}("");
        require(success, "ETH withdrawal failed");

        emit FundsWithdrawn(owner(), balance);
    }

    /**
     * @dev Withdraw accumulated ERC20 tokens to the owner
     * @param token The address of the ERC20 token
     */
    function withdrawERC20(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        IERC20(token).safeTransfer(owner(), balance);

        emit FundsWithdrawn(owner(), balance);
    }

    /**
     * @dev Get details of a listing
     * @param listingId The ID of the listing
     * @return The listing details
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @dev Get details of an offer
     * @param offerId The ID of the offer
     * @return The offer details
     */
    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }
}
