const BlindAuction = artifacts.require("BlindAuction");

module.exports = function (deployer) {
  deployer.deploy(BlindAuction,5000,5000,"0x48a266E71206f7EC7FBdF4854D516B009BE7552A");
};
