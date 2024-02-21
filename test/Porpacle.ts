import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import crypto from "crypto";
import { getAddress, parseGwei,  } from "viem";

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
    it("Write a random result", async function () {
      const { porpacle, owner } = await loadFixture(deployPorpacle);
      // just use some BigInts to mock sha256 hashes for now
      const survey = BigInt(42069);
      const outcome = BigInt(80085);

      const hash = await porpacle.write.recordResult([survey,outcome])

      const Resolutions = await porpacle.getEvents.Resolution();
      expect(Resolutions).to.have.lengthOf(1);
      expect(Resolutions[0].args.survey).to.equal(survey);
    });

    it("Verify a 2 leaf Merkle Tree", async function () {
      const { porpacle, owner } = await loadFixture(deployPorpacle);
      const leafA = 'Hello';
      const leafB = 'World!'
      const encodedLeafA = Buffer.from(leafA);
      const encodedLeafB = Buffer.from(leafB);

      const hashedLeafA = crypto.createHash("sha256").update(encodedLeafA).digest();
      const hashedLeafB = crypto.createHash("sha256").update(encodedLeafB).digest();
      const root = crypto.createHash("sha256").update(Buffer.concat([hashedLeafA, hashedLeafB])).digest();

      console.log("Hashed Leaf A: ", hashedLeafA.toString('hex'));
      console.log("Hashed Leaf B: ", hashedLeafB.toString('hex'));
      console.log("Root: ", root.toString('hex'));
      expect(await porpacle.read.verify([[`0x${hashedLeafB.toString('hex')}`], `0x${root.toString('hex')}`, `0x${hashedLeafA.toString('hex')}`])).to.equal(true);
    });
  });
});
