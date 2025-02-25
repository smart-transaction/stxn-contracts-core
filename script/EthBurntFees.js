import * as dotenv from 'dotenv';
import fetch from 'node-fetch';
import chalk from 'chalk';
import { ethers } from 'ethers';
import * as fs from 'fs';
// import abi from '../out/AshToken.sol/ASHToken.json' assert { type: 'json' };

dotenv.config();

const abiJsonPath = './out/AshToken.sol/ASHToken.json'; 
const abiJson = fs.readFileSync(abiJsonPath, 'utf8'); 
const abi = JSON.parse(abiJson).abi;

const {
    GRAPHQL_URL,
    AUTHORIZATION,
    FROM_BLOCK,
    CUSTOM_QUERY,
    TOKEN_ADDRESS,
    OWNER_PRIVATE_KEY,
    RPC_URL
} = process.env;

const apiUrl = GRAPHQL_URL && GRAPHQL_URL.trim() !== "" ? GRAPHQL_URL : 'https://streaming.bitquery.io/graphql';

if (!apiUrl || !AUTHORIZATION || !OWNER_PRIVATE_KEY || !RPC_URL) {
    throw new Error('Missing one or more required environment variables: GRAPHQL_URL, AUTHORIZATION, TOKEN_ADDRESS, OWNER_PRIVATE_KEY, RPC_URL');
}

const provider = new ethers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(OWNER_PRIVATE_KEY, provider);
const contract = new ethers.Contract(TOKEN_ADDRESS, abi, signer);

// Fetch last minted block from the token contract if FROM_BLOCK is not provided
async function fetchLastMintedBlock() {
    try {
        const lastMintedBlock = await contract.latestMintBlock();
        if (lastMintedBlock.toString() === '0') {
            throw new Error('Last minted block is zero, ensure the token contract has minted tokens.');
        }
        return lastMintedBlock.toString();
    } catch (error) {
        console.error(chalk.red(`Error fetching last minted block: ${error.message}`));
        process.exit(1);
    }
}

// If FROM_BLOCK is not found, fetch it from the contract
const fromBlock = FROM_BLOCK ? FROM_BLOCK : await fetchLastMintedBlock();

// If a custom query is provided, use it; otherwise, use the default query
const defaultQuery = `
  subscription {
    EVM(network: eth) {
      Blocks(
        orderBy: {ascending: Block_Time}
        where: {Block: {Number: {gt: "${fromBlock}"}}}
        ) {
        Block {
          Number
          Date
          BaseFee
          Result {
            Errors
            Gas
          }
        }
      }
    }
  }
`;

const query = CUSTOM_QUERY && CUSTOM_QUERY.trim() !== "" ? CUSTOM_QUERY : defaultQuery;

// Function to fetch blocks from the BitQuery GraphQL API
async function fetchBlocksFromGraphQL() {
    const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${AUTHORIZATION}`,
        },
        body: JSON.stringify({ query: query, variables: {} }),
    });

    const data = await response.json();

    if (data.errors) {
        throw new Error(`Error fetching data: ${JSON.stringify(data.errors)}`);
    }

    return data.data.EVM.Blocks || [];
}

// Function to calculate the total burnt ETH
async function calculateBurntETH() {
    try {
        const blocks = await fetchBlocksFromGraphQL();
        let totalBurntETH = 0;

        blocks.forEach(block => {
            const { BaseFee, Result } = block.Block;

            if (Result.Errors === "") {
                const gas = parseFloat(Result.Gas);
                const baseFee = parseFloat(BaseFee);

                if (!isNaN(gas) && !isNaN(baseFee)) {
                    const burntFees = gas * baseFee;
                    totalBurntETH += burntFees;
                } else {
                    console.error(chalk.red(`Invalid Gas/BaseFee in block ${block.Block.Number}`));
                }
            }
        });

        if (totalBurntETH === 0) {
            console.log(chalk.yellow('No burnt ETH found for the specified blocks.'));
        } else {
            console.log(chalk.green(`Total Burnt ETH after block ${fromBlock} till latest block is: ${totalBurntETH} ETH`));

            // Call the mint function to mint ASH tokens to the owner
            const lastBlock = blocks[blocks.length - 1].Block;
            const lastBlockNumber = lastBlock.Number;
            await mintTokens(totalBurntETH, lastBlockNumber);
        }
    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
        process.exit(1);
    }
}

// Function to mint ASH tokens to the owner
async function mintTokens(totalBurntETH, lastBlockNumber) {
    try {
        // Convert totalBurntETH to the correct token amount
        ethers.par
        const mintAmount = ethers.parseUnits(totalBurntETH.toString(), await contract.decimals());

        // Mint tokens to the owner's address
        const tx = await contract.mint(signer.address, mintAmount, lastBlockNumber);
        // Wait for transaction to be confirmed
        await tx.wait();
        console.log(chalk.green(`Minted ${totalBurntETH} ETH worth of ASH tokens to ${signer.address}`));

    } catch (error) {
        console.error(chalk.red(`Error minting tokens: ${error.message}`));
        process.exit(1);
    }
}

// Start the process
calculateBurntETH();
