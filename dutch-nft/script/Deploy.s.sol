// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/MeritDutchAuction.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address: %s", deployer);

        uint256 startPrice = 0;
        uint256 endPrice = 0;
        uint256 startTime = 0;
        uint256 endTime = 0;
        uint256 stepSize = 0;

        string memory name = "Merit NFT";
        string memory symbol = "MERIT";
        string memory baseURI = "https://example.com/";
        address uriSetter = address(0xffffffff5);

        // Starting transactions
        vm.startBroadcast(deployerPrivateKey);

        MeritDutchAuction auction = new MeritDutchAuction(
            startPrice,
            endPrice,
            startTime,
            endTime,
            stepSize
        );


        MeritNFT nft = new MeritNFT(
            name,
            symbol,
            baseURI,
            uriSetter,
            address(auction)
        );

        auction.setNFT(address(nft));

        // Ending transactions
        vm.stopBroadcast();

        // Print contract addresses
        console.log("NFT address: %s", address(nft));
        console.log("Auction address: %s", address(auction));

    }
}