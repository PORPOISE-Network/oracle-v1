// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";


// Uncomment this line to use console.log
// import "hardhat/console.sol";

// @title PORPOISE Network Oracle V1
contract Porpacle {
    string[] public domains;

    // @dev primary data structure for recording event outcomes with respect to specific surveys
    // @dev maps the address that reports the result to map of surveys and their results
    mapping(address => mapping(uint256 => Result)) results;

    event Resolution(address reporter, uint256 survey, uint256 outcome, uint when);

    struct Result {
        uint256 outcome;
        uint when;
    }

    constructor() {
        domains.push("porpoise.network");
    }

    // @notice This is the primary function of the oracle contract. Anyone may call this method with the observed result of a survey.
    // @dev surveys are indexed by the Merkle root of their components, outcomes are indicated by the sha256 hash of their text
    // @param survey the Merkle Root of a prediction survey, should be computed with sha256 hash
    // @param outcome the sha256 hash of the text representing the outcome of a prediction survey 
    // TODO: implement logic to insure that the reported outcome is included in the merkle root of the survey (i.e. that it is a valid reported outcome)
    // TODO: additionally, the logic should also check that msg.sender is the stated oracle address in the prediction survey
    function recordResult(uint256 survey, uint256 outcome) external {
        require(results[msg.sender][survey].when == 0, "Result has already been recorded");
        results[msg.sender][survey] = Result(outcome, block.timestamp);
        emit Resolution(msg.sender, survey, outcome, block.timestamp);
    }

    // @notice This function is used for looking up reported results by reporter address
    // @param reporter the address which reported the result of the survey
    // @param survey the Merkle Root of the target survey
    function getResultByReporter(address reporter, uint256 survey) external view returns (Result memory result) {
        return results[reporter][survey];
    }

    function addDomain(
      string memory domain
    ) external pure {
        revert("Domains cannot be added or removed in testnet");
    }

    function removeDomain(
      string memory domain
    ) external pure {
        revert("Domains cannot be added or removed in testnet");
    }

    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) external pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? sha256(abi.encodePacked(a, b)) : sha256(abi.encodePacked(b, a));
    }

    function dumbFunction(bytes32 dummy) external pure returns (bytes32) {
        console.logBytes(abi.encodePacked(dummy));
        return sha256(abi.encodePacked(dummy));
    }
}
