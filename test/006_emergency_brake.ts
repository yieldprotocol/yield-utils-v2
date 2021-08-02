import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import { id } from '../src/index';

import RestrictedERC20MockArtifact from '../artifacts/contracts/mocks/RestrictedERC20Mock.sol/RestrictedERC20Mock.json';
import EmergencyBrakeArtifact from '../artifacts/contracts/utils/EmergencyBrake.sol/EmergencyBrake.json';
import { RestrictedERC20Mock as ERC20 } from '../typechain/RestrictedERC20Mock';
import { EmergencyBrake } from '../typechain/EmergencyBrake';

import { BigNumber } from 'ethers';

import { ethers, waffle } from 'hardhat';
import { expect } from 'chai';
const { deployContract, loadFixture } = waffle;

describe('EmergencyBrake', async function () {
  this.timeout(0);

  let plannerAcc: SignerWithAddress;
  let planner: string;
  let executorAcc: SignerWithAddress;
  let executor: string;
  let targetAcc: SignerWithAddress;
  let target: string;

  let contact1: ERC20;
  let contact2: ERC20;
  let brake: EmergencyBrake;

  const state = {
    UNKNOWN: 0,
    PLANNED: 1,
    EXECUTED: 2,
    TERMINATED: 3,
  };

  const MINT = id('mint(address,uint256)')
  const BURN = id('burn(address,uint256)')
  const APPROVE = id('approve(address,uint256)')
  const TRANSFER = id('transfer(address,uint256)')
  const ROOT = '0x00000000'
  
  let contacts: string[]
  let signatures: string[][]

  beforeEach(async () => {
    const signers = await ethers.getSigners();
    plannerAcc = signers[0];
    planner = plannerAcc.address;
    executorAcc = signers[1];
    executor = executorAcc.address;
    targetAcc = signers[2];
    target = targetAcc.address;

    contact1 = (await deployContract(plannerAcc, RestrictedERC20MockArtifact, [
      'Contact1',
      'CT1',
    ])) as ERC20;
    contact2 = (await deployContract(plannerAcc, RestrictedERC20MockArtifact, [
      'Contact2',
      'CT2',
    ])) as ERC20;
    brake = (await deployContract(plannerAcc, EmergencyBrakeArtifact, [
      planner,
      executor,
    ])) as EmergencyBrake;

    await contact1.grantRoles([MINT, BURN], target)
    await contact2.grantRoles([TRANSFER, APPROVE], target)

    await contact1.grantRole(ROOT, brake.address)
    await contact2.grantRole(ROOT, brake.address)

    contacts = [contact1.address, contact2.address];
    signatures = [[MINT, BURN], [TRANSFER, APPROVE]];
  });

  it('doesn\'t allow mismatched inputs', async () => {
    const mismatch = [[MINT, BURN]];

    await expect(
      brake.connect(plannerAcc).plan(target, contacts, mismatch)
    ).to.be.revertedWith('Mismatched inputs');
    await expect(
      brake.connect(plannerAcc).cancel(target, contacts, mismatch)
    ).to.be.revertedWith('Mismatched inputs');
    await expect(
      brake.connect(executorAcc).execute(target, contacts, mismatch)
    ).to.be.revertedWith('Mismatched inputs');
    await expect(
      brake.connect(plannerAcc).restore(target, contacts, mismatch)
    ).to.be.revertedWith('Mismatched inputs');
    await expect(
      brake.connect(plannerAcc).terminate(target, contacts, mismatch)
    ).to.be.revertedWith('Mismatched inputs');
  });

  it('doesn\'t allow to cancel, execute, restore or terminate an unknown plan', async () => {
    await expect(
      brake.connect(plannerAcc).cancel(target, contacts, signatures)
    ).to.be.revertedWith('Emergency not planned for.');
    await expect(
      brake.connect(executorAcc).execute(target, contacts, signatures)
    ).to.be.revertedWith('Emergency not planned for.');
    await expect(
      brake.connect(plannerAcc).restore(target, contacts, signatures)
    ).to.be.revertedWith('Emergency plan not executed.');
    await expect(
      brake.connect(plannerAcc).terminate(target, contacts, signatures)
    ).to.be.revertedWith('Emergency plan not executed.');
  });

  it('only the planner can plan', async () => {
    await expect(
      brake.connect(executorAcc).plan(target, contacts, signatures)
    ).to.be.revertedWith('Access denied');
  });

  it('ROOT is out of bounds', async () => {
    const tryRoot = [[ROOT], [TRANSFER, APPROVE]];
    await expect(
      brake.connect(plannerAcc).plan(target, contacts, tryRoot)
    ).to.be.revertedWith('Can\'t remove ROOT');
  });

  it('emergencies can be planned', async () => {
    const txHash = await brake.connect(plannerAcc).callStatic.plan(target, contacts, signatures);

    expect(await brake.connect(plannerAcc).plan(target, contacts, signatures))
      .to.emit(brake, 'Planned');

    expect(await brake.plans(txHash)).to.equal(state.PLANNED)
  });

  describe('with a planned emergency', async () => {
    let txHash: string;

    beforeEach(async () => {
      txHash = await brake.connect(plannerAcc).callStatic.plan(target, contacts, signatures);
  
      await brake.connect(plannerAcc).plan(target, contacts, signatures)
    });

    it('the same emergency plan cant\'t registered twice', async () => {
      await expect(
        brake.connect(plannerAcc).plan(target, contacts, signatures)
      ).to.be.revertedWith('Emergency already planned for.');
    });

    it('only the planner can cancel', async () => {
      await expect(
        brake.connect(executorAcc).cancel(target, contacts, signatures)
      ).to.be.revertedWith('Access denied');
    });

    it('cancels a plan', async () => {
      await expect(
        await brake.connect(plannerAcc).cancel(target, contacts, signatures)
      ).to.emit(brake, 'Cancelled');
      //        .withArgs(txHash, target, contacts, signatures)
      expect(await brake.plans(txHash)).to.equal(state.UNKNOWN);
    });

    it('cant\'t restore or terminate a plan that hasn\'t been executed', async () => {
      await expect(
        brake.connect(plannerAcc).restore(target, contacts, signatures)
      ).to.be.revertedWith('Emergency plan not executed.');
      await expect(
        brake.connect(plannerAcc).terminate(target, contacts, signatures)
      ).to.be.revertedWith('Emergency plan not executed.');
    });
  
    it('only the executor can execute', async () => {
      await expect(
        brake.connect(plannerAcc).execute(target, contacts, signatures)
      ).to.be.revertedWith('Access denied');
    });

    it('can\'t revoke non-existing permissions', async () => {
      const nonExisting = [[MINT, BURN], [MINT, BURN]];
      await brake.connect(plannerAcc).plan(target, contacts, nonExisting) // It can be planned, because permissions could be different at execution time
      await expect(
        brake.connect(executorAcc).execute(target, contacts, nonExisting)
      ).to.be.revertedWith('Permission not found');
    });

    it('plans can be executed', async () => {
      expect(await brake.connect(executorAcc).execute(target, contacts, signatures))
        .to.emit(brake, 'Executed');

      expect(await contact1.hasRole(MINT, target)).to.be.false
      expect(await contact1.hasRole(BURN, target)).to.be.false
      expect(await contact2.hasRole(APPROVE, target)).to.be.false
      expect(await contact2.hasRole(TRANSFER, target)).to.be.false

      expect(await brake.plans(txHash)).to.equal(state.EXECUTED)
    });

    describe('with an executed emergency plan', async () => {  
      beforeEach(async () => {
        await brake.connect(executorAcc).execute(target, contacts, signatures);
      });

      it('the same emergency plan cant\'t executed twice', async () => {
        await expect(
          brake.connect(executorAcc).execute(target, contacts, signatures)
        ).to.be.revertedWith('Emergency not planned for.');
      });
  
      it('only the planner can restore or terminate', async () => {
        await expect(
          brake.connect(executorAcc).restore(target, contacts, signatures)
        ).to.be.revertedWith('Access denied');
        await expect(
          brake.connect(executorAcc).terminate(target, contacts, signatures)
        ).to.be.revertedWith('Access denied');
      });

      it('state can be restored', async () => {
        expect(await brake.connect(plannerAcc).restore(target, contacts, signatures))
          .to.emit(brake, 'Restored');

        expect(await contact1.hasRole(MINT, target)).to.be.true
        expect(await contact1.hasRole(BURN, target)).to.be.true
        expect(await contact2.hasRole(APPROVE, target)).to.be.true
        expect(await contact2.hasRole(TRANSFER, target)).to.be.true

        expect(await brake.plans(txHash)).to.equal(state.PLANNED)
      });

      it('target can be terminated', async () => {
        expect(await brake.connect(plannerAcc).terminate(target, contacts, signatures))
          .to.emit(brake, 'Terminated');

        expect(await brake.plans(txHash)).to.equal(state.TERMINATED)
      });
    });
  });
});
