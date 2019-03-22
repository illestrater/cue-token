var CUEToken = artifacts.require('CUEToken');
var CUEBookings = artifacts.require('CUEBookings');

module.exports = function(deployer) {
  deployer.deploy(CUEBookings, CUEToken.address);
};
