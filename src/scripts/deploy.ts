import {
    Account,
    CallData,
    Contract,
    RpcProvider,
    stark,
    shortString,
  } from "starknet";
  import * as dotenv from "dotenv";
  import { getCompiledCode } from "./utils";
  
  dotenv.config();
  
  async function main() {
    const provider = new RpcProvider({
      nodeUrl: "https://free-rpc.nethermind.io/sepolia-juno",
    });
  
    // initialize existing predeployed account 0
    console.log("ACCOUNT_ADDRESS=", process.env.DEPLOYER_ADDRESS);
    // console.log("ACCOUNT_PRIVATE_KEY=", process.env.DEPLOYER_PRIVATE_KEY);
    const privateKey0 = process.env.DEPLOYER_PRIVATE_KEY ?? "";
    const accountAddress0: string = process.env.DEPLOYER_ADDRESS ?? "";
  
   
    console.log("Provider connected to Starknet");
  
    const account0 = new Account(
      provider,
      accountAddress0,
      privateKey0
    );
  
    // Declare & deploy contract
    let sierraCode, casmCode;
  
    try {
      ({ sierraCode, casmCode } = await getCompiledCode(
        "CLTBase"
      ));
    } catch (error: any) {
      console.log("Failed to read contract files");
      process.exit(1);
    }
    const myCallData = new CallData(sierraCode.abi);
    const feeParams = {
        lp_automation_fee: { low: "0", high: "0" },
        strategy_creation_fee: { low: "0", high: "0" },
        protocol_fee_on_management: { low: "0", high: "0" },
        protocol_fee_on_performance: { low: "0", high: "0" }
    };
    
    const constructor = myCallData.compile("constructor", {
        owner: accountAddress0,
        governance_fee_handler_address:"0x075d8d86ca963d8bef34cf755a586e1a044e0eb7cd3e0afd0185e1208191eeae",
    });
    
    // console.log("Nonce", account0);
  
    const deployResponse = await account0.declareAndDeploy({
      contract: sierraCode,
      casm: casmCode,
      constructorCalldata: constructor,
      salt: stark.randomAddress(),
    });
    // Connect the new contract instance :
    const _contract = new Contract(
      sierraCode.abi,
      deployResponse.deploy.contract_address,
      provider
    );
    console.log(
      `✅ Contract has been deploy with the address: ${_contract.address}`
    );
  }
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });