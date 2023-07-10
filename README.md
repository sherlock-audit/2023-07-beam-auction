
# Beam contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Eth Mainnet
___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
None
___

### Q: Which ERC721 tokens do you expect will interact with the smart contracts? 
Merit NFT contract specifically deployed for this purpose
___

### Q: Which ERC777 tokens do you expect will interact with the smart contracts? 
None
___

### Q: Are there any FEE-ON-TRANSFER tokens interacting with the smart contracts?

No
___

### Q: Are there any REBASING tokens interacting with the smart contracts?

No
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED?
Owner of Auction contract
URI setter of NFT contract
___

### Q: Is the admin/owner of the protocol/contracts TRUSTED or RESTRICTED?
Restricted
___

### Q: Are there any additional protocol roles? If yes, please explain in detail:
NFT: URI_SETTER can set the URI
NFT: MINTER can mint the NFT

Auction: Owner: Can pull the proceeds and set the NFT contract once
___

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?
The NFT contract complies with ERC721
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
/
___

### Q: Please provide links to previous audits (if any).
/
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?
no
___

### Q: In case of external protocol integrations, are the risks of external contracts pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.
Yes
___

### Q: Do you expect to use any of the following tokens with non-standard behaviour with the smart contracts?
NO
___

### Q: Add links to relevant protocol resources
/
___



# Audit scope

