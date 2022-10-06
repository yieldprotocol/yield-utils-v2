import { ethers } from "hardhat";
import { EmergencyBrake__factory } from "../typechain";

(async () => {
  const provider = new ethers.providers.JsonRpcProvider(
    "https://eth-mainnet.g.alchemy.com/v2/hJjFfMayAD0ty8fkQh3PR33iXG3g8MaK"
  );

  // emergency brake contract addr
  const governanceCloakAddress = "0xaa7B33685e9730B4D700b8F3F190EcA5EC4cf106";
  // emergency brake contract instance
  const EmergencyBrake = EmergencyBrake__factory.connect(
    governanceCloakAddress,
    provider
  );

  const fromBlock = "0xCD44C3";
  const toBlock = "latest";

  // get all planned events
  const plannedEventsFilter = EmergencyBrake.filters.Planned();
  const events = await EmergencyBrake.queryFilter(
    plannedEventsFilter,
    fromBlock,
    toBlock
  );

  // just get what we need
  const txHashes = events.map(({ args: { txHash } }) => ({
    txHash,
  }));

  const plans = await Promise.all(
    txHashes.map(async ({ txHash }) => {
      const { state, target, permissions } = await EmergencyBrake.plans(txHash);

      const decodedPermissions: { contact: string; signatures: string[] }[] =
        ethers.utils.defaultAbiCoder
          .decode(["(address contact,bytes4[] signatures)[]"], permissions)
          .flat(1);

      const _permissions = decodedPermissions.flatMap(
        ({ contact, signatures }) =>
          signatures.map((s) => ({ contact, signature: s }))
      );

      return { state, target, permissions: _permissions };
    })
  );

  plans.map((p) => {
    console.log("🦄 ~ file: emergencyBrakeOldPlans.ts ~ line 53 ~ p", p);
  });

  return plans;
})();
