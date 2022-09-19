// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PuzzleMaster } from "src/PuzzleMaster.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Test, console } from "@forge-std/Test.sol";

contract PuzzleMasterTest is Test {

    ERC20 private WETH = ERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    PuzzleMaster private master;

    address public alice = vm.addr(1);
    address public bob = vm.addr(2);

    function setUp() public {
        bytes32 zeroRoot;
        master = new PuzzleMaster(zeroRoot, WETH);
    }

    function _addPrize(uint256 amount, string memory guess) internal {
        deal(address(WETH), address(this), amount);
        WETH.approve(address(master), amount);
        bytes32 prizeHash = master.getHash(guess);
        master.addPrize(prizeHash, amount);
    }

    function _createMerkleTree(address userA, address userB) internal pure returns(bytes32 root, bytes32 leafA, bytes32 leafB) {
        /**
         *            root
         *            / \
         *           /  \
         *          /   \
         *       userA userB
         */
        leafA = keccak256(abi.encodePacked(userA));
        leafB = keccak256(abi.encodePacked(userB));
        root = keccak256(abi.encodePacked(leafA, leafB));
    }

    uint256 private saltIndex;
    function _mutate(uint256 salt) internal returns (uint256) {
        saltIndex++;
        uint256 random = uint256(keccak256(abi.encode(salt, saltIndex)));
        random = bound(random, 1, type(uint224).max);
        return random;
    }

    function testClaimPrizeNoMerkle(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        string memory guess = "1";
        _addPrize(amount, guess);

        bytes32[] memory proof;
        bytes32 leaf;

        vm.prank(alice);
        master.claimPrize(proof, leaf, guess);

        // Make sure Alice received her prize.
        assertEq(WETH.balanceOf(alice), amount, "Alice should have received WETH from prize claim.");

        // Bob tries to claim the same prize.
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PuzzleMaster.PuzzleMaster__NoPrize.selector));
        master.claimPrize(proof, leaf, guess);

        // Make sure no prizes remain.
        (bytes32[] memory allPrizes, uint256[] memory amounts) = master.getActivePrizes();
        assertEq(allPrizes.length, 0, "There should be no prizes left.");
        assertEq(amounts.length, 0, "There should be no prizes left.");
        uint256 prizeAmount = master.prizes(master.getHash(guess));
        assertEq(prizeAmount, 0, "Prize amount should be zero.");
    }

    function testClaimPrizeWithMerkle(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        string memory guess = "1";
        _addPrize(amount, guess);

        (bytes32 root, bytes32 aliceLeaf, bytes32 bobLeaf) = _createMerkleTree(alice, bob);
        master.changeRoot(root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        vm.prank(alice);
        master.claimPrize(proof, aliceLeaf, guess);

        assertEq(WETH.balanceOf(alice), amount, "Alice should have received WETH from prize claim.");
    }

    function testClaimPrizeWithMerkleFrontRun(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        string memory guess = "1";
        _addPrize(amount, guess);

        (bytes32 root, bytes32 aliceLeaf, bytes32 bobLeaf) = _createMerkleTree(alice, bob);
        master.changeRoot(root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        // Attacker sees Alice's TX in mem pool, and tries to steal her prize.
        address attacker = vm.addr(1234);
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(PuzzleMaster.PuzzleMaster__InvalidProof.selector));
        master.claimPrize(proof, aliceLeaf, guess);
    }

    function testAddPrize(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        string memory guess = "1";
        _addPrize(amount, guess);

        // Adding an existing prize should revert.
        bytes32 prizeHash = master.getHash(guess);
        vm.expectRevert(abi.encodeWithSelector(PuzzleMaster.PuzzleMaster__PrizeAlreadySet.selector));
        master.addPrize(prizeHash, amount);

        assertEq(WETH.balanceOf(address(master)), amount, "Puzzle master should have `amount` of WETH.");
        assertEq(master.prizes(prizeHash), amount, "Prize should have been recorded in Puzzle Master.");
        (bytes32[] memory allPrizes, uint256[] memory amounts) = master.getActivePrizes();
        assertEq(allPrizes[0], prizeHash, "Prize hash should be in set.");
        assertEq(amounts[0], amount, "Prize amount should be in puzzle master.");
        assertEq(allPrizes.length, 1, "There should one prize left.");
        assertEq(amounts.length, 1, "There should one prize left.");
    }

    function testRemovePrize(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        string memory guess = "1";
        _addPrize(amount, guess);
        bytes32 prizeHash = master.getHash(guess);
        master.removePrize(prizeHash);

        assertEq(WETH.balanceOf(address(this)), amount, "Caller should have `amount` of WETH.");
        assertEq(WETH.balanceOf(address(master)), 0, "Puzzle master should have zero WETH.");
        
        assertEq(master.prizes(prizeHash), 0, "Prize should have been removed from Puzzle Master.");
        (bytes32[] memory allPrizes, uint256[] memory amounts) = master.getActivePrizes();
        assertEq(allPrizes.length, 0, "There should be no prizes left.");
        assertEq(amounts.length, 0, "There should be no prizes left.");
    }

    function testShutdown(uint256 amount) public {
        amount = bound(amount, 1, type(uint224).max);
        _addPrize(amount, "1");
        _addPrize(amount, "2");
        _addPrize(amount, "3");
        _addPrize(amount, "4");

        master.shutdown();
        assertEq(WETH.balanceOf(address(this)), 4 * amount, "Caller should have got all the WETH from puzzle master.");
        assertEq(WETH.balanceOf(address(master)), 0, "Puzzle master should have zero WETH.");
    }

    function testMultiplePrizesMultipleUsers(uint8 salt) public {
        
        uint256[] memory prizes = new uint256[](4);
        string[] memory guesses = new string[](4);
        _addPrize(prizes[0] = _mutate(salt), guesses[0] = "1");
        _addPrize(prizes[1] = _mutate(salt), guesses[1] = "2");
        _addPrize(prizes[2] = _mutate(salt), guesses[2] = "3");
        _addPrize(prizes[3] = _mutate(salt), guesses[3] = "4");

        (bytes32 root, bytes32 leafA, bytes32 leafB) = _createMerkleTree(alice, bob);
        master.changeRoot(root);

        (bytes32[] memory allPrizes, uint256[] memory amounts) = master.getActivePrizes();
        assertEq(allPrizes.length, 4, "There should one prize left.");
        assertEq(amounts.length, 4, "There should one prize left.");
        for (uint256 i=0; i<4; i++) {
            assertEq(allPrizes[i], master.getHash(guesses[i]), "Prize hash differs from expected.");
            assertEq(amounts[i], prizes[i], "Prize amount differs from expected.");
        }
        bytes32[] memory proof = new bytes32[](1);

        // Alice claims a prize.
        proof[0] = leafB;
        vm.prank(alice);
        master.claimPrize(proof, leafA, "1");
        assertEq(WETH.balanceOf(alice), prizes[0], "Alice should have received the first prize.");

        // Bob claims a prize.
        proof[0] = leafA;
        vm.prank(bob);
        master.claimPrize(proof, leafB, "2");
        assertEq(WETH.balanceOf(bob), prizes[1], "Bob should have received the second prize.");

        // Bob sells his crows on mainnet to Sally. And a new merkle root is calculated.
        address sally = vm.addr(7);
        (root, leafA, leafB) = _createMerkleTree(alice, sally);
        master.changeRoot(root);

        // Bob tries to claim a prize and TX reverts.
        bytes32 bobHash = keccak256(abi.encodePacked(bob));
        proof[0] = leafA;
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PuzzleMaster.PuzzleMaster__InvalidProof.selector));
        master.claimPrize(proof, bobHash, "3");

        // Sally claims the prize instead.
        proof[0] = leafA;
        vm.prank(sally);
        master.claimPrize(proof, leafB, "3");
        assertEq(WETH.balanceOf(sally), prizes[2], "Sally should have received the third prize.");

        // Alice claims the last prize.
        proof[0] = leafB;
        vm.prank(alice);
        master.claimPrize(proof, leafA, "4");
        assertEq(WETH.balanceOf(alice), prizes[0] + prizes[3], "Alice should have received the last prize.");

        // Make sure there are no prizes remaining.
        (allPrizes, amounts) = master.getActivePrizes();
        assertEq(allPrizes.length, 0, "There should be no prizes left.");
        assertEq(amounts.length, 0, "There should be no prizes left.");
        assertEq(WETH.balanceOf(address(master)), 0, "Puzzle master should have no more WETH in it.");
    }
}
