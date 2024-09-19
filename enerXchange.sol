// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract EnerXchange is ERC20, Ownable2Step, ReentrancyGuard {
    struct EnergyListing {
        address seller;
        uint256 amount;
        uint256 pricePerUnit;
        uint256 expirationTime;
        bool active;
    }

    mapping(uint256 => EnergyListing) public energyListings;
    uint256 public nextListingId;

    event EnergyListed(uint256 indexed listingId, address indexed seller, uint256 amount, uint256 pricePerUnit, uint256 expirationTime);
    event EnergyPurchased(uint256 indexed listingId, address indexed buyer, uint256 amount, uint256 totalPrice);
    event ListingCancelled(uint256 indexed listingId);
    event EnergyMinted(address indexed to, uint256 amount);

    constructor(address initialOwner) 
        ERC20("EnerXchange Token", "EXT") 
        Ownable(initialOwner)
        payable
    {
        _mint(initialOwner, 1e6 * 10**decimals());
    }

    function mintEnergy(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit EnergyMinted(to, amount);
    }

    modifier validListing(uint256 listingId) {
        require(energyListings[listingId].active, "Listing not active");
        _;
    }

    function listEnergy(uint256 amount, uint256 pricePerUnit, uint256 duration) external {
        require(amount != 0, "Amount must not be zero");
        require(pricePerUnit != 0, "Price must not be zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 listingId = nextListingId++;
        EnergyListing storage newListing = energyListings[listingId];
        newListing.seller = msg.sender;
        newListing.amount = amount;
        newListing.pricePerUnit = pricePerUnit;
        newListing.expirationTime = block.timestamp + duration;
        newListing.active = true;

        _transfer(msg.sender, address(this), amount);

        emit EnergyListed(listingId, msg.sender, amount, pricePerUnit, newListing.expirationTime);
    }

    function cancelListing(uint256 listingId) external validListing(listingId) {
        EnergyListing storage listing = energyListings[listingId];
        require(listing.seller == msg.sender, "Not the seller");

        listing.active = false;
        _transfer(address(this), msg.sender, listing.amount);

        emit ListingCancelled(listingId);
    }

    function purchaseEnergy(uint256 listingId, uint256 amount) external nonReentrant validListing(listingId) {
        EnergyListing storage listing = energyListings[listingId];
        require(block.timestamp < listing.expirationTime, "Listing expired");
        require(amount <= listing.amount, "Not enough energy available");

        uint256 totalPrice = amount * listing.pricePerUnit;
        require(balanceOf(msg.sender) >= totalPrice, "Insufficient balance");

        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
        }

        _transfer(msg.sender, listing.seller, totalPrice);
        _transfer(address(this), msg.sender, amount);

        emit EnergyPurchased(listingId, msg.sender, amount, totalPrice);
    }

    function getListingDetails(uint256 listingId) external view returns (EnergyListing memory) {
        return energyListings[listingId];
    }
}