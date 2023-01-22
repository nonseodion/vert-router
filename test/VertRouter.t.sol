// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import { IVertRouter } from "../src/interfaces/IVertRouter.sol";
import { IPancakeRouter02 } from "../src/interfaces/IPancakeRouter.sol";
import { VertRouter, IPancakePair, IERC20 } from "../src/VertRouter.sol";

contract VertRouterTest is Test {
    IVertRouter public router;
    address dummyAccount = 0xd8Ee094FeB76A51dFE00e08Fbb1206c8b4B54D8E;
    address dummyStable = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7;
    address dustTaker;

    address pairWBNB_BUSD = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    address pairCAKE_BUSD = 0x804678fa97d91B974ec2af3c843270886528a9E6;
    address pairSAFEMOON_WBNB = 0x87D7fd8c446Cb5D3da3CA23f429e7b7504d1931C;
    address CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address SAFEMOON = 0x42981d0bfbAf196529376EE702F2a9Eb9092fcB5;
    address BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

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


    function setUp() public {
        router = new VertRouter(
            0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73,
            0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            0xea89F5643d6B7B1baDD9fdE9Df898BbF5fF86742
        );
        dustTaker = address(
            uint160(uint256(vm.load(address(router), bytes32(uint256(1)))))
        );
        router.updateStableCoins(BUSD);
        vm.makePersistent(address(router));

        bnb_smart_chain_fork = vm.createFork(vm.rpcUrl("bnb_smart_chain"), 25020139);
    }

    // update state variables test
    function testUpdateDustTaker() public {
        router.updateDustTaker(dummyAccount);
        dustTaker = address(
            uint160(uint256(vm.load(address(router), bytes32(uint256(1)))))
        );
        assertEq(dustTaker, dummyAccount, "testUpdateDustTaker: DustTaker not updated");
    }

    function testCannotUpdateDustTaker() public {
        vm.prank(dummyAccount);
        vm.expectRevert("Ownable: caller is not the owner");
        router.updateDustTaker(dummyAccount);
    }

    function testAddStableCoin() public {
        vm.expectEmit(true, true, true, true);
        emit AddStableCoin(dummyStable, true);
        router.updateStableCoins(dummyStable);
        bool added = router.stableCoins(dummyStable);
        assertTrue(added, "testAddStableCoin: StableCoin not updated");
    }

    function testRemoveStableCoin() public {
        router.updateStableCoins(dummyStable);
        vm.expectEmit(true, true, true, true);
        emit AddStableCoin(dummyStable, false);
        router.updateStableCoins(dummyStable);
        bool added = router.stableCoins(dummyStable);
        assertTrue(!added, "testRemoveStableCoin: Could not remove stablecoin");
    }

    function testCannotAddStableCoin() public {
        vm.prank(dummyAccount);
        vm.expectRevert("Ownable: caller is not the owner");
        router.updateStableCoins(dummyStable);
    }

    // sell token tests
    function testSellToken() public {
        vm.selectFork(bnb_smart_chain_fork);
        IERC20(CAKE).approve(address(router), type(uint256).max);

        uint amountOut = 20000e18;
        uint amountOutMin = amountOut;
        (uint reserve0, uint reserve1, ) = IPancakePair(pairCAKE_BUSD).getReserves();
        (uint reserveIn, uint reserveOut) = IPancakePair(pairCAKE_BUSD).token0() == dummyStable ? (reserve1, reserve0) : (reserve0, reserve1);
        uint amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut) + dust;
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

    function testCannotSellTokenForNonStable() public {
        vm.selectFork(bnb_smart_chain_fork);
        address[] memory pair = new address[](2);
        pair[0] = CAKE;
        pair[1] = SAFEMOON;
        vm.expectRevert("VertRouter: UNSUPPORTED_StableCoin");
        router.sellToken(1000, 1000, pair, block.timestamp + 1, dummyAccount);
    }

    function testSellETH() public {
        vm.selectFork(bnb_smart_chain_fork);

        uint amountOut = 20000e18;
        uint amountOutMin = amountOut;
        (uint reserve0, uint reserve1, ) = IPancakePair(pairWBNB_BUSD).getReserves();
        (uint reserveIn, uint reserveOut) = IPancakePair(pairWBNB_BUSD).token0() == dummyStable ? (reserve1, reserve0) : (reserve0, reserve1);
        uint amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut) + dust;
        deal(address(this), amountIn);
        vm.expectEmit(true, true, true, true);
        emit Sell(address(this), WBNB, BUSD, amountIn, amountOutMin, dummyAccount);
        address[] memory pair = new address[](2);
        pair[0] = WBNB;
        pair[1] = BUSD;
        uint oldDustTakerBalance = IERC20(BUSD).balanceOf(dustTaker);
        router.sellETH{value: amountIn}(amountOutMin, pair, block.timestamp + 1, dummyAccount);
        assertEq(IERC20(BUSD).balanceOf(dummyAccount), amountOutMin, "testSellToken: Stablecoin not sent to receiver");
        assertGt(IERC20(BUSD).balanceOf(dustTaker), oldDustTakerBalance, "testSellToken: Dust not sent to dustTaker");
    }

    function testSellTokenSupportingFeeOnTransfer() public {
        vm.selectFork(bnb_smart_chain_fork);
        IERC20(SAFEMOON).approve(address(router), type(uint256).max);

        // bought token from pancakeswap because foundry throws error with deal(SAFEMOON, address(this), amount)
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        deal(address(this), 1e18);
        address [] memory path_0 = new address[](2);
        path_0[0] = WBNB;
        path_0[1] = SAFEMOON;
        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1e18}(0, path_0, address(this), block.timestamp + 1);

        uint amountIn = IERC20(SAFEMOON).balanceOf(address(this));
        address[] memory path = new address[](3);
        path[0] = SAFEMOON;
        path[1] = WBNB;
        path[2] = BUSD;
        uint amountOut = router.getAmountsOut(amountIn, path)[2];
        uint amountOutMin = amountOut*900/1000;

        vm.expectEmit(true, true, true, true);
        emit Sell(address(this), SAFEMOON, BUSD, amountIn, amountOutMin, dummyAccount);

        uint oldDustTakerBalance = IERC20(BUSD).balanceOf(dustTaker);
        router.sellTokenSupportingFeeOnTransfer(amountIn, amountOutMin, path, block.timestamp + 1, dummyAccount);
        assertEq(IERC20(BUSD).balanceOf(dummyAccount), amountOutMin, "testSellToken: Stablecoin not sent to receiver");
        assertGt(IERC20(BUSD).balanceOf(dustTaker), oldDustTakerBalance, "testSellToken: Dust not sent to dustTaker");
    }
}
