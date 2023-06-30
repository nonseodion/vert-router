pragma solidity 0.8.0;

import 'openzeppelin-contracts/contracts/access/Ownable.sol'; 
import './interfaces/IVertRouter.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import './libraries/PancakeLibrary.sol';
import './libraries/TransferHelper.sol';

contract VertRouter is Ownable, IVertRouter {
    address public immutable override factory;
    address public immutable override WETH;
    address dustTaker;
    mapping (address => bool) public override stableCoins; 

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'VertRouter: EXPIRED');
        _;
    }

    modifier onlyStable(address stableCoin) {
        require(stableCoins[stableCoin], "VertRouter: UNSUPPORTED_StableCoin");
        _;
    }

    constructor(address _factory, address _WETH, address _dustTaker) {
        factory = _factory;
        WETH = _WETH;
        dustTaker = _dustTaker;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function updateDustTaker(address newDustTaker) onlyOwner external override{
        require(newDustTaker != address(0));
        dustTaker = newDustTaker;
        emit UpdateDustTaker(newDustTaker);
    }

    function updateStableCoins(address stableCoin) onlyOwner external override{
        bool add = !stableCoins[stableCoin];
        stableCoins[stableCoin] = add;
        emit AddStableCoin(stableCoin, add);
    }

    function _settle(address token, address receiver, uint settlement) internal{
        TransferHelper.safeTransfer(token, receiver, settlement);
        uint balance = IERC20(token).balanceOf(address(this));
        if(balance > 0){
            TransferHelper.safeTransfer(token, dustTaker, balance);
        }
    }

    function sellToken(
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        uint deadline,
        address receiver
    ) external override onlyStable(path[path.length-1]) 
    {
        _swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);
        _settle(path[path.length-1], receiver, amountOutMin);
        emit Sell(msg.sender, path[0], path[path.length-1], amountIn, amountOutMin, receiver);
    }

    function sellETH( 
        uint amountOutMin,
        address[] calldata path, 
        uint deadline,
        address receiver
    ) external override payable onlyStable(path[path.length-1]) 
    {
        _swapExactETHForTokens(amountOutMin, path, address(this), deadline);
        _settle(path[path.length-1], receiver, amountOutMin);
        emit Sell(msg.sender, path[0], path[path.length-1], msg.value, amountOutMin, receiver);
    }

    function sellTokenSupportingFeeOnTransfer(
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        uint deadline,
        address receiver
    ) external override onlyStable(path[path.length-1]) 
    {
        _swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, address(this), deadline);
        _settle(path[path.length-1], receiver, amountOutMin);
        emit Sell(msg.sender, path[0], path[path.length-1], amountIn, amountOutMin, receiver);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? PancakeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IPancakePair(PancakeLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function _swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )  internal ensure(deadline) returns (uint[] memory amounts) {
        amounts = PancakeLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'VertRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function _swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        internal
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'VertRouter: INVALID_PATH');
        amounts = PancakeLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'VertRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function _swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        internal
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'VertRouter: INVALID_PATH');
        amounts = PancakeLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'VertRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeLibrary.sortTokens(input, output);
            IPancakePair pair = IPancakePair(PancakeLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
            amountOutput = PancakeLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? PancakeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function _swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) internal ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            'VertRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return PancakeLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return PancakeLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return PancakeLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return PancakeLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return PancakeLibrary.getAmountsIn(factory, amountOut, path);
    }
}