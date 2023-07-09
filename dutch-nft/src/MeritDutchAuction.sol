// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MeritNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @dev Dutch auction NFT contract with a stepped declining price. Every user pays whatever is the price at that point in time.
/// @dev The owner can claim whatever ETH is in the contract at any time.
contract MeritDutchAuction is Ownable {

    uint256 constant public CAP_PER_ADDRESS = 4;
    uint256 constant public MINT_CAP = 10000;

    uint256 public immutable startPrice;
    uint256 public immutable endPrice;
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable stepSize;

    MeritNFT public nft;

    uint256 public minted;
    mapping(address => uint256) public mintedPerAddress;
    
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
        require(stepSize_ > 0, "Step size must be greater than 0");
        require((endTime_ - startTime_) % stepSize_ == 0, "Step size must be multiple of total duration");
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
        require(address(nft) == address(0), "NFT already set");
        nft = MeritNFT(nft_);
    }

    /// @notice Returns the current price
    function getPrice() public view returns(uint256) {
        return getPriceAt(block.timestamp);
    }

    /// @notice Returns the price at a given time
    /// @param time Timestamp
    function getPriceAt(uint256 time) public view returns(uint256) {
        if(time < startTime) {
            return startPrice;
        }
        if(time >= endTime) {
            return endPrice;
        }
        uint256 timePassed = time - startTime;
        uint256 totalSteps = (endTime - startTime) / stepSize;
        uint256 currentStep = timePassed / stepSize;
        uint256 priceRange = startPrice - endPrice;

        uint256 price = startPrice - (priceRange * currentStep / totalSteps);
        return price;
    }

    /// @notice Mints NFTs, can only be called during the auction or after the auction has ended and the price has reached the end price
    /// @param amount Amount of NFTs to mint
    function mint(uint256 amount) external payable {
        // Checks
        uint256 mintedBefore = minted;
        uint256 mintedPerAddressBefore = mintedPerAddress[msg.sender];
        uint256 pricePaid = getPrice();
        uint256 totalPaid = pricePaid * amount;
        require(block.timestamp >= startTime, "Auction not started");
        require(mintedBefore + amount <= MINT_CAP, "Mint cap reached");
        require(mintedPerAddressBefore + amount <= CAP_PER_ADDRESS, "Mint cap per address reached");
        require(msg.value >= totalPaid, "Insufficient funds");

        // Effects
        minted += amount;
        mintedPerAddress[msg.sender] += amount;
        totalRaised += totalPaid;

        // Interactions
        for(uint256 i = 0; i < amount; i++) {
            nft.mint(mintedBefore + i + 1, msg.sender);
        }

        if(msg.value > totalPaid) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalPaid}(bytes(""));
            require(success, "Refund failed");
        }

        emit Minted(msg.sender, amount, pricePaid);
    }

    /// @notice Claims the proceeds of the auction, can only be called by the owner
    function claimProceeds() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}(bytes(""));
        require(success, "Claim failed");
        emit ClaimedProceeds(address(this).balance);
    }

    /// @notice Returns the auction data, out of scope for the audit
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