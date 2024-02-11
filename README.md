# 🐬 PORPOISE Network Oracle Contracts

This is the first stab at an implementation of a very simple oracle contract intended to be used within the PORPOISE Network. Simplicity and flexibility is
a top priority at this stage of development. 

A PORPOISE oracle contract's job is merely to allow someone who has posted a prediction survey to record the final event result on chain. Once the final state of 
the event relevant to a survey has been recorded on the blockchain, other smart contracts can leverage that state for custome logic, such as release of bounty funds, 
calculation of participant accuracy, etc. 

## Recording Results

The oracle contract is intended to be completely permissionless, anyone can write to it. However, event results are cataloged by the address with calls
`recordResult`. Hence, if bounties are offered for specific surveys, then those bounties can be tied the the result reported by a specific reporting address. 

Once an address has reported the result of a specific survey, its value cannot be changed later. 

## Reading Results

Results can be fetched by calling `getResultByReporter`. The address which reported the result of the survey is the primary key with the survey Merkle root being
the secondary key. 