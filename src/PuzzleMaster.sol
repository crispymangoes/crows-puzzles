// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract PuzzleMaster is Ownable{

    bytes32 public root;

    mapping(bytes32 => uint256) public prizes;

    constructor(bytes32 _root) {
        root = _root;
    }

    error PuzzleMaster__InvalidProof(); 

    error PuzzleMaster__NoPrize();

    error PuzzleMaster__PrizeAlreadySet();

    function claimPrize(bytes32[] memory proof, bytes32 leaf, uint256 guess) external {
        if(!MerkleProof.verify(proof, root, leaf)) revert PuzzleMaster__InvalidProof();

        bytes32 prizeHash = keccak256(abi.encode(guess));
        uint256 prizeAmount = prizes[prizeHash];

        if(prizeAmount > 0){
            delete prizes[prizeHash];
            address payable winner = payable(msg.sender);
            winner.transfer(prizeAmount);
        }
        else revert PuzzleMaster__NoPrize();
    }

    function addPrize(bytes32 prizeHash) payable external onlyOwner{
        if(prizes[prizeHash] > 0) revert PuzzleMaster__PrizeAlreadySet();
        prizes[prizeHash] = msg.value;
    }

    function removePrize(bytes32 prizeHash) external onlyOwner{
        uint256 prizeAmount = prizes[prizeHash];
        delete prizes[prizeHash];
        payable(msg.sender).transfer(prizeAmount);
    }

    function changeRoot(bytes32 newRoot) external onlyOwner{
        root = newRoot;
    }

    function shutdown() external onlyOwner{
        selfdestruct(payable(msg.sender));
    }
}
