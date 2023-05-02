// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title VerminCoin
 * @author piddlywinks
 * @notice This contract helps elect our benevolent overlord, Vermin Supreme to World President
 * @dev Use this contract to manufacture ponies
 * @custom:dev-run-script scripts/VerminCoin_test.sol
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/pancakeswap/pancake-swap-periphery/master/contracts/interfaces/IPancakeRouter01.sol";
import "https://raw.githubusercontent.com/pancakeswap/pancake-swap-periphery/master/contracts/interfaces/IPancakeRouter02.sol";

contract VerminCoin is IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

	bool private inAddLiquidity;

    address public busdTokenAddress;
	IERC20 private busdToken;

	function getBusdToken() public view returns (address) {
		return address(busdToken);
	}



    uint256 public transactionTaxPercent = 12;
    uint256 public reflectionTaxPercent = 5;
    uint256 public liquidityTaxPercent = 3;
    uint256 public marketingTaxPercent = 2;
    uint256 public ponyTaxPercent = 2;

    address public marketingAddress;
    address public ponyAddress;

    // other required variables will be declared here

	 // PancakeSwap Router
    IPancakeRouter02 private constant PANCAKE_ROUTER = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    constructor(
        address _busdTokenAddress,
        address _marketingAddress,
        address _ponyAddress
    ) {
        _name = "VerminCoin";
        _symbol = "VERM";
        _decimals = 18;
        _totalSupply = 1_000_000_000 * 10**18;

        busdTokenAddress = _busdTokenAddress;
        busdToken = IERC20(busdTokenAddress);

        marketingAddress = _marketingAddress;
        ponyAddress = _ponyAddress;

        // initial supply allocation
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // Part 2 - ERC20 functions and utility functions

	// ERC20 functions
	function name() public view override returns (string memory) {
	    return _name;
	}

	function symbol() public view override returns (string memory) {
	    return _symbol;
	}

	function decimals() public view override returns (uint8) {
	    return _decimals;
	}

	function totalSupply() public view override returns (uint256) {
	    return _totalSupply;
	}

	function balanceOf(address account) public view override returns (uint256) {
	    return _balances[account];
	}

	function transfer(address recipient, uint256 amount) public override returns (bool) {
	    _transfer(msg.sender, recipient, amount);
	    return true;
	}

	function allowance(address owner, address spender) public view override returns (uint256) {
	    return _allowances[owner][spender];
	}

	function approve(address spender, uint256 amount) public override returns (bool) {
	    _approve(msg.sender, spender, amount);
	    return true;
	}

	function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
	    _transfer(sender, recipient, amount);
	    _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
	    return true;
	}

	function _approve(address owner, address spender, uint256 amount) internal {
	    require(owner != address(0), "ERC20: approve from the zero address");
	    require(spender != address(0), "ERC20: approve to the zero address");

	    _allowances[owner][spender] = amount;
	    emit Approval(owner, spender, amount);
	}

	// Part 3 - Tokenomics logic and additional functions

	// Additional state variables for reflections
	mapping(address => uint256) private _busdReflections;
	uint256 private _totalBusdReflections;

	// Utility functions
	function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, "ERC20: transfer amount must be greater than zero");

    // Check if inAddLiquidity is false, sender and recipient are not the contract address, and sender is not the owner
    if (!inAddLiquidity && sender != address(this) && recipient != address(this) && (sender != address(PANCAKE_ROUTER) || recipient != address(PANCAKE_ROUTER))) {
        uint256 taxAmount = amount.mul(transactionTaxPercent).div(100);
        uint256 reflectionAmount = taxAmount.mul(reflectionTaxPercent).div(transactionTaxPercent);
        uint256 liquidityAmount = taxAmount.mul(liquidityTaxPercent).div(transactionTaxPercent);
        uint256 marketingAmount = taxAmount.mul(marketingTaxPercent).div(transactionTaxPercent);
        uint256 ponyAmount = taxAmount.mul(ponyTaxPercent).div(transactionTaxPercent);

        // Update balances and send taxes
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount.sub(taxAmount));

        _distributeReflections(sender, reflectionAmount);
        _transferToMarketing(marketingAmount);
        _transferToPony(ponyAmount);

        // Add liquidity
        _addLiquidity(sender, liquidityAmount);

        emit Transfer(sender, recipient, amount.sub(taxAmount));
    } else {
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }
}


	function _transferWithoutFees(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, "ERC20: transfer amount must be greater than zero");

    _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);

    emit Transfer(sender, recipient, amount);
}

	function _distributeReflections(address sender, uint256 reflectionAmount) internal {
		// Calculate sender's BUSD reflection share
		uint256 senderShare = _balances[sender].mul(_totalBusdReflections).div(totalSupply());
		uint256 senderReflection = _busdReflections[sender].add(senderShare);

		// Update the total BUSD reflections and sender's reflection balance
		_totalBusdReflections = _totalBusdReflections.add(reflectionAmount);
		_busdReflections[sender] = senderReflection.sub(senderShare);

		// Calculate and distribute the BUSD reflections to the sender
		uint256 senderBusdRewards = _balances[sender].mul(senderReflection).div(totalSupply());
		if (senderBusdRewards > 0) {
			busdToken.transfer(sender, senderBusdRewards);
		}
	}

	function _addLiquidity(address sender, uint256 liquidityAmount) internal {
		inAddLiquidity = true;
		// Swap half of the liquidity tokens for BUSD
		uint256 half = liquidityAmount.div(2);
		uint256 otherHalf = liquidityAmount.sub(half);
		uint256 initialBalance = busdToken.balanceOf(address(this));

		_swapTokensForBusd(half);

		// Calculate the amount of BUSD received after swapping
		uint256 swappedBusdAmount = busdToken.balanceOf(address(this)).sub(initialBalance);

		// Approve PancakeSwap Router to spend VerminCoin and BUSD tokens
		_approve(address(this), address(PANCAKE_ROUTER), otherHalf);
		busdToken.approve(address(PANCAKE_ROUTER), swappedBusdAmount);

		// Transfer VerminCoin tokens to the PancakeSwap Router without fees
		_transferWithoutFees(sender, address(PANCAKE_ROUTER), otherHalf);

		// Add the liquidity
		PANCAKE_ROUTER.addLiquidity(
			address(this),
			address(busdToken),
			otherHalf,
			swappedBusdAmount,
			0, // slippage is unavoidable
			0, // slippage is unavoidable
			sender,
			block.timestamp
		);
		// Reset the inAddLiquidity variable
    	inAddLiquidity = false;
}

	function _swapTokensForBusd(uint256 tokenAmount) internal {
        // Generate the PancakeSwap pair path of VerminCoin -> BUSD
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(busdToken);

        // Make the swap
        _approve(address(this), address(PANCAKE_ROUTER), tokenAmount);
        PANCAKE_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BUSD
            path,
            address(this),
            block.timestamp
        );
    }

	function _transferToMarketing(uint256 marketingAmount) internal {
		_balances[address(this)] = _balances[address(this)].add(marketingAmount);
		busdToken.transfer(marketingAddress, marketingAmount);
	}

	function _transferToPony(uint256 ponyAmount) internal {
		_balances[address(this)] = _balances[address(this)].add(ponyAmount);
		busdToken.transfer(ponyAddress, ponyAmount);
	}

}
