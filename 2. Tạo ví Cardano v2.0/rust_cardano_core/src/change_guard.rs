use cml_crypto::Bip32PublicKey;
use cml_chain::address::BaseAddress;
use cml_chain::certs::StakeCredential;
use std::collections::HashSet;

pub struct ChangeGuard;

impl ChangeGuard {
    /// Sinh tập hợp các địa chỉ hợp lệ thuộc cùng account xpub
    /// Bao gồm nhánh thanh toán (role 0) và nhánh tiền thừa (role 1) từ index 0 đến 50
    pub fn generate_valid_addresses(
        account_xpub: &Bip32PublicKey,
        is_testnet: bool,
    ) -> Result<HashSet<String>, String> {
        let mut valid_addrs = HashSet::new();

        let stake_pub = account_xpub.derive(2)
            .map_err(|e| format!("Lỗi derive stake role 2: {:?}", e))?
            .derive(0)
            .map_err(|e| format!("Lỗi derive stake index 0: {:?}", e))?;
        let stake_key_hash = stake_pub.to_raw_key().hash();

        let network_id = if is_testnet { 0 } else { 1 };

        // Quét role 0 (External) và role 1 (Internal/Change) từ index 0 đến 50
        for role in [0u32, 1u32] {
            let role_pub = account_xpub.derive(role)
                .map_err(|e| format!("Lỗi derive role {}: {:?}", role, e))?;

            for index in 0..51 {
                let key_pub = role_pub.derive(index)
                    .map_err(|e| format!("Lỗi derive index {}: {:?}", index, e))?;
                let payment_key_hash = key_pub.to_raw_key().hash();

                let base_addr = BaseAddress::new(
                    network_id,
                    StakeCredential::new_pub_key(payment_key_hash),
                    StakeCredential::new_pub_key(stake_key_hash),
                );

                if let Ok(bech32) = base_addr.to_address().to_bech32(None) {
                    valid_addrs.insert(bech32);
                }
            }
        }

        Ok(valid_addrs)
    }

    /// Xác minh địa chỉ tiền thừa (Change Address) có thuộc ví chủ hay không
    /// Trả về Ok(true) nếu an toàn, Err nếu phát hiện dấu hiệu đánh tráo (Change Hijacking)
    pub fn verify_change_address(
        change_address: &str,
        account_xpub: &Bip32PublicKey,
        is_testnet: bool,
    ) -> Result<bool, String> {
        let valid_addrs = Self::generate_valid_addresses(account_xpub, is_testnet)?;

        if valid_addrs.contains(change_address) {
            Ok(true)
        } else {
            Err(format!(
                "SECURITY_ALERT_CHANGE_HIJACKING: Địa chỉ nhận tiền thừa '{}' KHÔNG thuộc danh sách quản lý của ví!",
                change_address
            ))
        }
    }
}
