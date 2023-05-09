var Tags = artifacts.require("./Tags.sol");
var Provider = artifacts.require("./Provider.sol");
var Rewards = artifacts.require("./Rewards.sol");

module.exports = function (deployer) {
  deployer.deploy(Rewards)
    .then(() => Rewards.deployed())
    .then(() => deployer.deploy(Provider))
    .then(() => Provider.deployed())
    .then(() => deployer.deploy(Tags, Provider.address, Rewards.address, 1000, "Tags", "TAG"));
};
