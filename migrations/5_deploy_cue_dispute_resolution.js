var CUEToken = artifacts.require('CUEToken');
var CUEDisputeResolution = artifacts.require('CUEDisputeResolution');

module.exports = function(deployer) {
  deployer.deploy(CUEDisputeResolution, CUEToken.address);
};
