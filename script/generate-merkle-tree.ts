import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";
import readline from "readline";

async function main() {
  const fileStream = fs.createReadStream("whitelist.txt");

  const lines = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity,
  });

  const values: string[][] = [];
  for await (const line of lines) {
    values.push([line, "0"]);
  }

  const tree = StandardMerkleTree.of(values, ["address", "uint256"]);
  console.log("Total whitelisted address:", values.length);
  console.log("Merkle Root:", tree.root);
  const proofs: { address: string; proof: string[] }[] = [];
  for (const [i, v] of tree.entries()) {
    const address = v[0];
    const proof = tree.getProof(i);
    proofs.push({ address, proof });
  }
  fs.writeFileSync("merkle-proofs.json", JSON.stringify(proofs));
}

main();
