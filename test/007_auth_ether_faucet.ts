import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { id } from "../src/index";

import AuthEtherFaucetArtifact from "../artifacts/contracts/utils/AuthEtherFaucet.sol/AuthEtherFaucet.json";
import { AuthEtherFaucet } from "../typechain/AuthEtherFaucet";

import { ethers, waffle } from "hardhat";
import { expect } from "chai";
const { deployContract } = waffle;

describe("AuthEtherFaucet", async function () {
  let ownerAcc: SignerWithAddress;
  let owner: string;
  let operatorAcc: SignerWithAddress;
  let operator: string;
  let userAcc: SignerWithAddress;
  let user: string;

  let faucet: AuthEtherFaucet;

  beforeEach(async () => {
    const signers = await ethers.getSigners();
    ownerAcc = signers[0];
    owner = ownerAcc.address;
    operatorAcc = signers[1];
    operator = operatorAcc.address;
    userAcc = signers[2];
    user = userAcc.address;

    faucet = (await deployContract(ownerAcc, AuthEtherFaucetArtifact, [
      [operator],
    ])) as AuthEtherFaucet;

    await ownerAcc.sendTransaction({
      to: faucet.address,
      value: "0x1000000000000000000",
    });
  });

  it("allows to drip", async () => {
    const userBalance = await ethers.provider.getBalance(user);
    await faucet.connect(operatorAcc).drip(user, 1);
    expect(await ethers.provider.getBalance(user)).to.equal(userBalance.add(1));
  });

  it("allows to drip only to operators", async () => {
    await expect(faucet.connect(userAcc).drip(user, 1)).to.be.revertedWith(
      "Access denied"
    );
  });
});
