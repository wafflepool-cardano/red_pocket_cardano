Website flow:

- User locks in asset(s) that they want to give in smart contract.
- User can choose to either mint NFT in their wallet, or have the minted NFT sent to an address of their choice.
    - Preferably will also integrate ADA handles (TBC)
- Assets are sent to smart contract, and NFT is minted.
    - Asset will sit on UTxO with script address, with a datum indicating which asset can unlock it.
    - This will depend on a system of counter, where an oracle keeps track of how many red pockets have been minted, and assigns a unique counter to each red pocket.
- User or address of their choice receive Red Pocket NFT with art.
    - Although the Red Pocket art will look identical for everyone, they will each have a unique PolicyId.
    - Hope to have a special art work if SNEK is minted (TBC)
- Oracle will update each time a new red pocket is minted
- Apart from counter, there is another variable in oracle and script datum that indicates the year of the red pocket (ie Snake, Horse etc...)
