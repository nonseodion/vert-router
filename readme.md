# Vert Finance Smart Contracts

## Welcome
Hi thanks for taking a look at the Vert Finance Smart Contracts. Vert Finance is a web-baseed decentralized application that let's you convert almost any cryptocurrency to fiat in your bank account. It's currently built to support only cryptocurrency to the Nigerian Naira conversions. Checkout this piece to find out more about Vert Finance.

This is the Smart Contract Repo. You can also have a look at the frontend and backend repos.

### [Frontend](https://github.com/nonseodion/vert-ui)
### [Backend](https://github.com/nonseodion/vert-backend)

## Architecture

The architecture above shows how the Vert Router sells a users token for stablecoin. Vert Router takes any token from the user and swaps it a stablecoin which it sends to a receiver specified by the user. The Router swaps it to a stablecoin to ensure the amount receive maintains its value. This ensures Vert Finance does not lose money to cryptocurrency price flunctuations. Any address can be a receiver but the frontend passes a fixed receiver. The stablecoin must be sent to this receiver before the fiat equivalent can be sent to a users bank account.

## Contracts
There's only one contract.

### Router
The Router contract is a modification of Pancakeswap's Router contract. Its main function is to swap users tokens to a stablecoin and send to a receiver. 

#### Functions
| Function                                                                                                                       | Description                                                                                                                                 |
|--------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| sellETH( uint amountOutMin, address[] calldata path, uint deadline, address receiver )                                         | Exchanges ETH or the equivalent native currency of the chain it is deployed on to a stablecoin.                                             |
| sellToken(uint amountIn, uint amountOutMin, address[] calldata path, uint deadline, address receiver )                         | Exchanges any token to a stablecoin.                                                                                                        |
| sellTokenSupportingFeeOnTransfer( uint amountIn, uint amountOutMin, address[] calldata path, uint deadline, address receiver ) | Exchanges tokens with on transfer fees to a stablecoin.                                                                                     |
| getAmountIn( uint amountOut, uint reserveIn, uint reserveOut)                                                                  | Returns the token amount to swap to get `amountOut` from a pool.                                                                            |
| getAmountOut( uint amountIn, uint reserveIn, uint reserveOut)                                                                  | Returns the token amount gotten if `amountIn` is swapped on a pool.                                                                         |
| getAmountsOut( uint amountIn, address[] memory path )                                                                          | Returns an array of intermediate token amounts when `amountIn` is swapped along `path`. The last element is the token amount gotten.        |
| getAmountsIn( uint amountOut, address[] memory path )                                                                          | Returns an array of intermediate token amounts needed to get `amountOut` after a swap. The first element is the inital token amount needed. |            |

## Addresses

| Chain          | Addresses                                  |
|----------------|--------------------------------------------|
| BNB SmartChain | [0x0a055140c146bf8aaca189c65d8572ee18dd7e0](https://bscscan.com/address/0x0a055140c146bf8aaca189c65d8572ee18dd7e01) |
| BNB Testnet    | [0x74ad3f1C96E23456B8e6c9D7d7F67d1169949b5B](https://bscscan.com/address/0x74ad3f1C96E23456B8e6c9D7d7F67d1169949b5B) |
