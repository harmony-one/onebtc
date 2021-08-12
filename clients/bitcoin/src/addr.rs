use crate::Error;
use bitcoincore_rpc::bitcoin::secp256k1::SecretKey;
use fixed_hash::construct_fixed_hash;

construct_fixed_hash! {
    pub struct H256(32);
}
construct_fixed_hash! {
    pub struct H160(20);
}

pub fn calculate_deposit_secret_key(
    vault_key: SecretKey,
    issue_key: SecretKey,
) -> Result<SecretKey, Error> {
    let mut deposit_key = vault_key;
    deposit_key.mul_assign(&issue_key[..])?;
    Ok(deposit_key)
}

#[cfg(test)]
mod tests {

    use super::*;
    use bitcoincore_rpc::bitcoin::secp256k1::{PublicKey, Secp256k1, SecretKey};
    use secp256k1::rand::rngs::OsRng;

    #[test]
    fn test_caculate_deposit_secret_key() {
        let secp = Secp256k1::new();
        let mut rng = OsRng::new().unwrap();

        let secure_id = H256::random();
        let secret_key = SecretKey::from_slice(secure_id.as_bytes()).unwrap();

        let vault_secret_key = SecretKey::new(&mut rng);
        let vault_public_key = PublicKey::from_secret_key(&secp, &vault_secret_key);

        let mut deposit_public_key = vault_public_key.clone();
        deposit_public_key
            .mul_assign(&secp, &secret_key[..])
            .unwrap();

        let deposit_secret_key =
            calculate_deposit_secret_key(vault_secret_key, secret_key).unwrap();

        assert_eq!(
            deposit_public_key,
            PublicKey::from_secret_key(&secp, &deposit_secret_key)
        );
    }
}
