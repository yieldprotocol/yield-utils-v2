import { ethers } from 'hardhat'
import *  as fs from 'fs'

import { AuthEtherFaucet } from '../typechain/AuthEtherFaucet'

/**
 * @dev This script deploys the SafeERC20Namer and YieldMath libraries
 */

(async () => {
    let faucet: AuthEtherFaucet
    const [ ownerAcc ] = await ethers.getSigners();
    const faucetFactory = await ethers.getContractFactory('AuthEtherFaucet')
    faucet = ((await faucetFactory.deploy([ownerAcc.address])) as unknown) as AuthEtherFaucet
    await faucet.deployed()
    console.log(`Faucet deployed at ${faucet.address}`)
})()
