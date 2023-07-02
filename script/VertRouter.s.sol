// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Script.sol";
import { Addresses } from "../data/addresses.sol";
import { VertRouter } from "../src/VertRouter.sol";

contract VertRouterScript is Addresses, Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // broadcasted transactions
        VertRouter router = new VertRouter(
            Addresses.pancakeswapFactory,
            Addresses.WBNB,
            Addresses.dustTaker
        );
        router.updateStableCoins(Addresses.BUSD);

        vm.stopBroadcast();
    }
}
