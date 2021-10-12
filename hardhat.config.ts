import *  as fs from 'fs'
import * as path from 'path'

import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'
import 'hardhat-abi-exporter'
import 'hardhat-contract-sizer'
import 'hardhat-gas-reporter'
import 'hardhat-typechain'
import 'solidity-coverage'
import 'hardhat-deploy'
import { task } from 'hardhat/config'

// import { addAsset, makeBase, makeIlk, addSeries } from './scripts/add'

// REQUIRED TO ENSURE METADATA IS SAVED IN DEPLOYMENTS (because solidity-coverage disable it otherwise)
/* import {
  TASK_COMPILE_GET_COMPILER_INPUT
} from "hardhat/builtin-tasks/task-names"
task(TASK_COMPILE_GET_COMPILER_INPUT).setAction(async (_, bre, runSuper) => {
  const input = await runSuper()
  input.settings.metadata.useLiteralContent = bre.network.name !== "coverage"
  return input
}) */

/* task("asset", "Adds assets and makes them into ilks and/or bases")
  .addFlag("add", "Add asset")
  .addFlag("base", "Make asset into base")
  .addFlag("ilk", "Make asset into ilk")
  .addVariadicPositionalParam("asset", "The details of the asset")
  .setAction(async (taskArgs, hre) => {
    const argv: any = {}
    if (taskArgs.add) {
      argv.asset = taskArgs.asset[0]  // address
      await addAsset(argv, hre)
    } else if (taskArgs.base) {
      argv.asset = taskArgs.asset[0]  // address
      argv.rateSource = [1]           // address
      argv.chiSource = [2]            // address
      await makeBase(argv, hre)
    } else if (taskArgs.ilk) {
      argv.asset = taskArgs.asset[0]  // address, p.e. MKR, which will be used as collateral
      argv.base = taskArgs.asset[1]   // address, p.e. DAI, which will be the underlying
      argv.spotSource = taskArgs.asset[2] // address, p.e. DAI/MKR, which will be the source for the spot oracle
      await makeIlk(argv, hre)
    } else {
      console.error("Must add an asset, make an asset into a base or make an asset into an ilk")
    }
});

task("series", "Adds a series")
  .addVariadicPositionalParam("series", "The details of the series")
  .setAction(async (taskArgs, hre) => {
    const argv: any = {}
    argv.seriesId = taskArgs.series[0]  // address, p.e. MKR, which will be used as collateral
    argv.base = taskArgs.series[1]   // address, p.e. DAI, which will be the underlying
    argv.maturity = taskArgs.series[2]   // address, p.e. DAI, which will be the underlying
    argv.ilkIds = []
    argv.ilkIds = taskArgs.series.slice(3).forEach((ilkId: any) => { argv.ilkIds.push(ilkId) })
    await addSeries(argv, hre)
}); */

function nodeUrl(network: any) {
  let infuraKey
  try {
    infuraKey = fs.readFileSync(path.resolve(__dirname, '.infuraKey')).toString().trim()
  } catch(e) {
    infuraKey = ''
  }
  return `https://${network}.infura.io/v3/${infuraKey}`
}

let mnemonic = process.env.MNEMONIC
if (!mnemonic) {
  try {
    mnemonic = fs.readFileSync(path.resolve(__dirname, '.secret')).toString().trim()
  } catch(e){}
}
const accounts = mnemonic ? {
  mnemonic,
}: undefined

let etherscanKey = process.env.ETHERSCANKEY
if (!etherscanKey) {
  try {
    etherscanKey = fs.readFileSync(path.resolve(__dirname, '.etherscanKey')).toString().trim()
  } catch(e){}
}

module.exports = {
  solidity: {
    version: '0.8.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      }
    }
  },
  abiExporter: {
    path: './abis',
    clear: true,
    flat: true,
    // only: [':ERC20$'],
    spacing: 2
  },
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
  gasReporter: {
    enabled: true,
  },
  defaultNetwork: 'hardhat',
  namedAccounts: {
    deployer: 0,
    owner: 1,
    other: 2,
  },
  networks: {
    hardhat: {
      chainId: 31337
    },
    localhost: {
      chainId: 31337
    },
    kovan: {
      accounts,
      gasPrice: 10000000000,
      timeout: 600000,
      url: nodeUrl('kovan')
    },
    goerli: {
      accounts,
      url: nodeUrl('goerli'),
    },
    rinkeby: {
      accounts,
      url: nodeUrl('rinkeby')
    },
    ropsten: {
      accounts,
      url: nodeUrl('ropsten')
    },
    mainnet: {
      accounts,
      timeout: 600000,
      url: nodeUrl('mainnet')
    },
    coverage: {
      url: 'http://127.0.0.1:8555',
    },
  },
  etherscan: {
    apiKey: etherscanKey
  },
}
