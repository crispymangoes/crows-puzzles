// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract PuzzleMaster is Ownable{
    using SafeERC20 for ERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public root;
    ERC20 immutable public prizeToken;
    
    EnumerableSet.Bytes32Set private activePrizes;
    mapping(bytes32 => uint256) public prizes;

    constructor(bytes32 _root, ERC20 _prizeToken) {
        root = _root;
        prizeToken = _prizeToken;
    }

    error PuzzleMaster__InvalidProof(); 

    error PuzzleMaster__NoPrize();

    error PuzzleMaster__PrizeAlreadySet();

    function claimPrize(bytes32[] memory proof, bytes32 leaf, string memory guess) external {
        // Skip merkle proof check if root is zero.
        if (leaf != keccak256(abi.encodePacked(msg.sender))) revert PuzzleMaster__InvalidProof();
        if(root != bytes32(0) && !MerkleProof.verify(proof, root, leaf)) revert PuzzleMaster__InvalidProof();

        bytes32 prizeHash = keccak256(abi.encode(guess));
        uint256 prizeAmount = prizes[prizeHash];

        if(prizeAmount > 0){
            delete prizes[prizeHash];
            activePrizes.remove(prizeHash);
            prizeToken.safeTransfer(msg.sender, prizeAmount);
        }
        else revert PuzzleMaster__NoPrize();
    }

    function addPrize(bytes32 prizeHash, uint256 prizeAmount) external onlyOwner{
        if(prizes[prizeHash] > 0) revert PuzzleMaster__PrizeAlreadySet();
        prizeToken.transferFrom(msg.sender, address(this), prizeAmount);
        prizes[prizeHash] = prizeAmount;
        activePrizes.add(prizeHash);
    }

    function removePrize(bytes32 prizeHash) external onlyOwner{
        uint256 prizeAmount = prizes[prizeHash];
        delete prizes[prizeHash];
        activePrizes.remove(prizeHash);
        prizeToken.safeTransfer(msg.sender, prizeAmount);
    }

    function changeRoot(bytes32 newRoot) external onlyOwner{
        root = newRoot;
    }

    function shutdown() external onlyOwner{
        prizeToken.safeTransfer(msg.sender, prizeToken.balanceOf(address(this)));
        selfdestruct(payable(msg.sender));
    }

    function getPrizeAmount(string memory guess) external view returns(uint256 prizeAmount){
        bytes32 prizeHash = keccak256(abi.encode(guess));
        prizeAmount = prizes[prizeHash];
    }

    function getHash(string memory guess) external pure returns(bytes32) {
        return keccak256(abi.encode(guess));
    }

    function getActivePrizes() external view returns(bytes32[] memory allPrizes, uint256[] memory amounts) {
        uint256 len = activePrizes.length();
        allPrizes = new bytes32[](len);
        amounts = new uint256[](len);
        for(uint256 i=0; i<len; i++) {
            bytes32 prizeHash = activePrizes.at(i);
            allPrizes[i] = prizeHash;
            amounts[i] = prizes[prizeHash];
        }
    }
}
