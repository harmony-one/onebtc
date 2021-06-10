const bitcoin = require('bitcoinjs-lib')

//const ecp = bitcoin.ECPair.makeRandom();
//const p2pkh = bitcoin.payments.p2pkh({pubkey:ecp.publicKey})
//console.log(tx)

const Number2Buffer = num=>{ // bigendia
    let str = num.toString(16);
    if(str.length&1) str='0'+str;
    return Buffer.from(str, 'hex');
}

function issueTxMock(issueId, vaultAddress, issueValue) {
    const valutScript = bitcoin.address.toOutputScript(vaultAddress);
    const tx = new bitcoin.Transaction();
    tx.addInput(Buffer.alloc(32, 1), 0, 4294967295, Buffer.alloc(32));
    tx.addOutput(valutScript, issueValue)
    if(issueId != undefined){
        const OpData = Number2Buffer(issueId);
        const embed = bitcoin.payments.embed({ data: [OpData] });
        tx.addOutput(embed.output, 0)
    }
    return tx;
}

module.exports = {
    issueTxMock
}