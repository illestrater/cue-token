pragma solidity ^0.5.2;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract CUETransfer is Ownable {
  using SafeMath for uint256;

  address public CUEWallet = 0xa2B80aB01D4E0f10F724508E72713B3F53A0DECA;

  address CUETokenAddress;
  ERC20 public CUEToken;

  constructor(address _CUETokenAddress) public {
    CUETokenAddress = _CUETokenAddress;
  }

  event TransferSuccessful(address indexed _from, address indexed _to, uint256 _amount);
  event TransferFailed(address indexed _from, address indexed _to, uint256 _amount);
  event WTF(address sender, address recipient);

  function calculateCueShare(uint256 _amount) internal pure returns (uint256) {
    uint256 share = _amount.div(2);
    return share;
  }

  function calculateUserShare(uint256 _amount, uint256 _cueShare) internal pure returns (uint256) {
    uint256 share = _amount.sub(_cueShare);
    return share;
  }

  function tip(address _to, uint256 _amount) public {
    CUEToken = ERC20(CUETokenAddress);
    require(_amount > 0);

    address _from = msg.sender;
    emit WTF(_from, _to);

    if(_amount > CUEToken.allowance(_from, address(this))) {
      emit TransferFailed(_from, _to, _amount);
      revert();
    }

    uint256 _cueShare = calculateCueShare(_amount);
    uint256 _userShare = calculateUserShare(_amount, _cueShare);

    CUEToken.transferFrom(_from, CUEWallet, _cueShare);
    CUEToken.transferFrom(_from, _to, _userShare);
    emit TransferSuccessful(_from, _to, _amount);
  }
}