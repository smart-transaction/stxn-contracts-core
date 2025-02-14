const fs = require("fs");
const csv = require("csv-parser");
const { MerkleTree } = require("merkletreejs");
const { ethers } = require("ethers");
const keccak256 = require('keccak256');

const csvFilePath = "tokenholders.csv";
const jsonFilePath = "merkle.json";

async function readCSV(filePath) {
    return new Promise((resolve, reject) => {
        const results = [];
        fs.createReadStream(filePath)
            .pipe(csv())
            .on("data", (data) => results.push(data))
            .on("end", () => resolve(results))
            .on("error", (err) => reject(err));
    });
}

function hashLeaf(id, account, amount) {
    return ethers.solidityPackedKeccak256(["uint256", "address", "uint256"], [id, account, amount]);
}

async function generateMerkle() {
    try {
        const data = await readCSV(csvFilePath);

        const airdropData = data.map((row, index) => ({
            id: index,
            account: row.HolderAddress.trim(),
            amount: parseInt(row.Balance.replace(/,/g, ""), 10)
        }));

        const leaves = airdropData.map(({ id, account, amount }) => hashLeaf(id, account, amount));
        const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        const merkleRoot = merkleTree.getRoot().toString('hex');
       
        const claims = {};
        airdropData.forEach(({ id, account, amount }) => {
            const leaf = hashLeaf(id, account, amount);
            console.log(leaf,"\n");
            const proof = merkleTree.getHexProof(leaf);
            console.log(proof);
            claims[account] = { id, amount: amount.toString(), proof };
        });

        const output = { merkleRoot, claims };
        fs.writeFileSync(jsonFilePath, JSON.stringify(output, null, 4));
        console.log(`📂 Saved to: ${jsonFilePath}`);
    } catch (error) {
        console.error("❌ Error generating Merkle Tree:", error);
    }
}

generateMerkle();
