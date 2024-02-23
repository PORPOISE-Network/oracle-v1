// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";


// Uncomment this line to use console.log
// import "hardhat/console.sol";

// @title PORPOISE Network Oracle V1
contract Porpacle {
    string[] public domains;

    // @dev helpful datastructure that records a survey root and when it times out
    // @dev timestamp should be UTC timestamp from new Date().getTime()
    mapping(bytes32 => uint256) public surveyTimeouts; 

    // @dev primary data structure for recording event outcomes with respect to specific surveys
    // @dev maps the address that reports the result to map of surveys and their results
    mapping(address => mapping(bytes32 => Result)) private results;

    // @dev event to record when a new survey has been registered and by whom
    event Registration(address indexed reporter, bytes32 indexed survey, uint256 expiration, uint when);

    // @dev event to record when the result of the survey outcome has been resolved and who resolved it
    event Resolution(address indexed reporter, bytes32 indexed survey, string outcome, uint when);

    struct Result {
        bytes32 outcome;
        uint256 when;
    }

    constructor() {
        domains.push("porpoise.network");
    }

    // @notice Anyone may call this method to register a survey and its deadline with the oracle contract.
    // @dev Surveys are indexed by the Merkle root of their components. The nodes are computed with sha256 (not keccak).
    // @param proof An array of sha256 hashes needed to prove the deadline belonging to the survey root hash.
    // @param survey Merkle Root of a prediction survey, MUST be computed with sha256 hash.
    // @param timeout An integer representing the UTC timestamp (in milliseconds) of when a prediction must be commited.
    function registerSurvey(bytes32[] memory proof, bytes32 survey, uint256 timeout) external {
        require(timeout > (block.timestamp + 1 hours)*1000, "Deadline must be at least 1 hour in the future");
        require(surveyTimeouts[survey] == 0, "Survey already registered");
        require(verify(proof, survey, sha256(abi.encodePacked(timeout))), "Incorrect timestamp for survey root");
        surveyTimeouts[survey] = timeout;
    }

    // @notice Anyone may call this method with the observed result of a survey. It does not bind participants or bounties to respecting this specific result.
    // @param proof An array of sha256 hashes needed to prove the outcome was a valid option of the survey.
    // @param survey The Merkle Root of a prediction survey, should be computed with sha256 hash.
    // @param outcome The sha256 hash of the text representing the outcome of a prediction survey. 
    function recordResult(bytes32[] memory proof, bytes32 survey, string memory outcome) external {
        require(surveyTimeouts[survey] > 0, "Survey has not been registered yet.");
        require(surveyTimeouts[survey] < block.timestamp*1000, "Response deadline has not passed yet.");
        require(results[msg.sender][survey].when == 0, "Result has already been recorded");

        bytes32 hashedOutcome = sha256(abi.encodePacked(outcome));
        require(verify(proof, survey, hashedOutcome), "Incompatible survey outcome.");
        results[msg.sender][survey] = Result(hashedOutcome, block.timestamp);
        emit Resolution(msg.sender, survey, outcome, block.timestamp);
    }

    // @notice This function is used for looking up reported results by reporter address
    // @param reporter the address which reported the result of the survey
    // @param survey the Merkle Root of the target survey
    function getResultByReporter(address reporter, bytes32 survey) external view returns (Result memory result) {
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

    // @dev This is a Merkle leaf verification method copied from OpenZeppelin but modified by be based on sha256 instead of keccak
    // @dev The reasoning behing using sha256 is so that hashes can computed directly with standard browser-native crypto APIs
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
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

    function dumbFunction(bytes32 node1, uint256 time) external pure returns (bytes32) {
        bytes32 hashedTime = sha256(abi.encodePacked(time));
        console.logBytes(abi.encodePacked(hashedTime));
        console.logBytes(abi.encodePacked(node1));
        return sha256(abi.encodePacked(node1, hashedTime));
    }
}
