// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EnergyMarketplace {
    struct EnergyListing {
        uint256 amount;
        uint256 price;
        address seller;
    }

    mapping(uint256 => EnergyListing) public listings;
    uint256 public listingCount;

    event EnergyListed(uint256 listingId, uint256 amount, uint256 price, address indexed seller);

    function listEnergy(uint256 _amount, uint256 _price) public {
        listingCount++;
        listings[listingCount] = EnergyListing(_amount, _price, msg.sender);
        emit EnergyListed(listingCount, _amount, _price, msg.sender);
    }

    // ✅ Add this function to allow Ether payments!
    receive() external payable {}

    fallback() external payable {}
}
