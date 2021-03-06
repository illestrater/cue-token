pragma solidity ^0.5.2;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import './CUEDisputeResolution.sol';
import './CUETips.sol';

contract CUEBookings is Ownable {
  using SafeMath for uint256;

  ERC20 public CUEToken;
  CUEDisputeResolution public DisputeResolution;
  address public DisputeResolutionAddress;
  address public CUEWallet = 0xa2B80aB01D4E0f10F724508E72713B3F53A0DECA;
  uint8 public decimals = 18;

  struct Booking {
    string status;
    address agent;
    address performer;
    uint256 pay;
    uint256 deposit;
    uint256 startTime;
    uint256 endTime;
  }

  mapping (bytes12 => Booking) private bookings;

  constructor(address _CUETokenAddress) public {
    CUEToken = ERC20(_CUETokenAddress);
    transferOwnership(msg.sender);
  }

  event NewBooking(string status, address agent, address performer, uint256 pay, uint256 deposit, uint256 startTime, uint256 endTime);
  event PayableEvent(address _beneficiary, uint256 _payout, string _event);
  event CueShareEvent(uint256 _payout);
  event TestEvent(string wtf);

  function returnOrPayout(address _beneficiary, uint256 _pay, string memory _event) private {
    CUEToken.transfer(_beneficiary, _pay);
    emit PayableEvent(_beneficiary, _pay, _event);
  }

  function cueShare(uint256 _share) private {
    CUEToken.transfer(CUEWallet, _share);
    emit CueShareEvent(_share);
  }

  function newBooking(bytes12 _id, address _performer, uint256 _pay, uint256 _startTime, uint256 _endTime) public {
    require(
      bookings[_id].agent == address(0) && // Check if booking does not exist
      _pay >= 10 ** uint256(decimals) &&
      _pay <= CUEToken.allowance(msg.sender, address(this)) &&
      now < _startTime &&
      _endTime - _startTime > 0);
    CUEToken.transferFrom(msg.sender, address(this), _pay);

    Booking storage booking = bookings[_id];
    booking.status = 'requested';
    booking.agent = msg.sender;
    booking.performer = _performer;
    booking.pay = _pay;
    booking.deposit = _pay.div(10);
    booking.startTime = _startTime;
    booking.endTime = _endTime;

    emit NewBooking(bookings[_id].status, bookings[_id].agent, bookings[_id].performer, bookings[_id].pay, bookings[_id].deposit, bookings[_id].startTime, bookings[_id].endTime);
  }

  function getBooking(bytes12 _id) public view returns (string memory status, address agent, address performer, uint256 pay, uint256 deposit, uint256 startTime, uint256 endTime) {
    return (
      bookings[_id].status,
      bookings[_id].agent,
      bookings[_id].performer,
      bookings[_id].pay,
      bookings[_id].deposit,
      bookings[_id].startTime,
      bookings[_id].endTime
    );
  }

  function isRequested(string memory status) private pure returns (bool) {
    return keccak256(abi.encodePacked(status)) == keccak256(abi.encodePacked('requested'));
  }

  function isBooked(string memory status) private pure returns (bool) {
    return keccak256(abi.encodePacked(status)) == keccak256(abi.encodePacked('booked'));
  }

  function isAgentClaim(string memory status) private pure returns (bool) {
    return keccak256(abi.encodePacked(status)) == keccak256(abi.encodePacked('agent_claim'));
  }

  // Performer accepts booking
  function acceptBooking(bytes12 _id) public {
    Booking storage booking = bookings[_id];
    require(
      booking.performer == msg.sender &&
      now < booking.startTime &&
      isRequested(booking.status) &&
      booking.deposit <= CUEToken.allowance(msg.sender, address(this))
    );

    CUEToken.transferFrom(msg.sender, address(this), booking.deposit);
    booking.status = 'booked';
  }

  // Performer declines booking
  function declineBooking(bytes12 _id) public {
    Booking storage booking = bookings[_id];
    require(booking.performer == msg.sender);
 
    if (isRequested(booking.status)) {
      returnOrPayout(booking.agent, booking.pay, 'agent_deposit');
      booking.status = 'performer_reject';
    } else if (isBooked(booking.status)) {
      if (now > booking.startTime - 48 hours && now <= booking.startTime - 24 hours) { // Penalize performer
        returnOrPayout(booking.agent, booking.pay.add(booking.deposit), 'performer_penalty');
        booking.status = 'performer_reject_penalty';
      } else {
        require(now <= booking.startTime - 48 hours);
        returnOrPayout(booking.performer, booking.deposit, 'performer_deposit');
        returnOrPayout(booking.agent, booking.pay, 'agent_deposit');
        booking.status = 'performer_reject';
      }
    }
  }

  // Booking agent cancels booking
  function cancelBooking(bytes12 _id) public {
    Booking storage booking = bookings[_id];
    require(booking.agent == msg.sender);

    if (isRequested(booking.status)) {
      returnOrPayout(booking.agent, booking.pay, 'agent_deposit');
      booking.status = 'agent_reject';
    } else if (isBooked(booking.status)) {
      if (now > booking.startTime - 48 hours && now <= booking.startTime - 24 hours) { // Penalize booking agent
        returnOrPayout(booking.agent, booking.pay.sub(booking.deposit), 'agent_penalty');
        returnOrPayout(booking.performer, booking.deposit.mul(2), 'performer_benefit');
        booking.status = 'agent_reject_penalty';
      } else {
        require(now <= booking.startTime - 48 hours);
        returnOrPayout(booking.performer, booking.deposit, 'performer_deposit');
        returnOrPayout(booking.agent, booking.pay, 'agent_deposit');
        booking.status = 'agent_reject';
      }
    }
  }

  function withdrawPay(bytes12 _id) public {
    Booking storage booking = bookings[_id];
    require(
      booking.performer == msg.sender &&
      now >= booking.endTime + 24 hours &&
      isBooked(booking.status)
    );

    returnOrPayout(booking.performer, booking.pay.add(booking.deposit.div(2)), 'performer_withdraw');
    cueShare(booking.deposit.div(2));
    booking.status = 'completed';
  }

  function withdrawPayUnclaimed(bytes12 _id) public {
    Booking storage booking = bookings[_id];
    require(
      booking.agent == msg.sender &&
      (now > booking.endTime + 72 hours &&
      isAgentClaim(booking.status))
    );

    returnOrPayout(booking.performer, booking.deposit, 'performer_deposit');
    returnOrPayout(booking.agent, booking.pay, 'agent_deposit');
    booking.status = 'agent_claim_withdraw';
  }

  function agentClaim(bytes12 _id) public {
    Booking storage booking = bookings[_id];
    require(
      booking.agent == msg.sender &&
      now > booking.startTime && now < booking.endTime + 24 hours &&
      isBooked(booking.status)
    );

    booking.status = 'agent_claim';
  }

  function performerClaim(bytes12 _id) public {
    Booking storage booking = bookings[_id];
    require(
      booking.performer == msg.sender &&
      now > booking.startTime && now < booking.endTime + 72 hours &&
      isAgentClaim(booking.status)
    );

    CUEToken.transfer(DisputeResolutionAddress, booking.pay.add(booking.deposit));
    DisputeResolution.createDispute(_id, booking.agent, booking.performer, booking.pay, booking.deposit);

    booking.status = 'dispute';
  }

  // Dispute resolution functions
  function setDisputeResolutionAddress(address _disputeResolutionAddress) public onlyOwner() {
    DisputeResolutionAddress = _disputeResolutionAddress;
    DisputeResolution = CUEDisputeResolution(DisputeResolutionAddress);
  }

  function addArbitrator(address _arbitrator, bytes32 _arbitratorName) public onlyOwner() {
    DisputeResolution.addArbitrator(_arbitrator, _arbitratorName);
  }

  function removeArbitrator(address _arbitrator) public onlyOwner() {
    DisputeResolution.removeArbitrator(_arbitrator);
  }
}