import * as dotenv from 'dotenv';
import fs from 'fs';
import csvParser from 'csv-parser';
import chalk from 'chalk';

dotenv.config();

const { CSV_FILE_PATH, FROM_DATE, TO_DATE } = process.env;

if (!CSV_FILE_PATH || !FROM_DATE || !TO_DATE) {
  throw new Error('Missing required environment variables: CSV_FILE_PATH, FROM_DATE, TO_DATE');
}

// Convert the FROM_DATE and TO_DATE from string to Date object
const fromDate = new Date(FROM_DATE.replace(' ', 'T')); // Replace space with 'T' to make it ISO 8601
const toDate = new Date(TO_DATE.replace(' ', 'T')); // Replace space with 'T' to make it ISO 8601

// Check if the dates are valid
if (isNaN(fromDate.getTime()) || isNaN(toDate.getTime())) {
  throw new Error('Invalid date format in .env file. Ensure FROM_DATE and TO_DATE are valid date strings.');
}

// Function to read and parse the CSV file, then calculate the total burnt ETH
async function calculateBurntETH() {
  return new Promise((resolve, reject) => {
    const burntFeesColumn = 'Burnt Fees (ETH)';
    const dateColumn = 'DateTime (UTC)';
    let totalBurntETH = 0;
    let foundBlocks = 0;

    fs.createReadStream(CSV_FILE_PATH)
      .pipe(csvParser())
      .on('data', (row) => {
        try {
          // Parse the 'DateTime (UTC)' and convert to a valid timestamp
          const blockDate = row[dateColumn];
          const blockTimestamp = new Date(blockDate.replace(' ', 'T')).getTime(); // Replace space with 'T' to match ISO format
          
          if (isNaN(blockTimestamp)) {
            throw new Error(`Invalid date format in row: ${JSON.stringify(row)}`);
          }

          // Get the burnt fees (ETH) for the current block
          const burntFees = parseFloat(row[burntFeesColumn]);

          if (isNaN(burntFees)) {
            throw new Error(`Invalid burnt fee value in row: ${JSON.stringify(row)}`);
          }

          // Check if the block timestamp is within the given date range
          if (blockTimestamp >= fromDate.getTime() && blockTimestamp <= toDate.getTime()) {
            totalBurntETH += burntFees;
            foundBlocks++;
          }
        } catch (error) {
          // Catch any error in parsing the CSV row
          console.error(chalk.red(`Error processing row: ${error.message}`));
        }
      })
      .on('end', () => {
        if (foundBlocks === 0) {
          reject(new Error(`No blocks found between the specified dates (${fromDate} and ${toDate})`));
        } else {
          resolve(totalBurntETH);
        }
      })
      .on('error', (error) => {
        reject(new Error(`Error reading CSV file: ${error.message}`));
      });
  });
}

// Run the script
async function main() {
  try {
    const totalBurntETH = await calculateBurntETH();
    console.log(chalk.green(`Total Burnt ETH between blocks: ${totalBurntETH} ETH`));
  } catch (error) {
    console.error(chalk.red(`Error: ${error.message}`));
    process.exit(1);
  }
}

main();
