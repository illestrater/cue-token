pragma solidity ^0.5.2;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import './CUETransfer.sol';

contract CUEDisputeResolution is Ownable {
  using SafeMath for uint256;

  ERC20 public CUEToken;
  address public CUEBookingsAddress;
  address public CUEWallet = 0xa2B80aB01D4E0f10F724508E72713B3F53A0DECA;

  struct Dispute {
    string status;
    address agent;
    address performer;
    uint256 pay;
    uint256 deposit;
  }

  mapping (address => bytes32) private resolvers;
  mapping (bytes12 => Dispute) private disputes;
  address[] public resolversList;

  constructor(address _CUETokenAddress) public {
    CUEToken = ERC20(_CUETokenAddress);
    transferOwnership(msg.sender);
  }

  function setCUEBookingsAddress(address _CUEBookingsAddress) public onlyOwner() {
    CUEBookingsAddress = _CUEBookingsAddress;
    transferOwnership(CUEBookingsAddress);
  }

  event NewDispute(bytes12 id, string status, address agent, address performer, uint256 pay, uint256 deposit);

  function addResolver(address _resolver, bytes32 _resolverName) public onlyOwner() {
    resolvers[_resolver] = _resolverName;
    resolversList.push(_resolver) -1;
  }

  function removeResolver(address _resolver) public onlyOwner() {
    for (uint i = 0; i < resolversList.length - 1; i++) {
      if (resolversList[i] == _resolver) {
        delete resolversList[i];
      }
    }
    delete resolvers[_resolver];
  }

  function getResolverCount() public view returns (uint count) {
    return resolversList.length;
  }

  function getResolver(address _resolver) public view returns (bytes32 resolver) {
    return resolvers[_resolver];
  }

  function createDispute(bytes12 _id, address _agent, address _performer, uint256 _pay, uint256 _deposit) public onlyOwner() {
    Dispute storage dispute = disputes[_id];
    dispute.status = 'unresolved';
    dispute.agent = _agent;
    dispute.performer = _performer;
    dispute.pay = _pay;
    dispute.deposit = _deposit;

    emit NewDispute(_id, 'unresolved', _agent, _performer, _pay, _deposit);
  }

  function getDispute(bytes12 _id) public view returns (string memory status, address agent, address performer, uint256 pay, uint256 deposit) {
    return (
      disputes[_id].status,
      disputes[_id].agent,
      disputes[_id].performer,
      disputes[_id].pay,
      disputes[_id].deposit
    );
  }

  function resolveDispute(bytes12 _id, bool _didPerformerWin) public {
    require(resolvers[msg.sender].length != 0);
    Dispute storage dispute = disputes[_id];

    if (_didPerformerWin) {
      CUEToken.transfer(CUEWallet, dispute.deposit.div(2));
      CUEToken.transfer(dispute.performer, dispute.pay.add(dispute.deposit.div(2)));
    }
    else {
      CUEToken.transfer(CUEWallet, dispute.deposit.div(2));
      CUEToken.transfer(dispute.agent, dispute.pay.add(dispute.deposit.div(2)));
    }

    dispute.status = 'resolved';
  }
}