const BigNumber = require('bignumber.js');
const moment = require('moment');
const CUEToken = artifacts.require('CUEToken');
const CUEBookings = artifacts.require('CUEBookings');

const should = require('chai')
 .use(require('chai-as-promised'))
 .use(require('chai-bignumber'))
 .should();

contract('CUEBookings', async (accounts) => {
  let token, bookings;
  let WALLET, AGENT_ADDRESS, PERFORMER_ADDRESS, CUE_WALLET, BOOKINGS_WALLET;
  [WALLET, AGENT_ADDRESS, PERFORMER_ADDRESS] = accounts;

  const now = moment(new Date());
  const ID = web3.utils.fromUtf8('1337');
  const PAY = new BigNumber(30);
  const DEPOSIT = PAY.div(5);
  const SHARE = DEPOSIT.div(2);
  const START_TIME = new moment(now).add('4', 'days');
  const END_TIME = new moment(START_TIME).add('4', 'hours');
  let agentBalance = new BigNumber(500);
  let performerBalance = new BigNumber(500);
  let cueBalance = new BigNumber(0);
  let bookingsBalance = new BigNumber(0);

  const createBooking = async () => {
    await token.approve(bookings.address, PAY, { from: AGENT_ADDRESS });
    await bookings.newBooking(ID, PERFORMER_ADDRESS, PAY, START_TIME.unix(), END_TIME.unix(), { from: AGENT_ADDRESS });
    agentBalance = agentBalance.minus(PAY);
    bookingsBalance = bookingsBalance.plus(PAY);
  }
  
  const acceptBooking = async () => {
    await token.approve(bookings.address, DEPOSIT, { from: PERFORMER_ADDRESS });
    await bookings.acceptBooking(ID, { from: PERFORMER_ADDRESS });
    performerBalance = performerBalance.minus(DEPOSIT);
    bookingsBalance = bookingsBalance.plus(DEPOSIT);
  }

  const getBooking = async () => {
    return await bookings.getBooking(ID);
  }

  const checkBalances = async () => {
    (await token.balanceOf(AGENT_ADDRESS)).toString().should.equal(agentBalance.toString());
    (await token.balanceOf(PERFORMER_ADDRESS)).toString().should.equal(performerBalance.toString());
    (await token.balanceOf(CUE_WALLET)).toString().should.equal(cueBalance.toString());
    (await token.balanceOf(BOOKINGS_WALLET)).toString().should.equal(bookingsBalance.toString());
  }

  beforeEach(async () => {
    await CUEToken.deployed().then(instance => token = instance);
    await CUEBookings.deployed(CUEToken.address).then(async instance => {
      bookings = instance
      CUE_WALLET = await instance.CUEWallet();
      BOOKINGS_WALLET = instance.address;
    });
  });

  it('should send 500 tokens to agent and performer', async () => {
    let balance;

    await token.transfer(AGENT_ADDRESS, agentBalance, { from: WALLET });
    balance = await token.balanceOf(AGENT_ADDRESS);
    balance.toString().should.equal(agentBalance.toString());

    await token.transfer(PERFORMER_ADDRESS, performerBalance, { from: WALLET });
    balance = await token.balanceOf(PERFORMER_ADDRESS);
    balance.toString().should.equal(performerBalance.toString());
  });

  it('should request new booking for 30 tokens (AGENT)', async () => {
    await createBooking();
    const booking = await getBooking();
    await checkBalances();

    booking.status.should.equal('requested');
    booking.agent.should.equal(AGENT_ADDRESS);
    booking.performer.should.equal(PERFORMER_ADDRESS);
    booking.pay.toString().should.equal(PAY.toString());
    booking.deposit.toString().should.equal(DEPOSIT.toString());
    booking.startTime.toString().should.equal(START_TIME.unix().toString());
    booking.endTime.toString().should.equal(END_TIME.unix().toString());
  });

  it('should cancel request before booking (AGENT)', async () => {
    await createBooking();
    await bookings.cancelBooking(ID, { from: AGENT_ADDRESS });
    bookingsBalance = bookingsBalance.minus(PAY);
    agentBalance = agentBalance.plus(PAY);
    await checkBalances();

    const booking = await getBooking();
    booking.status.should.equal('agent_reject');
    booking.agent.should.equal(AGENT_ADDRESS);
    booking.performer.should.equal(PERFORMER_ADDRESS);
    booking.pay.toString().should.equal(PAY.toString());
    booking.deposit.toString().should.equal(DEPOSIT.toString());
    booking.startTime.toString().should.equal(START_TIME.unix().toString());
    booking.endTime.toString().should.equal(END_TIME.unix().toString());
  });

  it('should cancel request after booking (AGENT)', async () => {
    await createBooking();
    await acceptBooking();

    await bookings.cancelBooking(ID, { from: AGENT_ADDRESS });
    bookingsBalance = bookingsBalance.minus(PAY).minus(DEPOSIT);
    agentBalance = agentBalance.plus(PAY);
    performerBalance = performerBalance.plus(DEPOSIT);
    await checkBalances();

    const booking = await getBooking();
    booking.status.should.equal('agent_reject');
    booking.agent.should.equal(AGENT_ADDRESS);
    booking.performer.should.equal(PERFORMER_ADDRESS);
    booking.pay.toString().should.equal(PAY.toString());
    booking.deposit.toString().should.equal(DEPOSIT.toString());
    booking.startTime.toString().should.equal(START_TIME.unix().toString());
    booking.endTime.toString().should.equal(END_TIME.unix().toString());
  });

  it('should decline request before booking (PERFORMER)', async () => {
    await createBooking();
    await bookings.declineBooking(ID, { from: PERFORMER_ADDRESS });
    bookingsBalance = bookingsBalance.minus(PAY);
    agentBalance = agentBalance.plus(PAY);
    await checkBalances();
    
    const booking = await getBooking();
    booking.status.should.equal('performer_reject');
    booking.agent.should.equal(AGENT_ADDRESS);
    booking.performer.should.equal(PERFORMER_ADDRESS);
    booking.pay.toString().should.equal(PAY.toString());
    booking.deposit.toString().should.equal(DEPOSIT.toString());
    booking.startTime.toString().should.equal(START_TIME.unix().toString());
    booking.endTime.toString().should.equal(END_TIME.unix().toString());
  });

  it('should decline request after booking (PERFORMER)', async () => {
    await createBooking();
    await acceptBooking();

    await bookings.declineBooking(ID, { from: PERFORMER_ADDRESS });
    bookingsBalance = bookingsBalance.minus(PAY).minus(DEPOSIT);
    agentBalance = agentBalance.plus(PAY);
    performerBalance = performerBalance.plus(DEPOSIT);
    await checkBalances();

    const booking = await getBooking();
    booking.status.should.equal('performer_reject');
    booking.agent.should.equal(AGENT_ADDRESS);
    booking.performer.should.equal(PERFORMER_ADDRESS);
    booking.pay.toString().should.equal(PAY.toString());
    booking.deposit.toString().should.equal(DEPOSIT.toString());
    booking.startTime.toString().should.equal(START_TIME.unix().toString());
    booking.endTime.toString().should.equal(END_TIME.unix().toString());
  });

  it('should accept booking (PERFORMER)', async () => {
    await createBooking();
    await acceptBooking();
    await checkBalances();

    const booking = await getBooking();
    booking.status.should.equal('booked');
    booking.agent.should.equal(AGENT_ADDRESS);
    booking.performer.should.equal(PERFORMER_ADDRESS);
    booking.pay.toString().should.equal(PAY.toString());
    booking.deposit.toString().should.equal(DEPOSIT.toString());
    booking.startTime.toString().should.equal(START_TIME.unix().toString());
    booking.endTime.toString().should.equal(END_TIME.unix().toString());
  });
  
  it ('should create future successful booking', async () => {
    await createBooking();
    await acceptBooking();
    await checkBalances();
  });

  it('should adjust time forward to successful booking', async () => {
    const addTime = new moment(now).add('6', 'days');
    const timeAdjustment = addTime.unix() - now.unix();
    await web3.currentProvider.send({ id: '1', jsonrpc: '2.0', method: 'evm_increaseTime', params: [timeAdjustment] }, (err, result) => {});
    await web3.currentProvider.send({ id: '1', jsonrpc: '2.0', method: 'evm_mine' }, (err, result) => {});
  })

  it('should payout pay and share', async () => {
    await bookings.withdrawPay(ID, { from: PERFORMER_ADDRESS });
    bookingsBalance = bookingsBalance.minus(PAY).minus(DEPOSIT);
    performerBalance = performerBalance.plus(PAY.plus(SHARE));
    cueBalance = cueBalance.plus(SHARE);
    await checkBalances();

    const booking = await getBooking();
    booking.status.should.equal('completed');
    booking.agent.should.equal(AGENT_ADDRESS);
    booking.performer.should.equal(PERFORMER_ADDRESS);
    booking.pay.toString().should.equal(PAY.toString());
    booking.deposit.toString().should.equal(DEPOSIT.toString());
    booking.startTime.toString().should.equal(START_TIME.unix().toString());
    booking.endTime.toString().should.equal(END_TIME.unix().toString());
  });
});
