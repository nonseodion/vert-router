pragma solidity 0.8.0;

interface IVertRouter {
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
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function stableCoins(address stableCoin) external view returns (bool);

    function updateDustTaker(address dustTaker) external;
    function updateStableCoins(address stableCoin) external;
    function sellToken(
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        uint deadline,
        address receiver
    ) external;
    function sellETH( 
        uint amountOutMin, 
        address[] calldata path, 
        uint deadline,
        address receiver
    ) external payable;
    function sellTokenSupportingFeeOnTransfer(
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        uint deadline,
        address receiver
    ) external;

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}