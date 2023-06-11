// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VerminCoin is ERC20, Ownable {
    address public constant ponyWallet = address(0x6F7AffbE02a8524b0ACbd1cDFd76F0D4Ca49e58e);
    uint256 public constant TAX_FEE = 2;
    uint256 public constant MAX = ~uint256(0);
    uint256 public _tTotal = 100000000000;
    uint256 public _rTotal = (MAX - (MAX % _tTotal));
    uint256 public _tFeeTotal;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    constructor() ERC20("VerminCoin", "VERM") {
        _rOwned[_msgSender()] = _rTotal;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        uint256 rAmount = _getRValues(tAmount, tFee, _getRate());
        return (rAmount, tTransferAmount, tFee);
    }

    function _getTValues(uint256 tAmount) private pure returns (uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tTransferAmount = tAmount - tFee;
        return (tTransferAmount, tFee);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rTransferAmount = rAmount - rFee;
        return rTransferAmount;
    }

    function _getRate() private view returns(uint256) {
        return _rTotal / _tTotal;
    }

    function calculateTaxFee(uint256 _amount) private pure returns (uint256) {
        return _amount * TAX_FEE / 100;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 currentRate =  _getRate();
        uint256 rAmount = amount * currentRate;
        uint256 rFee = calculateTaxFee(rAmount);
        uint256 rTransferAmount = rAmount - rFee;
        uint256 tFee = calculateTaxFee(amount);

        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _reflectFee(rFee, tFee);
        _transferStandard(sender, recipient, amount - tFee);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        uint256 currentRate =  _getRate();
        uint256 rAmount = tAmount * currentRate;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rAmount;
        emit Transfer(sender, recipient, tAmount);
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (from != owner() && to != owner()) {
            require(amount <= _tTotal, "Transfer amount exceeds the maxTxAmount");
        }
    }
}
