const createHash = require('create-hash')
var reverse = require('buffer-reverse')

function flipBytes(bytesLE){
    var bytesBE = bytesLE.toString(16).match(/.{1,2}/g);
    bytesBE.push("0X");
    return bytesBE.reverse().join("").toString(16);
}

function sha256(buffer) {
    return createHash('sha256').update(buffer).digest();
}

// Expecting leading "0x"
function dblSha256Flip(blockHeader){
    console.log(blockHeader)
    var buffer = Buffer.from(blockHeader.substr(2), "hex")
    console.log("Buffer: " + buffer.toString("hex"))
    return "0x" + reverse(sha256(sha256(buffer))).toString("hex")
}

// Expecting leading "0x"
function flipBytes(hexString){
    var buffer = Buffer.from(hexString.substr(2), "hex");
    return "0x" + reverse(buffer).toString("hex")
}

function nBitsToTarget(nBits){
    var exp = nBits >> 24;
    var c = nBits & 0xffffff;
    var target = (c * 2**(8*(exp - 3)));
    return target;
}



var exp = 26959535291011309493156476344723991336010898738574164086137773096960;
var res = nBitsToTarget("0x1d00ffff")
console.log(res)
console.log(exp == res)