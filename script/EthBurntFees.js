import * as dotenv from 'dotenv';
import fetch from 'node-fetch';
import chalk from 'chalk';

dotenv.config();

const { GRAPHQL_URL, AUTHORIZATION, FROM_BLOCK, TO_BLOCK, CUSTOM_QUERY } = process.env;
const apiUrl = GRAPHQL_URL && GRAPHQL_URL.trim() !== "" ? GRAPHQL_URL : 'https://streaming.bitquery.io/graphql';

if (!apiUrl || !AUTHORIZATION || !FROM_BLOCK || !TO_BLOCK) {
    throw new Error('Missing one or more required environment variables: GRAPHQL_URL, AUTHORIZATION, FROM_BLOCK, TO_BLOCK');
}

// If a custom query is provided, use it; otherwise, use the default query
const defaultQuery = `
  subscription {
    EVM(network: eth) {
      Blocks(
        orderBy: {ascending: Block_Time}
        where: {Block: {Number: {gt: "${FROM_BLOCK}", le: "${TO_BLOCK}"}}}
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
            console.log(chalk.green(`Total Burnt ETH between blocks ${FROM_BLOCK} and ${TO_BLOCK}: ${totalBurntETH} ETH`));
        }
    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
        process.exit(1);
    }
}

calculateBurntETH();
