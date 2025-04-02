// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title KuverseNFT
 * @dev Implementation of ERC-721 token with metadata and royalty support
 * @custom:security-contact security@kuverse.app
 */
contract KuverseNFT is ERC721URIStorage, Ownable {
    using Strings for uint256;

    // Counter for token IDs
    uint256 private _tokenIdCounter;

    // Mapping from token ID to metadata
    struct NFTMetadata {
        string name;
        string description;
        string imageURI;
    }

    mapping(uint256 => NFTMetadata) private _metadata;

    // Maximum supply
    uint256 public immutable maxSupply;

    // Royalty percentage (in basis points, e.g., 250 = 2.5%)
    uint256 public royaltyBasisPoints;

    // Base URI for token metadata
    string private _baseTokenURI;

    // Interface ID for ERC-2981 (Royalty Standard)
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    // Events
    event NFTMinted(address indexed to, uint256 indexed tokenId, string name, string description, string imageURI);
    event RoyaltyUpdated(uint256 newRoyaltyBasisPoints);
    event BaseURIUpdated(string newBaseURI);

    /**
     * @dev Constructor to initialize the NFT collection
     * @param name_ The name of the NFT collection
     * @param symbol_ The symbol of the NFT collection
     * @param maxSupply_ The maximum supply of NFTs
     * @param initialRoyaltyBasisPoints The initial royalty percentage in basis points
     * @param initialBaseURI The initial base URI for the NFTs
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 initialRoyaltyBasisPoints,
        string memory initialBaseURI
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(initialRoyaltyBasisPoints <= 1000, "Royalty too high");
        maxSupply = maxSupply_;
        royaltyBasisPoints = initialRoyaltyBasisPoints;
        _baseTokenURI = initialBaseURI;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721URIStorage) returns (bool) {
        return interfaceId == _INTERFACE_ID_ERC2981 || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Mint a new NFT with metadata
     * @param to The address to mint the NFT to
     * @param name The name of the NFT
     * @param description The description of the NFT
     * @param imageURI The image URI of the NFT
     * @return tokenId The ID of the minted NFT
     */
    function mint(address to, string memory name, string memory description, string memory imageURI)
        public
        returns (uint256)
    {
        uint256 tokenId = _tokenIdCounter;
        require(tokenId < maxSupply, "Max supply reached");

        _tokenIdCounter++;

        // Store metadata
        _metadata[tokenId] = NFTMetadata({name: name, description: description, imageURI: imageURI});

        // Create token URI with metadata
        string memory tokenURI = string(abi.encodePacked(_baseTokenURI, tokenId.toString()));

        // Mint the NFT
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit NFTMinted(to, tokenId, name, description, imageURI);

        return tokenId;
    }

    /**
     * @dev Allow users to mint their own NFT
     * @param name The name of the NFT
     * @param description The description of the NFT
     * @param imageURI The image URI of the NFT
     * @return tokenId The ID of the minted NFT
     */
    function mintOwn(string memory name, string memory description, string memory imageURI)
        external
        returns (uint256)
    {
        return mint(msg.sender, name, description, imageURI);
    }

    /**
     * @dev Get the metadata for a token
     * @param tokenId The ID of the NFT
     * @return The metadata of the NFT
     */
    function getMetadata(uint256 tokenId) external view returns (NFTMetadata memory) {
        require(_exists(tokenId), "NFT does not exist");
        return _metadata[tokenId];
    }

    /**
     * @dev Set the royalty basis points
     * @param newRoyaltyBasisPoints The new royalty percentage in basis points
     */
    function setRoyaltyBasisPoints(uint256 newRoyaltyBasisPoints) external onlyOwner {
        require(newRoyaltyBasisPoints <= 1000, "Royalty too high");
        royaltyBasisPoints = newRoyaltyBasisPoints;
        emit RoyaltyUpdated(newRoyaltyBasisPoints);
    }

    /**
     * @dev Set the base URI for token metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Get royalty information for a token
     * @param tokenId The ID of the NFT
     * @param salePrice The sale price of the NFT
     * @return receiver The address that should receive royalties
     * @return royaltyAmount The royalty amount to be paid
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "NFT does not exist");
        return (owner(), (salePrice * royaltyBasisPoints) / 10000);
    }

    /**
     * @dev Batch mint multiple NFTs at once
     * @param to The address to mint the NFTs to
     * @param quantity The number of NFTs to mint
     * @param name The base name for all NFTs
     * @param description The description for all NFTs
     * @param baseImageURI The base image URI for all NFTs
     * @return The array of minted token IDs
     */
    function batchMint(
        address to,
        uint256 quantity,
        string memory name,
        string memory description,
        string memory baseImageURI
    ) external returns (uint256[] memory) {
        require(quantity > 0, "Quantity must be greater than 0");
        require(_tokenIdCounter + quantity <= maxSupply, "Would exceed max supply");

        uint256[] memory tokenIds = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            // Create a unique name and image URI for each NFT
            string memory nftName = string(abi.encodePacked(name, " #", Strings.toString(i + 1)));
            string memory imageURI = string(abi.encodePacked(baseImageURI, Strings.toString(i + 1)));

            tokenIds[i] = mint(to, nftName, description, imageURI);
        }

        return tokenIds;
    }

    /**
     * @dev Check if a token exists
     * @param tokenId The ID of the NFT
     * @return Whether the NFT exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Base URI for computing {tokenURI}.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
