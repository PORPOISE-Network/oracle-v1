import crypto from "crypto";

export function ethHexString(myBuffer: Buffer): `0x${string}` { return `0x${myBuffer.toString('hex')}`; }

export function convertProofToHex(proof: Buffer[], root: Buffer): [`0x${string}`[], `0x${string}`] {
    const proofLength: number = proof.length;

    let stringProof: `0x${string}`[] = [];
    for (let i = 0; i < proofLength; i++) {
        stringProof.push(ethHexString(proof[i]));
    }

    return [stringProof, ethHexString(root)];
}

export function computeMerkleRoot(leafs: Buffer[], proof: Buffer[], tracker: number): [Buffer, Buffer[], number] {
    // Base case: if there's only one element, return its hash
    if (leafs.length === 1) {
        return [leafs[0], proof, tracker];
    }

    // Recursive case: compute hash of pairs until a single hash is obtained
    const pairedHashes: Buffer[] = [];
    let j: number = 0;
    for (let i = 0; i < leafs.length; i += 2, j++) {
        const a = leafs[i];
        const b = leafs[i + 1];
        if (tracker === i) {
            proof.push(b);
            tracker = j;
        } else if (tracker === (i + 1)) {
            proof.push(a);
            tracker = j;
        }
        const pairHash = (a.toString('hex') < b.toString('hex')) ?
            crypto.createHash("sha256").update(Buffer.from(Buffer.concat([a, b]))).digest() :
            crypto.createHash("sha256").update(Buffer.from(Buffer.concat([b, a]))).digest();
        pairedHashes.push(pairHash);
    }

    // Recursively compute the Merkle root for the paired hashes
    return computeMerkleRoot(pairedHashes, proof, tracker);
}

export function padArrayToPowerOfTwo(arr: string[], paddingValue: string): Buffer[] {
    // Check if the array length is already a power of 2
    if ((arr.length & (arr.length - 1)) === 0) {
        return arr.map((elem: string, index: number) => {
            if (index === 1) {
                // for the time element, it must be hex encoded
                return crypto.createHash("sha256").update(Buffer.from(elem, 'hex')).digest();
            } else {
                return crypto.createHash("sha256").update(Buffer.from(elem, 'binary')).digest();
            }
        }); // Array length is already a power of 2, no padding needed
    }

    // Calculate the next power of 2 greater than the current length
    const nextPowerOfTwo = Math.pow(2, Math.ceil(Math.log2(arr.length)));

    // Calculate the number of elements to pad
    const paddingCount = nextPowerOfTwo - arr.length;

    // Pad the array with the specified paddingValue (default is undefined)
    return arr.concat(new Array(paddingCount).fill(paddingValue)).map((elem: string, index: number) => {
        if (index === 1) {
            // for the time element, it must be hex encoded
            return crypto.createHash("sha256").update(Buffer.from(elem, 'hex')).digest();
        } else {
            return crypto.createHash("sha256").update(Buffer.from(elem, 'binary')).digest();
        }
    });
}

export function mapBigIntTo256BitNumber(bigIntValue: bigint): string {
    // Convert the BigInt to a hexadecimal string
    let hexString = bigIntValue.toString(16);

    // Pad the hexadecimal string with zeros to ensure it is 64 characters long
    while (hexString.length < 64) {
        hexString = '0' + hexString;
    }

    return hexString;
}
