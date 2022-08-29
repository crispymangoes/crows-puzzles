// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PuzzleMaster is Ownable{
    using SafeERC20 for ERC20;

    bytes32 public root;
    ERC20 immutable public prizeToken;

    mapping(bytes32 => uint256) public prizes;

    constructor(bytes32 _root, ERC20 _prizeToken) {
        root = _root;
        prizeToken = _prizeToken;
    }

    error PuzzleMaster__InvalidProof(); 

    error PuzzleMaster__NoPrize();

    error PuzzleMaster__PrizeAlreadySet();

    function claimPrize(bytes32[] memory proof, bytes32 leaf, uint256 guess) external {
        // Skip merkle proof check if root is zero.
        if(root != bytes32(0) && !MerkleProof.verify(proof, root, leaf)) revert PuzzleMaster__InvalidProof();

        bytes32 prizeHash = keccak256(abi.encode(guess));
        uint256 prizeAmount = prizes[prizeHash];

        if(prizeAmount > 0){
            delete prizes[prizeHash];
            prizeToken.transfer(msg.sender, prizeAmount);
        }
        else revert PuzzleMaster__NoPrize();
    }

    function addPrize(bytes32 prizeHash, uint256 prizeAmount) external onlyOwner{
        if(prizes[prizeHash] > 0) revert PuzzleMaster__PrizeAlreadySet();
        prizeToken.transferFrom(msg.sender, address(this), prizeAmount);
        prizes[prizeHash] = prizeAmount;
    }

    function removePrize(bytes32 prizeHash) external onlyOwner{
        uint256 prizeAmount = prizes[prizeHash];
        delete prizes[prizeHash];
        prizeToken.transferFrom(address(this), msg.sender, prizeAmount);
    }

    function changeRoot(bytes32 newRoot) external onlyOwner{
        root = newRoot;
    }

    function shutdown() external onlyOwner{
        prizeToken.transferFrom(address(this), msg.sender, prizeToken.balanceOf(address(this)));
        selfdestruct(payable(msg.sender));
    }

    function getPrizeAmount(uint256 guess) external view returns(uint256 prizeAmount){
        bytes32 prizeHash = keccak256(abi.encode(guess));
        prizeAmount = prizes[prizeHash];
    }

    function getHash(uint256 guess) external pure returns(bytes32) {
        return keccak256(abi.encode(guess));
    }
}
