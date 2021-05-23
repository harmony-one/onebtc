const bitcoin = require('bitcoinjs-lib');
const ecc = require('tiny-secp256k1');

const BitcoinKeyDerivationMock = artifacts.require("BitcoinKeyDerivationMock");

const Secp256k1_NN = BigInt('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141')
const bn=b=>BigInt(`0x${b.toString('hex')}`);
const toBuffer32 = bn=>{
    let hexStr = bn.toString(16);
    const diff = 64 - hexStr.length;
    hexStr = '0'.repeat(diff) + hexStr;
    return Buffer.from(hexStr, 'hex');
};
const keccak256 = b=>Buffer.from(web3.utils.keccak256(b).slice(2), 'hex');

function derivate(priD, id) {
    const ecPair = bitcoin.ECPair.fromPrivateKey(priD, {compressed:false});
    const scale = keccak256(Buffer.concat([ecPair.publicKey.slice(1), id]));
    if(bn(scale)%Secp256k1_NN == 0) throw "invalid scale";
    const derivatedPub = ecc.pointMultiply(ecPair.publicKey, scale, true);
    const derivatedPriD = bn(priD)*bn(scale)%Secp256k1_NN;
    const derivatedEcPair = bitcoin.ECPair.fromPrivateKey(toBuffer32(derivatedPriD), {compressed:true});
    if(!derivatedEcPair.publicKey.equals(derivatedPub)) throw "impossible error!"
    return derivatedEcPair;
}

contract("BitcoinKeyDerivation:On-Chain Key Derivation Scheme", accounts => {
    it("key derivate", async () => {
        const keyDervation = await BitcoinKeyDerivationMock.new();
        for(let i = 0; i < 100; i++) {
            const ecPair = bitcoin.ECPair.makeRandom({compressed:false});
            // scale = hash(publicKey|i)
            const randomID = bitcoin.crypto.sha256(ecPair.publicKey)
            const derivatedEcPair = derivate(ecPair.privateKey, randomID);
            const pubX = bn(ecPair.publicKey.slice(1, 33));
            const pubY = bn(ecPair.publicKey.slice(33, 65));
            const derivated = await keyDervation.derivate(pubX, pubY, bn(randomID));
            const expectedBase58 =  bitcoin.payments.p2pkh({pubkey:derivatedEcPair.publicKey}).address;
            const actualBase58 = bitcoin.address.toBase58Check(Buffer.from(derivated.slice(2), 'hex'), 0);
            console.log(i, actualBase58, expectedBase58);
            assert.equal(actualBase58, expectedBase58);
        }
    });
}
);