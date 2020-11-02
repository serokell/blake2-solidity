const Blake2b = artifacts.require("Blake2b");
const Blake2bTest = artifacts.require("Blake2bTest");

module.exports = function(deployer) {
  deployer.deploy(Blake2b);
  deployer.link(Blake2b, Blake2bTest);
  deployer.deploy(Blake2b);
};
