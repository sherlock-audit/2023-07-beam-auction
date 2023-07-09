// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MeritNFT.sol";
import "../src/MeritDutchAuction.sol";

contract MeritDutchAuctionTest is Test {
    string constant NAME = "Merit NFT";
    string constant SYMBOL = "MERIT";
    string constant BASE_URI = "https://example.com/";

    address constant wallet1 = address(0xffffffff1);
    address constant wallet2 = address(0xffffffff2);
    address constant wallet3 = address(0xffffffff3);
    address constant owner = address(0xffffffff4);
    address constant uriSetter = address(0xffffffff5);

    uint256 constant START_PRICE = 1e18;
    uint256 constant END_PRICE = 0.1e18;
    uint256 constant AUCTION_DURATION = 2 hours;
    uint256 constant STEP_SIZE = 12 minutes;

    uint256 public startTime;
    uint256 public endTime;

    MeritNFT public nft;
    MeritDutchAuction public auction;

    function setUp() public {
        vm.startPrank(owner);

        startTime = block.timestamp + 1 days;
        endTime = startTime + AUCTION_DURATION;

        auction = new MeritDutchAuction(
            START_PRICE,
            END_PRICE,
            startTime,
            endTime,
            STEP_SIZE
        );

        nft = new MeritNFT(NAME, SYMBOL, BASE_URI, uriSetter, address(auction));
        auction.setNFT(address(nft));

        // Gift eth to test addresses
        vm.deal(wallet1, 1000000e18);
        vm.deal(wallet2, 1000000e18);
        vm.deal(wallet3, 1000000e18);

        vm.stopPrank();
    }

    function testConstructor() public {
        assertEq(auction.startPrice(), START_PRICE);
        assertEq(auction.endPrice(), END_PRICE);
        assertEq(auction.startTime(), startTime);
        assertEq(auction.endTime(), endTime);
        assertEq(auction.stepSize(), STEP_SIZE);
        assertEq(address(auction.nft()), address(nft));
        assertEq(auction.minted(), 0);
        assertEq(auction.totalRaised(), 0);
        assertEq(auction.owner(), owner);
    }

    function testSetNFT() public {
        vm.startPrank(owner);
        MeritDutchAuction tempAuction = new MeritDutchAuction(
            START_PRICE,
            END_PRICE,
            startTime,
            endTime,
            STEP_SIZE
        );

        tempAuction.setNFT(address(1337));
        assertEq(address(tempAuction.nft()), address(1337));
    }

    function setNFTFromNonOwnerShouldFail() public {
        vm.startPrank(wallet1);
        vm.expectRevert("Ownable: caller is not the owner");
        auction.setNFT(address(1337));
    }

    function setNFTMoreThanOnceShouldFail() public {
        vm.startPrank(owner);
        vm.expectRevert("NFT already set");
        auction.setNFT(address(1337));
    }

    function testMintSingleExactAmount() public {
        vm.startPrank(wallet1);
        vm.warp(startTime);
        auction.mint{value: START_PRICE}(1);

        assertEq(auction.minted(), 1);
        assertEq(auction.totalRaised(), START_PRICE);
        assertEq(address(auction).balance, START_PRICE);
        assertEq(auction.mintedPerAddress(wallet1), 1);
        assertEq(nft.ownerOf(1), wallet1);
    }

    function testMintSingleOverypay() public {
        vm.startPrank(wallet1);
        uint256 balanceBefore = address(wallet1).balance;
        vm.warp(startTime);
        auction.mint{value: START_PRICE + 1e18}(1);
        uint256 balanceAfter = address(wallet1).balance;

        assertEq(auction.minted(), 1);
        assertEq(auction.totalRaised(), START_PRICE);
        assertEq(address(auction).balance, START_PRICE);
        assertEq(auction.mintedPerAddress(wallet1), 1);
        assertEq(nft.ownerOf(1), wallet1);
        assertEq(balanceBefore - balanceAfter, START_PRICE);
    }

    function testMintSingleUnderpayShouldFail() public {
        vm.startPrank(wallet1);
        vm.warp(startTime);
        vm.expectRevert("Insufficient funds");
        auction.mint{value: START_PRICE - 1e18}(1);
    }

    function testMintMultiple() public {
        vm.startPrank(wallet1);
        uint256 balanceBefore = wallet1.balance;
        vm.warp(startTime);
        auction.mint{value: START_PRICE * 3}(3);
        uint256 balanceAfter = wallet1.balance;

        assertEq(auction.minted(), 3);
        assertEq(auction.totalRaised(), START_PRICE * 3);
        assertEq(address(auction).balance, START_PRICE * 3);
        assertEq(auction.mintedPerAddress(wallet1), 3);
        assertEq(nft.ownerOf(1), wallet1);
        assertEq(nft.ownerOf(2), wallet1);
        assertEq(nft.ownerOf(3), wallet1);
        assertEq(balanceBefore - balanceAfter, START_PRICE * 3);
        
        vm.stopPrank();
    }

    function testMintMultipleUnderpayShouldFail() public {
        vm.startPrank(wallet1);
        vm.warp(startTime);
        vm.expectRevert("Insufficient funds");
        auction.mint{value: START_PRICE * 3 - 1e18}(3);
    }

    function testMintBeforeStartShouldFail() public {
        vm.prank(wallet1);
        vm.expectRevert("Auction not started");
        auction.mint(1);
        vm.stopPrank();
    }

    function testMintAfterEnd() public {
        vm.startPrank(wallet1);
        uint256 balanceBefore = wallet1.balance;
        vm.warp(endTime + 1);
        auction.mint{value: START_PRICE}(1);
        uint256 balanceAfter = wallet1.balance;

        assertEq(auction.minted(), 1);
        assertEq(auction.totalRaised(), END_PRICE);
        assertEq(address(auction).balance, END_PRICE);
        assertEq(auction.mintedPerAddress(wallet1), 1);
        assertEq(nft.ownerOf(1), wallet1);
        assertEq(balanceBefore - balanceAfter, END_PRICE);
        vm.stopPrank();
    }

    function testMintMoreThanCapShouldFail() public {        
        uint256 cap = auction.MINT_CAP();
        
        vm.warp(startTime);
        for(uint256 i = 0; i < cap; i++) {
            address wallet = vm.addr(uint256(keccak256(abi.encodePacked(i, "kekekekek"))));
            vm.deal(wallet, 1000000e18);
            vm.prank(wallet);
            auction.mint{value: START_PRICE}(1);
        }

        vm.expectRevert("Mint cap reached");
        vm.prank(wallet1);
        auction.mint{value: START_PRICE}(1);
    }

    function testMintMoreThanCapPerAddressShouldFail() public {
        uint256 cap = auction.CAP_PER_ADDRESS();
        
        vm.startPrank(wallet1);
        vm.warp(startTime);
        auction.mint{value: START_PRICE * cap}(cap);

        vm.expectRevert("Mint cap per address reached");
        auction.mint{value: START_PRICE}(1);
        vm.stopPrank();
    }

    function testClaimProceeds() public {
        vm.startPrank(wallet1);
        vm.warp(startTime);
        auction.mint{value: START_PRICE}(1);
        vm.stopPrank();
        vm.prank(owner);
        uint256 balanceBefore = address(owner).balance;
        auction.claimProceeds();
        uint256 balanceAfter = address(owner).balance;

        assertEq(balanceAfter - balanceBefore, START_PRICE);
        assertEq(address(auction).balance, 0);
        vm.stopPrank();
    }

    function testClaimProceedsFromNonOwnerShouldFail() public {
        vm.startPrank(wallet1);
        vm.warp(startTime);
        auction.mint{value: START_PRICE}(1);
        vm.expectRevert("Ownable: caller is not the owner");
        auction.claimProceeds();
        vm.stopPrank();
    }


    function testRunAuction() public {
        uint256 cap = auction.MINT_CAP();
        uint256 timeRange = endTime - startTime;
        uint256 timePerMint = timeRange / cap;

        uint256 totalPaid = 0;

        for(uint256 i = 0; i < cap; i++) {
            address wallet = vm.addr(uint256(keccak256(abi.encodePacked(i, "kekekekek"))));
            vm.deal(wallet, 1000000e18);
            vm.startPrank(wallet);
            uint256 time = startTime + timePerMint * i;
            uint256 price = auction.getPriceAt(time);
            totalPaid += price;

            vm.warp(time);
            auction.mint{value: price}(1);
            vm.stopPrank();
        }

        assertEq(auction.minted(), cap);
        assertEq(auction.totalRaised(), totalPaid);
        assertEq(address(auction).balance, totalPaid);
    }

}
