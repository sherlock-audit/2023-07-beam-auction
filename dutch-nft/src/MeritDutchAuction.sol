// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MeritNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @dev Dutch auction NFT contract with a stepped declining price. Every user pays whatever is the price at that point in time.
/// @dev The owner can claim whatever ETH is in the contract at any time.
contract MeritDutchAuction is Ownable {

    // Maximum amount of NFTs that can be minted per address
    uint256 constant public CAP_PER_ADDRESS = 4;
    // Maximum amount of NFTs that can be minted in total
    uint256 constant public MINT_CAP = 10000;

    // Price at the start of the auction in wei
    uint256 public immutable startPrice;
    // Price at the end of the auction in wei
    uint256 public immutable endPrice;
    // Start time of the auction as a unix timestamp
    uint256 public immutable startTime;
    // End time of the auction as a unix timestamp
    uint256 public immutable endTime;
    // Duration of each step in seconds
    uint256 public immutable stepSize;

    // NFT contract which gets minted to users during the auction. Contract should allow the auction contract to mint NFTs
    MeritNFT public nft;

    // Amount of NFTs minted
    uint256 public minted;
    // Amount of NFTs minted per address
    mapping(address => uint256) public mintedPerAddress;
    
    // Total amount of ETH raised
    uint256 public totalRaised; 

    // Triggered on mint
    event Minted(address indexed to, uint256 amount, uint256 price);
    // Triggered on claim of proceeds by owner
    event ClaimedProceeds(uint256 amount);

    // Data returned from getAuctionData()
    struct AuctionData {
        uint256 startPrice;
        uint256 endPrice;
        uint256 currentPrice;
        uint256 totalRaised;
        uint256 minted;
        uint256 cap;
        uint256 startTime;
        uint256 endTime;
        uint256 stepSize;
        uint256[] priceSteps;
        uint256[] priceStepTimestamps;
        uint256 currentStep;
        uint256 timeToNextStep;
        uint256 timeToStart;
        uint256 timeToEnd;
    }

    /// @notice Constructor
    /// @param startPrice_ Price at the start of the auction
    /// @param endPrice_ Price at the end of the auction
    /// @param startTime_ Start time of the auction
    /// @param endTime_ End time of the auction
    /// @param stepSize_ Duration of each step
    constructor(
        uint256 startPrice_,
        uint256 endPrice_,
        uint256 startTime_,
        uint256 endTime_,
        uint256 stepSize_
    ) { 
        // Cannot have 0 second steps
        require(stepSize_ > 0, "Step size must be greater than 0");
        // Duration must be a multiple of step size
        require((endTime_ - startTime_) % stepSize_ == 0, "Step size must be multiple of total duration");
        // Start price must be greater than end price
        require(startPrice_ > endPrice_, "Start price must be greater than end price");

        startPrice = startPrice_;
        endPrice = endPrice_;
        startTime = startTime_;
        endTime = endTime_;
        stepSize = stepSize_;
    }

    /// @notice Sets the NFT contract address, can only be called once, only calable by owner
    /// @param nft_ Address of the NFT contract
    function setNFT(address nft_) external onlyOwner {
        // Can only be set once
        require(address(nft) == address(0), "NFT already set");
        // NFT contract must allow this contract to mint NFTs
        nft = MeritNFT(nft_);
    }

    /// @notice Returns the current price
    function getPrice() public view returns(uint256) {
        // Use the current timestamp to get the current price
        return getPriceAt(block.timestamp);
    }

    /// @notice Returns the price at a given time
    /// @param time Timestamp
    function getPriceAt(uint256 time) public view returns(uint256) {
        // If auction hasn't started yet, return start price
        if(time < startTime) {
            return startPrice;
        }
        // If auction has ended, return end price
        if(time >= endTime) {
            return endPrice;
        }

        uint256 timePassed = time - startTime;
        uint256 totalSteps = (endTime - startTime) / stepSize;
        uint256 currentStep = timePassed / stepSize;
        uint256 priceRange = startPrice - endPrice;

        // Calculate the price at the current step
        uint256 price = startPrice - (priceRange * currentStep / totalSteps);
        return price;
    }

    /// @notice Mints NFTs, can only be called during the auction or after the auction has ended and the price has reached the end price
    /// @param amount Amount of NFTs to mint
    function mint(uint256 amount) external payable {
        // Checks
        // Cache mintedBefore to save on sloads
        uint256 mintedBefore = minted;
        // Cache mintedPerAddressBefore to save on sloads
        uint256 mintedPerAddressBefore = mintedPerAddress[msg.sender];
        // Price being paid is the current price
        uint256 pricePaid = getPrice();
        // Total price being paid is the current price times the amount of NFTs
        uint256 totalPaid = pricePaid * amount;
        // Auction must have started
        require(block.timestamp >= startTime, "Auction not started");
        // Cannot mint more than the mint cap
        require(mintedBefore + amount <= MINT_CAP, "Mint cap reached");
        // Cannot mint more than the cap per address
        require(mintedPerAddressBefore + amount <= CAP_PER_ADDRESS, "Mint cap per address reached");
        // Make sure enough ETH was sent in the transaction
        require(msg.value >= totalPaid, "Insufficient funds");

        // Effects
        // Update amount minted in total
        minted += amount;
        // Update amount minted per address
        mintedPerAddress[msg.sender] += amount;
        // Update amount of ETH raised
        totalRaised += totalPaid;

        // Interactions
        for(uint256 i = 0; i < amount; i++) {
            // Mint the amount of NFTs to the sender
            nft.mint(mintedBefore + i + 1, msg.sender);
        }

        if(msg.value > totalPaid) {
            // If too much ETH was sent, refund the difference
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalPaid}(bytes(""));
            require(success, "Refund failed");
        }

        // Emit event for offchain integrations
        emit Minted(msg.sender, amount, pricePaid);
    }

    /// @notice Claims the proceeds of the auction, can only be called by the owner
    function claimProceeds() external onlyOwner {
        // Send ETH to the owner
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}(bytes(""));
        // Revert if transfer failed
        require(success, "Claim failed");
        // Emit event for offchain integrations
        emit ClaimedProceeds(address(this).balance);
    }

    /// @notice Returns the auction data, out of scope for the audit
    /// @dev out of scope for audit, only used for offchain integrations
    function getAuctionData() external view returns (AuctionData memory) {
        uint256[] memory priceSteps = new uint256[]((endTime - startTime) / stepSize + 1);
        uint256[] memory priceStepTimestamps = new uint256[]((endTime - startTime) / stepSize + 1);
        uint256 currentStep = 0;
        uint256 timeToNextStep = 0;
        uint256 timeToStart = 0;
        uint256 timeToEnd = 0;

        if(block.timestamp < startTime) {
            timeToStart = startTime - block.timestamp;
        } else if(block.timestamp >= endTime) {
            timeToEnd = 0;
        } else {
            uint256 timePassed = block.timestamp - startTime;
            currentStep = timePassed / stepSize;
            timeToNextStep = (currentStep + 1) * stepSize - timePassed;
            timeToEnd = endTime - block.timestamp;
        }

        for(uint256 i = 0; i < priceSteps.length; i++) {
            priceStepTimestamps[i] = startTime + i * stepSize;
            priceSteps[i] = getPriceAt(priceStepTimestamps[i]);
        }

        return AuctionData({
            startPrice: startPrice,
            endPrice: endPrice,
            currentPrice: getPrice(),
            totalRaised: totalRaised,
            minted: minted,
            cap: MINT_CAP,
            startTime: startTime,
            endTime: endTime,
            stepSize: stepSize,
            priceSteps: priceSteps,
            priceStepTimestamps: priceStepTimestamps,
            currentStep: currentStep,
            timeToNextStep: timeToNextStep,
            timeToStart: timeToStart,
            timeToEnd: timeToEnd
        });
    }

}