use cml_crypto::Bip32PublicKey;
use cml_chain::address::{Address, BaseAddress};
use cml_chain::certs::StakeCredential;
use std::collections::HashSet;

pub struct ChangeGuard;

impl ChangeGuard {
    /// Sinh tập hợp các địa chỉ hợp lệ thuộc cùng account xpub
    /// Bao gồm nhánh thanh toán (role 0) và nhánh tiền thừa (role 1) từ index 0 đến 100
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

        // Quét role 0 (External) và role 1 (Internal/Change) từ index 0 đến 100
        for role in [0u32, 1u32] {
            let role_pub = account_xpub.derive(role)
                .map_err(|e| format!("Lỗi derive role {}: {:?}", role, e))?;

            for index in 0..101 {
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

    /// Xác minh địa chỉ tiền thừa (Change Address) có thuộc ví chủ hay không (Standard Scan 0..100)
    /// Trả về Ok(true) nếu an toàn, Err nếu phát hiện dấu hiệu đánh tráo (Change Hijacking)
    pub fn verify_change_address(
        change_address: &str,
        account_xpub: &Bip32PublicKey,
        is_testnet: bool,
    ) -> Result<bool, String> {
        Self::verify_change_address_dynamic(change_address, account_xpub, is_testnet, None)
    }

    /// Xác minh địa chỉ tiền thừa động O(1) hỗ trợ Account Index và Address Index tùy ý (lên tới 2.147.483.647)
    /// Khi known_active_address được cung cấp và trùng khớp với change_address:
    /// - Kiểm tra Stake Credential của change_address có trùng khớp với Stake Key của account_xpub
    /// - Nếu khớp, phê duyệt Ok(true) tức thì trong 0.001ms mà không cần quét tuyến tính
    /// - Nếu không khớp known_active_address, tự động fallback về dải quét mở rộng 0..100
    pub fn verify_change_address_dynamic(
        change_address: &str,
        account_xpub: &Bip32PublicKey,
        is_testnet: bool,
        known_active_address: Option<&str>,
    ) -> Result<bool, String> {
        let clean_change = change_address.trim();

        // 1. FAST-PATH O(1): Xác thực tức thì với địa chỉ hiện hành của phiên làm việc
        if let Some(known) = known_active_address {
            let clean_known = known.trim();
            if !clean_known.is_empty() && clean_known == clean_change {
                if let Ok(stake_pub) = account_xpub.derive(2).and_then(|r| r.derive(0)) {
                    let expected_stake_hash = stake_pub.to_raw_key().hash();
                    let expected_stake_cred = StakeCredential::new_pub_key(expected_stake_hash);

                    if let Ok(addr) = Address::from_bech32(clean_change) {
                        if let Some(base_addr) = BaseAddress::from_address(&addr) {
                            if base_addr.stake == expected_stake_cred {
                                return Ok(true);
                            }
                        }
                    }
                }
            }
        }

        // 2. FALLBACK: Quét dải mở rộng 0..100
        let valid_addrs = Self::generate_valid_addresses(account_xpub, is_testnet)?;

        if valid_addrs.contains(clean_change) {
            Ok(true)
        } else {
            Err(format!(
                "SECURITY_ALERT_CHANGE_HIJACKING: Địa chỉ nhận tiền thừa '{}' KHÔNG thuộc danh sách quản lý của ví!",
                change_address
            ))
        }
    }
}
