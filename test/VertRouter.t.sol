// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import { IVertRouter } from "../src/interfaces/IVertRouter.sol";
import { VertRouter, IPancakePair, IERC20 } from "../src/VertRouter.sol";

contract VertRouterTest is Test {
    IVertRouter public router;
    address dummyAccount = 0xd8Ee094FeB76A51dFE00e08Fbb1206c8b4B54D8E;
    address dummyStable = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7;
    address dustTaker;

    address pairWBNB_BUSD = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    address pairCAKE_BUSD = 0x804678fa97d91B974ec2af3c843270886528a9E6;
    address pairBABYDOGE_BUSD = 0xc736cA3d9b1E90Af4230BD8F9626528B3D4e0Ee0;
    address CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address BABYDOGE = 0xc748673057861a797275CD8A068AbB95A902e8de;
    address BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    //forks
    uint bnb_smart_chain_fork;

    uint dust = 1000000;

    event UpdateDustTaker(address dustTaker);
    event AddStableCoin(address token, bool added);
    event Sell(
        address indexed seller, 
        address indexed tokenSold, 
        address indexed stableCoin, 
        uint amountTokenSold,
        uint amountStableCoin,
        address receiver
    );

    function deployAndSetup() internal {
        router = new VertRouter(
            0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73,
            0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            0xea89F5643d6B7B1baDD9fdE9Df898BbF5fF86742
        );

        dustTaker = address(
            uint160(uint256(vm.load(address(router), bytes32(uint256(1)))))
        );
        router.updateStableCoins(BUSD);
    }

    function setUp() public {
        deployAndSetup();
        bnb_smart_chain_fork = vm.createFork(vm.rpcUrl("bnb_smart_chain"));
    }

    // update state variables test
    function xtestUpdateDustTaker() public {
        router.updateDustTaker(dummyAccount);
        assertEq(dustTaker, dummyAccount, "testUpdateDustTaker: DustTaker not updated");
    }

    function xtestCannotUpdateDustTaker() public {
        vm.prank(dummyAccount);
        vm.expectRevert("Ownable: caller is not the owner");
        router.updateDustTaker(dummyAccount);
    }

    function xtestAddStableCoin() public {
        vm.expectEmit(true, true, true, true);
        emit AddStableCoin(dummyStable, true);
        router.updateStableCoins(dummyStable);
        bool added = router.stableCoins(dummyStable);
        assertTrue(added, "testAddStableCoin: StableCoin not updated");
    }

    function xtestRemoveStableCoin() public {
        router.updateStableCoins(dummyStable);
        vm.expectEmit(true, true, true, true);
        emit AddStableCoin(dummyStable, false);
        router.updateStableCoins(dummyStable);
        bool added = router.stableCoins(dummyStable);
        assertTrue(!added, "testRemoveStableCoin: Could not remove stablecoin");
    }

    function xtestCannotAddStableCoin() public {
        vm.prank(dummyAccount);
        vm.expectRevert("Ownable: caller is not the owner");
        router.updateStableCoins(dummyStable);
    }

    // sell token tests
    function testSellToken() public {
        vm.selectFork(bnb_smart_chain_fork);
        deployAndSetup();
        IERC20(CAKE).approve(address(router), type(uint256).max);

        uint amountOut = 20000e18;
        uint amountOutMin = amountOut;
        (uint reserve0, uint reserve1, ) = IPancakePair(pairCAKE_BUSD).getReserves();
        (uint reserveIn, uint reserveOut) = IPancakePair(pairCAKE_BUSD).token0() == dummyStable ? (reserve1, reserve0) : (reserve0, reserve1);
        uint amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut) + dust;
        amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
        deal(CAKE, address(this), amountIn, true);
        vm.expectEmit(true, true, true, true);
        emit Sell(address(this), CAKE, BUSD, amountIn, amountOutMin, dummyAccount);
        address[] memory pair = new address[](2);
        pair[0] = CAKE;
        pair[1] = BUSD;
        uint oldDustTakerBalance = IERC20(BUSD).balanceOf(dustTaker);
        router.sellToken(amountIn, amountOutMin, pair, block.timestamp + 1, dummyAccount);
        assertEq(IERC20(BUSD).balanceOf(dummyAccount), amountOutMin, "testSellToken: Stablecoin not sent to receiver");
        assertGt(IERC20(BUSD).balanceOf(dustTaker), oldDustTakerBalance, "testSellToken: Dust not sent to dustTaker");
    }

    function xtestCannotSellTokenForNonStable() public {
        vm.selectFork(bnb_smart_chain_fork);
        deployAndSetup();
        address[] memory pair = new address[](2);
        pair[0] = CAKE;
        pair[1] = BABYDOGE;
        vm.expectRevert("VertRouter: UNSUPPORTED_STABLeCoin");
        router.sellToken(1000, 1000, pair, block.timestamp + 1, dummyAccount);
    }

    function xtestSellETH() public {

    }

    function xtestSellTokenSupportingFeeOnTransfer() public {}
}
