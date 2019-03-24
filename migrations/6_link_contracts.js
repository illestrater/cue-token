var CUEBookings = artifacts.require('CUEBookings');
var CUEDisputeResolution = artifacts.require('CUEDisputeResolution');

module.exports = function(deployer) {
  CUEBookings.deployed(instance => {
    instance.setDisputeResolutionAddress(CUEDisputeResolution.address);
  })

  CUEDisputeResolution.deployed(instance => {
    instance.setBookingsAddress(CUEBookings.address);
  })
};
