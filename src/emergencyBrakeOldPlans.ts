// Setup: npm install alchemy-sdk

import { IEmergencyBrake } from "../out/EmergencyBrake.sol/IEmergencyBrake.json";
import { ethers } from 'hardhat';

const config = {
    apiKey: "hJjFfMayAD0ty8fkQh3PR33iXG3g8MaK",
    network: Network.ETH_MAINNET 
}

const alchemy = new Alchemy(config);

const provider = new ethers.providers.JsonRpcProvider('https://eth-mainnet.g.alchemy.com/v2/hJjFfMayAD0ty8fkQh3PR33iXG3g8MaK');
const signer = provider.getSigner();

const contractAddress = "0xaa7B33685e9730B4D700b8F3F190EcA5EC4cf106";
const from = "0xCD44C3"
const to = "latest"

const data = await provider.getLogs({
    address: contractAddress,
    fromBlock: from,
    toBlock: to,
    topics: ['0x37ac5de7a90f04f7f1c8ac1abdfce792e13bf888d85cff4be327bc4ea2ea8169']
})

class Plan  {
    txHash = ""
    target = ""
}

var plans: Plan[] = [];

for(var i = 0; i < data.length; i++) {
    
    let txHash_ = data[i].topics[1];
    let address_ = data[i].topics[2];
    let plan_ = new Plan();
    plan_.txHash = txHash_;
    plan_.target = address_;
    plans.push(plan_);
}

const governanceCloakAddress = "0xaa7B33685e9730B4D700b8F3F190EcA5EC4cf106";


const governanceCloak = new ethers.Contract(
    governanceCloakAddress,
    IEmergencyBrake.abi,
    signer
)



class OldPlan {
    
    state = ""
    target = ""
    permissions = []
}

var OldPlans: OldPlan[] = []

for(var i = 0; i < plans.length; i++) {
    let txHash_ = plans[i].txHash;
    OldPlans[i].state = governanceCloak.plans(txHash_).state;
    OldPlans[i].target = governanceCloak.plans(txHash_).contact;
    var _permissions = governanceCloak.plans(txHash_).permissions;
    OldPlans[i].permissions = ethers.utils.defaultAbiCoder
    .decode(["address contact,bytes4[] signatures[]"], _permissions)
    .flat(1);
}

class Permission {
    contact = ""
    signature = ""
}

class NewPlan {

    target = ""
    permissions: Permission[] = []
}

var newPlans: NewPlan[] = []

for(var i = 0; i < OldPlans.length; i++) {
    if(OldPlans[i].state == "PLANNED"){
        
        for(var j = 0; j < OldPlans[i].permissions.length; j++) {
            for(var k = 0; k < OldPlans[i].permissions[j].signatures.length; k++) {
                const new Permission = (
                    OldPlans[i].permissions[j].contact,
                    )
            }
        }
    }

}