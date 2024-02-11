# 🐬 PORPOISE Network Oracle Contracts

This is the first stab at an implementation of a very simple oracle contract intended to be used within the PORPOISE Network. Simplicity and flexibility is
a top priority at this stage of development. 

A PORPOISE oracle contract's job is merely to allow someone who has posted a prediction survey to record the final event result on chain. Once the final state of 
the event relevant to a survey has been recorded on the blockchain, other smart contracts can leverage that state for custome logic, such as release of bounty funds, 
calculation of participant accuracy, etc. 