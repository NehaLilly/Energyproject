// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title Energy Marketplace Contract
/// @notice Verified sellers list energy units, buyers purchase them; sellers withdraw earnings safely.
/// @dev Includes pausable functionality for emergency control.
contract EnergyMarketplace is ReentrancyGuard, Ownable, Pausable {

    constructor() Ownable(msg.sender) {
        // You can add any initialization here if needed
    }

    struct EnergyListing {
        uint256 amount;           // Total units offered
        uint256 pricePerUnit;     // Price per unit in Wei
        uint256 amountAvailable;  // Units still available
        address payable seller;   // Seller address
        uint256 expiryTimestamp;  // Listing expiry unix timestamp
        bool cancelled;           // Cancelled flag
    }

    uint256 public listingCount;
    mapping(uint256 => EnergyListing) private listings;

    mapping(address => uint256) private pendingWithdrawals;
    mapping(address => bool) private verifiedSellers;

    // Events
    event EnergyListed(
        uint256 indexed listingId,
        uint256 amount,
        uint256 pricePerUnit,
        address indexed seller,
        uint256 expiryTimestamp
    );

    event EnergyPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 amountBought,
        uint256 totalPrice
    );

    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event Withdrawal(address indexed seller, uint256 amount);
    event ListingUpdated(uint256 indexed listingId, uint256 newPricePerUnit, uint256 newExpiryTimestamp);
    event SellerVerified(address indexed seller, bool verified);
    event ContractPaused(address indexed account);
    event ContractUnpaused(address indexed account);
    event ExpiredListingRemoved(uint256 indexed listingId, address indexed seller);

    // Modifiers
    modifier listingExists(uint256 listingId) {
        require(listingId > 0 && listingId <= listingCount, "Listing does not exist");
        _;
    }

    modifier onlySeller(uint256 listingId) {
        require(msg.sender == listings[listingId].seller, "Only seller can call");
        _;
    }

    modifier notExpired(uint256 listingId) {
        require(block.timestamp <= listings[listingId].expiryTimestamp, "Listing expired");
        _;
    }

    modifier notCancelled(uint256 listingId) {
        require(!listings[listingId].cancelled, "Listing cancelled");
        _;
    }

    modifier hasAvailability(uint256 listingId, uint256 amount) {
        require(amount > 0, "Amount must be > 0");
        require(listings[listingId].amountAvailable >= amount, "Not enough energy available");
        _;
    }

    modifier onlyVerifiedSeller() {
        require(verifiedSellers[msg.sender], "Seller not verified");
        _;
    }

    modifier onlyWhenActive() {
        require(!paused(), "Contract is paused");
        _;
    }

    // --- Seller verification ---

    function verifySeller(address seller, bool verified) external onlyOwner {
        verifiedSellers[seller] = verified;
        emit SellerVerified(seller, verified);
    }

    function isVerifiedSeller(address seller) external view returns (bool) {
        return verifiedSellers[seller];
    }

    // --- Main functions ---

    function listEnergy(
        uint256 _amount,
        uint256 _pricePerUnit,
        uint256 _expiryTimestamp
    ) external onlyVerifiedSeller onlyWhenActive {
        require(_amount > 0, "Amount must be > 0");
        require(_pricePerUnit > 0, "Price must be > 0");
        require(_expiryTimestamp > block.timestamp, "Expiry must be future");

        listingCount++;
        listings[listingCount] = EnergyListing({
            amount: _amount,
            pricePerUnit: _pricePerUnit,
            amountAvailable: _amount,
            seller: payable(msg.sender),
            expiryTimestamp: _expiryTimestamp,
            cancelled: false
        });

        emit EnergyListed(listingCount, _amount, _pricePerUnit, msg.sender, _expiryTimestamp);
    }

    function buyEnergy(uint256 _listingId, uint256 _amount)
        external
        payable
        nonReentrant
        listingExists(_listingId)
        notCancelled(_listingId)
        notExpired(_listingId)
        hasAvailability(_listingId, _amount)
        onlyWhenActive
    {
        EnergyListing storage listing = listings[_listingId];

        uint256 totalPrice = listing.pricePerUnit * _amount;
        require(msg.value == totalPrice, "Incorrect payment");

        listing.amountAvailable -= _amount;

        if (listing.amountAvailable == 0) {
            listing.cancelled = true;
        }

        pendingWithdrawals[listing.seller] += msg.value;

        emit EnergyPurchased(_listingId, msg.sender, _amount, totalPrice);
    }

    function cancelListing(uint256 _listingId)
        external
        listingExists(_listingId)
        onlySeller(_listingId)
        notCancelled(_listingId)
        notExpired(_listingId)
        onlyWhenActive
    {
        EnergyListing storage listing = listings[_listingId];
        require(listing.amountAvailable > 0, "No energy left to cancel");

        listing.cancelled = true;

        emit ListingCancelled(_listingId, msg.sender);
    }

    /// @notice Remove expired listing with leftover energy (seller can clean up)
    function unlistExpired(uint256 _listingId)
        external
        listingExists(_listingId)
        onlySeller(_listingId)
        notCancelled(_listingId)
    {
        EnergyListing storage listing = listings[_listingId];
        require(block.timestamp > listing.expiryTimestamp, "Listing not expired");
        require(listing.amountAvailable > 0, "No energy left");

        listing.cancelled = true;

        emit ExpiredListingRemoved(_listingId, msg.sender);
    }

    function withdraw() external nonReentrant onlyWhenActive {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawal(msg.sender, amount);
    }

    function updateListing(
        uint256 _listingId,
        uint256 _newPricePerUnit,
        uint256 _newExpiryTimestamp
    )
        external
        listingExists(_listingId)
        onlySeller(_listingId)
        notCancelled(_listingId)
        notExpired(_listingId)
        onlyWhenActive
    {
        require(_newPricePerUnit > 0, "Price must be > 0");
        require(_newExpiryTimestamp > block.timestamp, "Expiry must be future");

        EnergyListing storage listing = listings[_listingId];
        listing.pricePerUnit = _newPricePerUnit;
        listing.expiryTimestamp = _newExpiryTimestamp;

        emit ListingUpdated(_listingId, _newPricePerUnit, _newExpiryTimestamp);
    }

    // --- View functions ---

    function isListingActive(uint256 _listingId)
        external
        view
        listingExists(_listingId)
        returns (bool)
    {
        EnergyListing memory listing = listings[_listingId];
        return !listing.cancelled && listing.amountAvailable > 0 && block.timestamp <= listing.expiryTimestamp;
    }

    function getPendingWithdrawal(address seller) external view returns (uint256) {
        return pendingWithdrawals[seller];
    }

    function getListing(uint256 _listingId)
        external
        view
        listingExists(_listingId)
        returns (
            uint256 amount,
            uint256 pricePerUnit,
            uint256 amountAvailable,
            address seller,
            uint256 expiryTimestamp,
            bool cancelled
        )
    {
        EnergyListing memory listing = listings[_listingId];
        return (
            listing.amount,
            listing.pricePerUnit,
            listing.amountAvailable,
            listing.seller,
            listing.expiryTimestamp,
            listing.cancelled
        );
    }

    // --- Owner functions ---

    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    // --- Fallbacks ---

    receive() external payable {
        revert("Direct ETH transfer not allowed");
    }

    fallback() external payable {
        revert("Fallback called: not allowed");
    }
}