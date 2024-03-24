// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

// @title PORPOISE Network Oracle V1
contract Porpacle {
    /// @notice Optional event emitted when a domain is added
    /// @param domain eTLD+1 associated with the contract
    event AddDomain(string domain);

    /// @notice Optional event emitted when a domain is removed
    /// @param domain eTLD+1 that is no longer associated with the contract
    event RemoveDomain(string domain);

    /// @notice event to record when a new survey has been registered and by whom
    /// @param reporter the address which has registered the survey with the oracle contract
    /// @param survey the merkle root of the survey whose resolution is being recorded
    /// @param expiration the timestamp when prediction are nolonger accepted
    /// @param when the timestamp of when the survey was registered on-chain
    event Registration(
        address indexed reporter,
        bytes32 indexed survey,
        uint256 expiration,
        uint256 when
    );

    /// @notice event to record when the result of the survey outcome has been resolved and who resolved it
    /// @param reporter the address which as registered a valid outcome for a registered survey
    /// @param survey the merkle root of the target survey
    /// @param outcome the option which has be chosen as the outcome by the reporter address
    /// @param when the timestamp of when the resolution was recorded on-chain
    event Resolution(
        address indexed reporter,
        bytes32 indexed survey,
        string outcome,
        uint when
    );

    /// @notice event to record when a user has revealed a previously committed prediction
    /// @param user the address of the user revealing their prediction
    /// @param survey the survey root for which the user has made a prediction
    /// @param selection the sha256 hash of the selected outcome
    /// @param when the timestamp when the user made the original prediction commitment
    event Reveal(
        address indexed user,
        bytes32 indexed survey,
        bytes32 indexed selection,
        uint when
    );

    struct Result {
        bytes32 outcome;
        uint256 when;
    }

    struct Commitment {
        bytes32 prediction; // sha256(salt + selection + survey root)
        uint256 when;
        string salt;
        bytes32 selection; // sha256(selection)
    }

    /// @dev a mapping from the keccak256 hash of eTLD+1 domains associated with this contract to a boolean
    mapping(bytes32 => bool) domains;

    /// @dev helpful datastructure that records a survey root and when it times out
    /// @dev timestamp should be UTC timestamp from new Date().getTime()
    mapping(bytes32 => uint256) public surveyTimeouts;

    /// @dev primary data structure for recording event outcomes with respect to specific surveys
    /// @dev maps the address that reports the result to map of surveys and their results
    mapping(address => mapping(bytes32 => Result)) private results;

    /// @dev storage variable for user prediction commitments
    /// @dev outer mapping maps from user address to inner mapping which maps from a survey root to a commitment
    mapping(address => mapping(bytes32 => Commitment)) private commitments;

    constructor() {
        domains[keccak256(abi.encodePacked("porpoise.network"))] = true;
    }

    /// @notice Anyone may call this method to register a survey and its deadline with the oracle contract.
    /// @dev Surveys are indexed by the Merkle root of their components. The nodes are computed with sha256 (not keccak).
    /// @param proof An array of sha256 hashes needed to prove the deadline belonging to the survey root hash.
    /// @param survey Merkle Root of a prediction survey, MUST be computed with sha256 hash.
    /// @param timeout An integer representing the UTC timestamp (in milliseconds) of when a prediction must be commited.
    function registerSurvey(
        bytes32[] calldata proof,
        bytes32 survey,
        uint256 timeout
    ) external {
        require(
            timeout > (block.timestamp + 1 hours) * 1000,
            "Deadline must be at least 1 hour in the future"
        );
        require(surveyTimeouts[survey] == 0, "Survey already registered");
        require(
            verify(proof, survey, sha256(abi.encodePacked(timeout))),
            "Incorrect timestamp for survey root"
        );
        surveyTimeouts[survey] = timeout;
        emit Registration(msg.sender, survey, timeout, block.timestamp);
    }

    /// @notice Anyone may call this method with the observed result of a survey. It does not bind participants or bounties to respecting this specific result.
    /// @param proof An array of sha256 hashes needed to prove the outcome was a valid option of the survey.
    /// @param survey The Merkle Root of a prediction survey, should be computed with sha256 hash.
    /// @param outcome Text string representing the outcome of a prediction survey.
    function recordResult(
        bytes32[] calldata proof,
        bytes32 survey,
        string calldata outcome
    ) external {
        require(
            surveyTimeouts[survey] > 0,
            "Survey has not been registered yet."
        );
        require(
            surveyTimeouts[survey] < block.timestamp * 1000,
            "Response deadline has not passed yet."
        );
        require(
            results[msg.sender][survey].when == 0,
            "Result has already been recorded"
        );

        bytes32 hashedOutcome = sha256(abi.encodePacked(outcome));
        require(
            verify(proof, survey, hashedOutcome),
            "Incompatible survey outcome."
        );
        results[msg.sender][survey] = Result(hashedOutcome, block.timestamp);
        emit Resolution(msg.sender, survey, outcome, block.timestamp);
    }

    /// @notice This function is called by a user account to establish a prediction for a survey before the survey deadline
    /// @dev prediction = sha256(salt + predicted outcome + survey root)
    /// @param survey the survey root that the user is making the prediction for
    /// @param prediction the survey commitment binding the user to a prediction without revealing their selection
    function makePrediction(bytes32 survey, bytes32 prediction) external {
        require(
            surveyTimeouts[survey] > 0,
            "Survey has not been registered yet."
        );
        require(
            surveyTimeouts[survey] > block.timestamp * 1000,
            "Survey deadline has passed."
        );
        commitments[msg.sender][survey] = Commitment(
            prediction,
            block.timestamp,
            "",
            bytes32(0)
        );
    }

    /// @notice this function is called by a user to reveal their selection from a previously committed prediciton
    /// @param proof a merkle proof that proves their selection is a valid selection for the target survey
    /// @param survey the merkle root of the target survey
    /// @param selection the text of the selection the user made in the existing prediction
    /// @param salt the salt value used when committing to the prediction
    function revealPrediction(
        bytes32[] calldata proof,
        bytes32 survey,
        string calldata selection,
        string calldata salt
    ) external {
        require(
            surveyTimeouts[survey] > 0,
            "Survey has not been registered yet."
        );
        require(
            surveyTimeouts[survey] < block.timestamp * 1000,
            "Response deadline has not passed yet."
        );

        bytes32 prediction = sha256(abi.encodePacked(salt, selection, survey));
        Commitment memory registeredCommitment = commitments[msg.sender][survey];
        require(
            registeredCommitment.when > 0,
            "Prediction was never committed prior to survey deadline."
        );
        require(
            registeredCommitment.prediction == prediction,
            "Reveal data does not match committed prediction."
        );

        bytes32 hashedSelection = sha256(abi.encodePacked(selection));
        require(
            verify(proof, survey, hashedSelection),
            "Incompatible survey selection."
        );
        commitments[msg.sender][survey] = Commitment(
            prediction,
            registeredCommitment.when,
            salt,
            hashedSelection
        );
        emit Reveal(msg.sender, survey, hashedSelection, registeredCommitment.when);
    }

    /// @notice This function is used for looking up reported results by reporter address
    /// @param reporter the address which reported the result of the survey
    /// @param survey the Merkle Root of the target survey
    function getResultByReporter(
        address reporter,
        bytes32 survey
    ) external view returns (Result memory) {
        return results[reporter][survey];
    }

    /// @notice This function is used for looking up commitments from users by their address
    /// @param user the address which has made a commitment
    /// @param survey the Merkle Root of the target survey
    function getCommitmentByAddress(
        address user,
        bytes32 survey
    ) external view returns (Commitment memory) {
        return commitments[user][survey];
    }

    /// @notice a getter function that takes an eTLD+1 domain string and returns true if associated with the contract
    /// @param domain a string representing an eTLD+1 domain
    function getDomain(string calldata domain) external view returns (bool) {
        return domains[keccak256(abi.encodePacked(domain))];
    }

    /// @notice an authenticated method to add an eTLD+1 domain
    /// @param domain a string representing an eTLD+1 domain associated with the contract
    function addDomain(string calldata domain) external {
        domains[keccak256(abi.encodePacked(domain))] = true;
        emit AddDomain(domain);
    }

    /// @notice an authenticated method to remove an eTLD+1 domain
    /// @param domain a string representing an eTLD+1 domain that is no longer associated with the contract
    function removeDomain(string calldata domain) external {
        require(
            domains[keccak256(abi.encodePacked(domain))] == true,
            "ERC7529: eTLD+1 currently not associated with this contract"
        );
        domains[keccak256(abi.encodePacked(domain))] = false;
        emit RemoveDomain(domain);
    }

    // @dev This is a Merkle leaf verification method copied from OpenZeppelin but modified by be based on sha256 instead of keccak
    // @dev The reasoning behing using sha256 is so that hashes can computed directly with standard browser-native crypto APIs
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    function processProof(
        bytes32[] memory proof,
        bytes32 leaf
    ) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return
            a < b
                ? sha256(abi.encodePacked(a, b))
                : sha256(abi.encodePacked(b, a));
    }

    function dumbFunction(
        bytes32 node1,
        uint256 time
    ) external pure returns (bytes32) {
        bytes32 hashedTime = sha256(abi.encodePacked(time));
        console.logBytes(abi.encodePacked(hashedTime));
        console.logBytes(abi.encodePacked(node1));
        return sha256(abi.encodePacked(node1, hashedTime));
    }
}
