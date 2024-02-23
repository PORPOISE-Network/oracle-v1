# 🐬 PORPOISE Network Oracle Contracts

This is the first stab at an implementation of a very simple oracle contract intended to be used within the PORPOISE Network. Simplicity and flexibility is
a top priority at this stage of development. 

A PORPOISE oracle contract's job is merely to allow someone who has posted a prediction survey to record the final event result on chain. Once the final state of 
the event relevant to a survey has been recorded on the blockchain, other smart contracts can leverage that state for custome logic, such as release of bounty funds, 
calculation of participant accuracy, etc. 

## Registering a Survey

A survey must be registered with the oracle at least `1` hour before the prediction deadline (⏰). Surveys are indexed by the Merkle Root of their components 
as described in the [whitepaper](https://info.porpoise.network/whitepaper/survey-commitment-protocol), and one of the leaves of the associated Merkle Tree is 
the survey deadline. 

To register a survey, call the [`registerSurvey`](/contracts/Porpacle.sol#L42) method with an inclusion proof of the deadline timestamp, the survey root itself, and the UTC deadline timestamp. Survey deadlines can be looked up by calling the public member variable, [`surveyTimeouts`](/contracts/Porpacle.sol#L16). Once a survey is registered, external contracts may reference it, its deadline, and verify results. 

## Recording Results

The oracle contract is intended to be completely permissionless, anyone can write to it. However, event results are cataloged by the address which calls
[`recordResult`](/contracts/Porpacle.sol#L53). Hence, if bounties are offered for specific surveys, then those bounties can be tied the the result reported by a specific reporting address. 

When recording the result of a prediction survey, the caller must provide a Merkle proof with their reported value to prove they are submitting a valid option (i.e. an 
option specified with a 🗳️). 

**NOTE**: Once an address has reported the result of a specific survey, its value cannot be changed later. 

## Reading Results

Results can be fetched by calling [`getResultByReporter`](/contracts/Porpacle.sol#L67). The address which reported the result of the survey is the primary key 
with the survey Merkle root being the secondary key. 

## EVM Events

There are two event types in the PORPOISE Network oracle:

1. `Registration`: emits a log of a new survey root, who registered it, its response deadline (in UTC milliseconds), and the block timestamp when the survey was registered.
2. `Resolution`: emits a log of a survey root, who recorded it, the outcome string, and the block timestamp of when the result was recorded. 