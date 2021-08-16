import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { id } from "../src/index";

import ERC20MockArtifact from "../artifacts/contracts/mocks/ERC20Mock.sol/ERC20Mock.json";
import TimeLockArtifact from "../artifacts/contracts/utils/TimeLock.sol/TimeLock.json";
import { ERC20Mock as ERC20 } from "../typechain/ERC20Mock";
import { TimeLock } from "../typechain/TimeLock";

import { BigNumber } from "ethers";

import { ethers, waffle } from "hardhat";
import { expect } from "chai";
const { deployContract, loadFixture } = waffle;

describe("TimeLock", async function () {
  this.timeout(0);

  let schedulerAcc: SignerWithAddress;
  let scheduler: string;
  let executorAcc: SignerWithAddress;
  let executor: string;

  let target1: ERC20;
  let target2: ERC20;
  let timelock: TimeLock;

  let timestamp: number;
  let resetChain: number;
  let now: BigNumber

  before(async () => {
    resetChain = await ethers.provider.send("evm_snapshot", []);
    const signers = await ethers.getSigners();
    schedulerAcc = signers[0];
    scheduler = schedulerAcc.address;
    executorAcc = signers[1];
    executor = executorAcc.address;
  });

  after(async () => {
    await ethers.provider.send("evm_revert", [resetChain]);
  });

  beforeEach(async () => {
    target1 = (await deployContract(schedulerAcc, ERC20MockArtifact, [
      "Target1",
      "TG1",
    ])) as ERC20;
    target2 = (await deployContract(schedulerAcc, ERC20MockArtifact, [
      "Target2",
      "TG2",
    ])) as ERC20;
    timelock = (await deployContract(schedulerAcc, TimeLockArtifact, [
      scheduler,
      executor,
    ])) as TimeLock;
    ({ timestamp } = await ethers.provider.getBlock("latest"));
    now = BigNumber.from(timestamp)
  });

  it("doesn't allow governance changes to scheduler", async () => {
    await expect(timelock.setDelay(0)).to.be.revertedWith("Access denied");
    await expect(
      timelock.grantRole("0x00000000", scheduler)
    ).to.be.revertedWith("Only admin");
    await expect(
      timelock.grantRole(id("schedule(address[],bytes[],uint32)"), executor)
    ).to.be.revertedWith("Only admin");
    await expect(
      timelock.revokeRole(id("schedule(address[],bytes[],uint32)"), scheduler)
    ).to.be.revertedWith("Only admin");
  });

  it("doesn't allow mismatched inputs", async () => {
    const targets = [target1.address, target2.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    const eta = now.add(await timelock.delay());
    await expect(
      timelock.connect(schedulerAcc).schedule(targets, data, eta)
    ).to.be.revertedWith("Mismatched inputs");
    await expect(
      timelock.connect(schedulerAcc).cancel(targets, data)
    ).to.be.revertedWith("Mismatched inputs");
    await expect(
      timelock.connect(executorAcc).execute(targets, data)
    ).to.be.revertedWith("Mismatched inputs");
  });

  it("only the scheduler can schedule", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    const eta = now;
    await expect(
      timelock.connect(executorAcc).schedule(targets, data, eta)
    ).to.be.revertedWith("Access denied");
  });

  it("doesn't allow to schedule for execution before `delay()`", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    const eta = now;
    await expect(
      timelock.connect(schedulerAcc).schedule(targets, data, eta)
    ).to.be.revertedWith("Must satisfy delay");
  });

  it("only the scheduler can cancel", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    await expect(
      timelock.connect(executorAcc).cancel(targets, data)
    ).to.be.revertedWith("Access denied");
  });

  it("doesn't allow to cancel if not scheduled", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    await expect(
      timelock.connect(schedulerAcc).cancel(targets, data)
    ).to.be.revertedWith("Transaction hasn't been scheduled.");
  });

  it("only the executor can execute", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    await expect(
      timelock
        .connect(schedulerAcc)
        .execute(targets, data)
    ).to.be.revertedWith("Access denied");
  });

  it("doesn't allow to execute before eta", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    const eta = now.add(await timelock.delay()).add(100);
    await timelock
      .connect(schedulerAcc)
      .schedule(targets, data, eta);
    await expect(
      timelock.connect(executorAcc).execute(targets, data)
    ).to.be.revertedWith("ETA not reached");
  });

  it("doesn't allow to execute after grace period", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    const eta = now.add(await timelock.delay()).add(100);

    await timelock
      .connect(schedulerAcc)
      .schedule(targets, data, eta);
    
    const snapshotId = await ethers.provider.send("evm_snapshot", []);
    await ethers.provider.send("evm_mine", [eta.add(await timelock.GRACE_PERIOD()).add(100).toNumber()]);
    
    await expect(
      timelock.connect(executorAcc).execute(targets, data)
    ).to.be.revertedWith("Transaction is stale");

    await ethers.provider.send("evm_revert", [snapshotId]);
  });

  it("doesn't allow to execute to a non-contract", async () => {
    const targets = [scheduler];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    const eta = now.add(await timelock.delay()).add(100);

    await timelock
      .connect(schedulerAcc)
      .schedule(targets, data, eta);
    
    const snapshotId = await ethers.provider.send("evm_snapshot", []);
    await ethers.provider.send("evm_mine", [eta.add(100).toNumber()]);
    
    await expect(
      timelock.connect(executorAcc).execute(targets, data)
    ).to.be.revertedWith("Call to a non-contract");

    await ethers.provider.send("evm_revert", [snapshotId]);
  });

  it("doesn't allow to execute if not scheduled", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    await expect(
      timelock.connect(executorAcc).execute(targets, data)
    ).to.be.revertedWith("Transaction hasn't been scheduled.");
  });

  it("schedules a transaction", async () => {
    const targets = [target1.address];
    const data = [target1.interface.encodeFunctionData("mint", [scheduler, 1])];
    const eta = now.add(await timelock.delay()).add(100);
    const txHash = await timelock
      .connect(schedulerAcc)
      .callStatic.schedule(targets, data, eta);

    await expect(
      await timelock.connect(schedulerAcc).schedule(targets, data, eta)
    ).to.emit(timelock, "Scheduled");
    //      .withArgs(txHash, targets, data, eta)
    expect(await timelock.transactions(txHash)).to.equal(eta);
  });

  describe("with a scheduled transaction", async () => {
    let snapshotId: string;
    let timestamp: number;
    let targets: string[];
    let data: string[];
    let eta: BigNumber;
    let txHash: string;

    beforeEach(async () => {
      ({ timestamp } = await ethers.provider.getBlock("latest"));
      now = BigNumber.from(timestamp)
      targets = [target1.address, target2.address];
      data = [
        target1.interface.encodeFunctionData("mint", [scheduler, 1]),
        target2.interface.encodeFunctionData("approve", [scheduler, 1]),
      ];
      eta = now.add(await timelock.delay()).add(100);
      txHash = await timelock
        .connect(schedulerAcc)
        .callStatic.schedule(targets, data, eta);
      await timelock.connect(schedulerAcc).schedule(targets, data, eta);
    });

    it("cancels a transaction", async () => {
      await expect(
        await timelock.connect(schedulerAcc).cancel(targets, data)
      ).to.emit(timelock, "Cancelled");
      //        .withArgs(txHash, targets, data, eta)
      expect(await timelock.transactions(txHash)).to.equal(0);
    });

    describe("once the eta arrives", async () => {
      beforeEach(async () => {
        snapshotId = await ethers.provider.send("evm_snapshot", []);
        await ethers.provider.send("evm_mine", [eta.toNumber()]);
      });

      afterEach(async () => {
        await ethers.provider.send("evm_revert", [snapshotId]);
      });

      it("executes a transaction", async () => {
        await expect(
          await timelock.connect(executorAcc).execute(targets, data)
        )
          .to.emit(timelock, "Executed")
          //          .withArgs(txHash, targets, data, eta)
          .to.emit(target1, "Transfer")
          //          .withArgs(null, scheduler, 1)
          .to.emit(target2, "Approval");
        //          .withArgs(scheduler, scheduler, 1)
        expect(await timelock.transactions(txHash)).to.equal(0);
        expect(await target1.balanceOf(scheduler)).to.equal(1);
        expect(await target2.allowance(timelock.address, scheduler)).to.equal(
          1
        );
      });
    });
  });
});
