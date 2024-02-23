import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { mine } from "@nomicfoundation/hardhat-network-helpers";
import {
  ethHexString,
  padArrayToPowerOfTwo,
  mapBigIntTo256BitNumber,
  computeMerkleRoot,
  convertProofToHex,
} from "./utilities"
import crypto from "crypto";
import { getAddress, parseGwei, } from "viem";

describe("Porpacle", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployPorpacle() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.viem.getWalletClients();

    const porpacle = await hre.viem.deployContract("Porpacle", [], {});

    const publicClient = await hre.viem.getPublicClient();

    return {
      porpacle,
      owner,
      otherAccount,
      publicClient,
    };
  }

  describe("Deployment", function () {
    it("Should set porpoise.network as associated domain.", async function () {
      const { porpacle } = await loadFixture(deployPorpacle);

      expect(await porpacle.read.domains([BigInt(0)])).to.equal("porpoise.network");
    });
  });

  describe("Recording Results", function () {
    it("Can't register a survey too close to deadline.", async function () {
      const { porpacle, owner } = await loadFixture(deployPorpacle);

      const dolphin: string = "When Moon?";
      const alarmclock: number = new Date().getTime();
      const hexAlarmClock: string = mapBigIntTo256BitNumber(BigInt(alarmclock));
      const oracle: string = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
      const option1: string = "Soon";
      const option2: string = "NGMI";

      // hexAlarmClock MUST be encoded as 'hex' not 'binary'
      const paddedComponents: Buffer[] = padArrayToPowerOfTwo([dolphin, hexAlarmClock, oracle, option1, option2], '0');

      const bufferMerkleProof: [Buffer, Buffer[], number] = computeMerkleRoot(paddedComponents, [], 1);
      const stringMerkleProof: [`0x${string}`[], `0x${string}`] = convertProofToHex(bufferMerkleProof[1], bufferMerkleProof[0]);
      const proof: `0x${string}`[] = stringMerkleProof[0];
      const root: `0x${string}` = stringMerkleProof[1];

      await expect(porpacle.write.registerSurvey([proof, root, BigInt(alarmclock)])).to.be.rejectedWith("Deadline must be at least 1 hour in the future");
    });

    it("Proof must refer to correct leaf.", async function () {
      const { porpacle, owner } = await loadFixture(deployPorpacle);

      const dolphin: string = "When Moon?";
      const alarmclock: number = new Date().getTime() + 86400000;
      const hexAlarmClock: string = mapBigIntTo256BitNumber(BigInt(alarmclock));
      const oracle: string = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
      const option1: string = "Soon";
      const option2: string = "NGMI";

      // hexAlarmClock MUST be encoded as 'hex' not 'binary'
      const paddedComponents: Buffer[] = padArrayToPowerOfTwo([dolphin, hexAlarmClock, oracle, option1, option2], '0');

      const bufferMerkleProof: [Buffer, Buffer[], number] = computeMerkleRoot(paddedComponents, [], 2); // here we track the wrong leaf node
      const stringMerkleProof: [`0x${string}`[], `0x${string}`] = convertProofToHex(bufferMerkleProof[1], bufferMerkleProof[0]);
      const proof: `0x${string}`[] = stringMerkleProof[0];
      const root: `0x${string}` = stringMerkleProof[1];

      await expect(porpacle.write.registerSurvey([proof, root, BigInt(alarmclock)])).to.be.rejectedWith("Incorrect timestamp for survey root");
    });

    it("Register a survey only once.", async function () {
      const { porpacle, owner } = await loadFixture(deployPorpacle);

      const dolphin: string = "When Moon?";
      const alarmclock: number = new Date().getTime() + 86400000;
      const hexAlarmClock: string = mapBigIntTo256BitNumber(BigInt(alarmclock));
      const oracle: string = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
      const option1: string = "Soon";
      const option2: string = "NGMI";

      // hexAlarmClock MUST be encoded as 'hex' not 'binary'
      const paddedComponents: Buffer[] = padArrayToPowerOfTwo([dolphin, hexAlarmClock, oracle, option1, option2], '0');

      const bufferMerkleProof: [Buffer, Buffer[], number] = computeMerkleRoot(paddedComponents, [], 1);
      const stringMerkleProof: [`0x${string}`[], `0x${string}`] = convertProofToHex(bufferMerkleProof[1], bufferMerkleProof[0]);
      const proof: `0x${string}`[] = stringMerkleProof[0];
      const root: `0x${string}` = stringMerkleProof[1];

      await porpacle.write.registerSurvey([proof, root, BigInt(alarmclock)]);
      const surveyTimeouts: bigint = await porpacle.read.surveyTimeouts([root]);
      expect(surveyTimeouts).to.equal(BigInt(alarmclock));
      await expect(porpacle.write.registerSurvey([proof, root, BigInt(alarmclock)])).to.be.rejectedWith("Survey already registered");
    });

    it("Record a result only once.", async function () {
      const { porpacle, owner } = await loadFixture(deployPorpacle);

      const dolphin: string = "When Moon?";
      const alarmclock: number = new Date().getTime() + 86400000;
      const hexAlarmClock: string = mapBigIntTo256BitNumber(BigInt(alarmclock));
      const oracle: string = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
      const option1: string = "Soon";
      const option2: string = "NGMI";

      // hexAlarmClock MUST be encoded as 'hex' not 'binary'
      const paddedComponents: Buffer[] = padArrayToPowerOfTwo([dolphin, hexAlarmClock, oracle, option1, option2], '0');

      const bufferMerkleProof: [Buffer, Buffer[], number] = computeMerkleRoot(paddedComponents, [], 1);
      const stringMerkleProof: [`0x${string}`[], `0x${string}`] = convertProofToHex(bufferMerkleProof[1], bufferMerkleProof[0]);
      const proof: `0x${string}`[] = stringMerkleProof[0];
      const root: `0x${string}` = stringMerkleProof[1];

      await porpacle.write.registerSurvey([proof, root, BigInt(alarmclock)]);

      const resultBufferMerkleProof: [Buffer, Buffer[], number] = computeMerkleRoot(paddedComponents, [], 3);
      const resultStringMerkleProof: [`0x${string}`[], `0x${string}`] = convertProofToHex(resultBufferMerkleProof[1], resultBufferMerkleProof[0]);
      await expect(porpacle.write.recordResult([resultStringMerkleProof[0], root, option1])).to.be.rejectedWith("Response deadline has not passed yet.");

      await mine(8650, { interval: 10 }); // mine blocks 1 day into the future
      await porpacle.write.recordResult([resultStringMerkleProof[0], root, option1]);

      const result = await porpacle.read.getResultByReporter([owner.account.address, root]);
      expect(result.outcome).to.equal(ethHexString(paddedComponents[3]));

      await expect(porpacle.write.recordResult([resultStringMerkleProof[0], root, option1])).to.be.rejectedWith("Result has already been recorded");
    });
  });
});
