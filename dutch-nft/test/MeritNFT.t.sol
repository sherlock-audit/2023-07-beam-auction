// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MeritNFT.sol";

contract MeritNFTTest is Test {

    string constant NAME = "Merit NFT";
    string constant SYMBOL = "MERIT";
    string constant BASE_URI = "https://example.com/";
    
    address constant wallet1 = address(0xffffffff1);
    address constant wallet2 = address(0xffffffff2);
    address constant wallet3 = address(0xffffffff3);
    address constant owner = address(0xffffffff4);
    address constant uriSetter = address(0xffffffff5);
    address constant minter = address(0xffffffff6);

    MeritNFT public nft;

    function setUp() public {
        vm.prank(owner);
        nft = new MeritNFT(NAME, SYMBOL, BASE_URI, uriSetter, minter);
    }

    function testConstructor() public {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.baseURI(), BASE_URI);
        assertTrue(nft.hasRole(nft.URI_SETTER(), uriSetter));
        assertEq(nft.getRoleMemberCount(nft.URI_SETTER()), 1);
        assertTrue(nft.hasRole(nft.MINTER_ROLE(), minter));
        assertEq(nft.getRoleMemberCount(nft.MINTER_ROLE()), 1);
    }

    function testMint() public {
        vm.prank(minter);
        nft.mint(1, wallet1);
        assertEq(nft.balanceOf(wallet1), 1);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.ownerOf(1), wallet1);
    }

    function testMintFromNonMinterShouldFail() public {
        vm.startPrank(wallet1);
        vm.expectRevert(MeritNFT.OnlyMinterError.selector);
        nft.mint(1, wallet1);
        vm.stopPrank();
    }

    function testMintSameTokenIdShouldFail() public {
        vm.prank(minter);
        nft.mint(1, wallet1);
        vm.expectRevert();
        nft.mint(1, wallet1);
        vm.stopPrank();
    }

    function testSetBaseURI() public {
        vm.prank(uriSetter);
        nft.setBaseURI("https://example2.com/");
        assertEq(nft.baseURI(), "https://example2.com/");
        vm.stopPrank();
    }

    function testSetBaseURIFromNonUriSetterShouldFail() public {
        vm.startPrank(wallet1);
        vm.expectRevert(MeritNFT.OnlyURISetter.selector);
        nft.setBaseURI("https://example2.com/");
        vm.stopPrank();
    }

    function testTokenUri() public {
        vm.prank(minter);
        nft.mint(1, wallet1);
        assertEq(nft.tokenURI(1), "https://example.com/1.json");
        vm.stopPrank();
    }

}