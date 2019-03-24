var CUEToken = artifacts.require('CUEToken');
var CUETips = artifacts.require('CUETips');

module.exports = function(deployer) {
  deployer.deploy(CUETips, CUEToken.address);
};
