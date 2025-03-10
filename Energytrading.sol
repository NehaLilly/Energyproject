// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EnergyMarketplace {
    struct EnergyListing {
        uint256 amount;  // Amount of energy units
        uint256 price;   // Price in Wei (1 ETH = 10^18 Wei)
        address payable seller;  // Seller's address (payable to receive ETH)
        address buyer;  // Track buyer address
        bool sold;  // Track if the energy is sold
    }

    mapping(uint256 => EnergyListing) public listings;
    uint256 public listingCount;

    event EnergyListed(uint256 listingId, uint256 amount, uint256 price, address indexed seller);
    event EnergyPurchased(uint256 listingId, address indexed buyer, uint256 amount, uint256 price);
    event ListingCancelled(uint256 listingId, address indexed seller);

    // ✅ List energy for sale
    function listEnergy(uint256 _amount, uint256 _price) public {
        require(_amount > 0, "Energy amount must be greater than 0");
        require(_price > 0, "Price must be greater than 0");

        listingCount++;
        listings[listingCount] = EnergyListing(_amount, _price, payable(msg.sender), address(0), false);
        emit EnergyListed(listingCount, _amount, _price, msg.sender);
    }

    // ✅ Buy energy (send ETH to seller)
    function buyEnergy(uint256 _listingId) public payable {
        EnergyListing storage listing = listings[_listingId];

        require(!listing.sold, "Energy already sold");
        require(msg.value == listing.price, "Incorrect ETH amount");

        listing.seller.transfer(msg.value);  // Transfer ETH to the seller
        listing.buyer = msg.sender;  // Store buyer's address
        listing.sold = true;  // Mark as sold

        emit EnergyPurchased(_listingId, msg.sender, listing.amount, listing.price);
    }

    // ✅ Cancel energy listing (only seller can cancel before purchase)
    function cancelListing(uint256 _listingId) public {
        EnergyListing storage listing = listings[_listingId];

        require(msg.sender == listing.seller, "Only the seller can cancel the listing");
        require(!listing.sold, "Listing already sold");

        delete listings[_listingId];  // Remove listing
        emit ListingCancelled(_listingId, msg.sender);
    }

    // ✅ Allow contract to receive ETH
    receive() external payable {}

    fallback() external payable {}
}
