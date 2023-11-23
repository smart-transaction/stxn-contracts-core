// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;
import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../test/examples/MyErc20.sol";
contract UniswapV2Model {
    mapping(address => uint) _reserve;
    
    constructor(
        address tokenA, address tokenB,
        uint reserveA, uint reserveB
    ) {
        _reserve[tokenA] = reserveA;
        _reserve[tokenB] = reserveB;
    }

    event Foo(uint);
    
    function getAmountsOut(uint amountIn, address[2] memory path)
        public
        returns (uint[2] memory amounts)
    {
        uint reserveIn = _reserve[path[0]];
        uint reserveOut = _reserve[path[1]];
        uint k = reserveIn * reserveOut;
        uint amountOut = reserveOut - k / (reserveIn + amountIn);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[2] calldata path,
        address to,
        uint deadline
    ) external returns (uint[2] memory amounts) {
        require(deadline >= block.timestamp, "past deadline");
        uint amountOut = getAmountsOut(amountIn, path)[1];
        emit Foo(3);
        require(amountOut >= amountOutMin, "insufficient output amount");
        emit Foo(2);
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        emit Foo(1);
        IERC20(path[1]).transfer(to, amountOut);
        emit Foo(0);
        amounts[0] = amountIn;
        emit Foo(5);
        amounts[1] = amountOut;
        emit Foo(6);
        _reserve[path[0]] += amountIn;
        _reserve[path[1]] -= amountOut;
    }
}
contract SandwichAttackTest is Test {
    address user;
    address attacker;
    MyErc20 tokenA;
    MyErc20 tokenB;
        
    function setUp() external {
        user = address(uint160(uint256(keccak256("user"))));
        attacker = address(uint160(uint256(keccak256("MEV attacker"))));
        vm.label(user, "user");
        vm.label(attacker, "attacker");
        tokenA = new MyErc20("Token A", "A");
        tokenB = new MyErc20("Token B", "B");
    }
    
    function testSandwichAttack_concrete() public {
      testSandwichAttack_symbolic(1000, 1000, 50, 40, 100);
     }

    function testSandwichAttack_concsymb_xy(uint64 x, uint64 y) public {
      testSandwichAttack_symbolic(x, y, 50, 40, 300);
    }

    function testSandwichAttack_concsymb_front(uint64 amountFrontRun) public {
      testSandwichAttack_symbolic(1000, 1000, 50, 40, amountFrontRun);
    }

    function testSandwichAttack_concsymb_front_slip(uint64 amountOutMin, uint64 amountFrontRun) public {
      testSandwichAttack_symbolic(1000, 1000, 50, amountOutMin, amountFrontRun);
    }

    function testSandwichAttack_symbolic(
        uint64 x, uint64 y,
        uint64 amountIn, uint64 amountOutMin,
        uint64 amountFrontRun
    ) public {
        vm.assume(x >= y);
        vm.assume(y > 100);
        UniswapV2Model uniswap = new UniswapV2Model(address(tokenA), address(tokenB), x, y);
        address[2] memory pathAToB = [address(tokenA), address(tokenB)];
        address[2] memory pathBToA = [address(tokenB), address(tokenA)];
        tokenA.mint(user, amountIn);
        tokenA.mint(attacker, amountFrontRun);
        tokenA.mint(address(uniswap), x);
        tokenB.mint(address(uniswap), y);
        // MEV attacker swaps token A for B
        vm.startPrank(attacker);
        IERC20(tokenA).approve(address(uniswap), amountFrontRun);
        uint amountBOutMin = uniswap.getAmountsOut(amountFrontRun, pathAToB)[1];
        uint amountBOut = uniswap.swapExactTokensForTokens(
            amountFrontRun, amountBOutMin, pathAToB, attacker, block.timestamp)[1];
        vm.stopPrank();
        // User swaps token A for B
        vm.startPrank(user);
        IERC20(tokenA).approve(address(uniswap), amountIn);
        uniswap.swapExactTokensForTokens(
            amountIn, amountOutMin, pathAToB, user, block.timestamp)[1];
        vm.stopPrank();
        // MEV attacker swaps token B back for A
        vm.startPrank(attacker);
        IERC20(tokenB).approve(address(uniswap), amountBOut);
        uint amountAOutMin = uniswap.getAmountsOut(amountBOut, pathBToA)[1];
        uint amountAOut = uniswap.swapExactTokensForTokens(
            amountBOut, amountAOutMin, pathBToA, attacker, block.timestamp)[1];
        vm.stopPrank();
        assertGt(amountAOut, amountFrontRun);
    }
}
