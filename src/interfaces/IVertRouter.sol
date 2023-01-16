pragma solidity 0.8.0;

interface IVertRouter {
    event UpdateFeeTaker(address feeTaker);
    event AddStableToken(address token, bool added);
    event Sell(
        address indexed seller, 
        address indexed tokenSold, 
        address indexed stableCoin, 
        uint amountTokenSold,
        uint amountStableCoin
    );
    function factory() external view returns (address);
    function WETH() external view returns (address);

    

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}