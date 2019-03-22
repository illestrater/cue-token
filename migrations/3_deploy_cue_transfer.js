var CUEToken = artifacts.require('CUEToken');
var CUETransfer = artifacts.require('CUETransfer');

module.exports = function(deployer) {
  deployer.deploy(CUETransfer, CUEToken.address);
};
