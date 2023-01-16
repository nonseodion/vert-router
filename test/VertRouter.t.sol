// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "../src/interfaces/IVertRouter.sol";
import "../src/VertRouter.sol";

contract VertRouterTest is Test {
    IVertRouter public router;
    address dummyAccount = 0xd8Ee094FeB76A51dFE00e08Fbb1206c8b4B54D8E;
    address dummyStable = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7;

    address pairBNB_BUSD;
    address pairCAKE_BUSD;
    address pairBABYDOGE_BUSD;

    uint dust = 1000000;

    event UpdateDustTaker(address dustTaker);
    event AddStableToken(address token, bool added);
    event Sell(
        address indexed seller, 
        address indexed tokenSold, 
        address indexed stableCoin, 
        uint amountTokenSold,
        uint amountStableCoin,
        address receiver
    );

    function setUp() public {
        router = new VertRouter(
            0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc,
            0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd,
            0xd8Ee094FeB76A51dFE00e08Fbb1206c8b4B54D8E
        );
    }

    // update state variables test
    function testUpdateDustTaker() public {
        router.updateDustTaker(dummyAccount);
        address dustTaker = address(
            uint160(uint256(vm.load(address(router), bytes32(uint256(1)))))
        );
        assertEq(dustTaker, dummyAccount);
    }

    function testCannotUpdateDustTaker() public {
        vm.prank(dummyAccount);
        vm.expectRevert();
        router.updateDustTaker(dummyAccount);
    }

    function testAddStableCoin() public {
        vm.expectEmit(false, false, false, true);
        emit AddStableToken(dummyStable, true);
        router.updateStableTokens(dummyStable);
        bool added = router.stableTokens(dummyStable);
        assertTrue(added);
    }

    function testRemoveStableCoin() public {
        router.updateStableTokens(dummyStable);
        vm.expectEmit(false, false, false, true);
        emit AddStableToken(dummyStable, false);
        router.updateStableTokens(dummyStable);
        bool added = router.stableTokens(dummyStable);
        assertTrue(!added);
    }

    function testCannotAddStableCoin() public {
        vm.prank(dummyAccount);
        vm.expectRevert();
        router.updateStableTokens(dummyStable);
    }

    // sell token tests
    function testSellToken() public {
        IPancakePair pair = dummyToken;
        (uint reserve0, uint reserve1, ) = pair.getReserves();
        (uint reserveIn, uint reserveOut) = pair.token0() == dummyStable ? (reserve1, reserve0) : (reserve0, reserve1);
        uint amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut) + dust;
        vm.deal(pairCAKE_BUSD, address(this), amountIn);
        router.sellToken(amountIn, amountOutMin, path, deadline, receiver);
        // do checks
    }

    function testCannotSellTokenForNonStable() public {}

    function testSellETH() public {}

    function testSellTokenSupportingFeeOnTransfer() public {}
}
