# Merit Dutch auction

Stepped dutch auction in which buyers buy at the price of the time the transaction is mined.

## Deploy

- Copy .env.example to .env
- Fill in appropiate values
- Load in env variables ``source .env``
- Run script ``forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast --verify -vvvv

## Running tests

``forge test``