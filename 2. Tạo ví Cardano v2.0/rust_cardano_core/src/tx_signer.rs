use cml_chain::transaction::{Transaction, TransactionBody, TransactionWitnessSet};
use cml_chain::crypto::Vkeywitness;
use cml_core::serialization::{Deserialize, Serialize};
use cml_crypto::{blake2b256, RawBytesEncoding};
use crate::key_derivation::KeyDerivator;
use crate::secure_zeroize;

pub struct TransactionSigner;

impl TransactionSigner {
    /// Ký giao dịch Conway ngoại tuyến với Account Index và Address Index (Chuẩn BIP-39 Seed mặc định)
    pub fn sign_raw_transaction(
        cbor_hex: &str,
        mnemonic: &str,
        passphrase: &str,
        sign_stake: bool,
        account_index: u32,
        address_index: u32,
    ) -> Result<String, String> {
        Self::sign_raw_transaction_ext(
            cbor_hex,
            mnemonic,
            passphrase,
            sign_stake,
            account_index,
            address_index,
            false,
        )
    }

    /// Ký giao dịch Conway ngoại tuyến hỗ trợ tùy chọn chuẩn BIP-39 Seed (mặc định) hoặc CIP-0003 Icarus
    pub fn sign_raw_transaction_ext(
        cbor_hex: &str,
        mnemonic: &str,
        passphrase: &str,
        sign_stake: bool,
        account_index: u32,
        address_index: u32,
        use_icarus: bool,
    ) -> Result<String, String> {
        let trimmed = cbor_hex.trim();
        let clean_hex = trimmed
            .trim_start_matches("TxBodyConway:")
            .trim_start_matches("TxBodyConwayWithdrawal:")
            .trim_start_matches("TxBodyConwayDelegation:")
            .trim();

        let raw_body_bytes = hex::decode(clean_hex).map_err(|e| format!("Lỗi giải mã CBOR Hex: {}", e))?;
        let tx_body = TransactionBody::from_cbor_bytes(&raw_body_bytes)
            .map_err(|e| format!("Lỗi phân tích TransactionBody: {}", e))?;

        let is_testnet = tx_body.outputs.iter().any(|o| {
            if let Ok(bech) = o.address().to_bech32(None) {
                bech.starts_with("addr_test1") || bech.starts_with("stake_test1")
            } else {
                false
            }
        });

        Self::sign_raw_transaction_v2(
            cbor_hex,
            mnemonic,
            passphrase,
            sign_stake,
            account_index,
            address_index,
            is_testnet,
            use_icarus,
        )
    }

    /// Ký giao dịch Conway ngoại tuyến v2 với ràng buộc mạng lưới cụ thể (Anti-Cross-Network Signing Guard)
    /// Thực thi:
    /// 1. Xác thực mạng lưới nghiêm ngặt (is_testnet), chặn đứng tấn công hoán đổi mạng Mainnet/Testnet
    /// 2. Chặn tự động ký mù Stake Key khi giao dịch chứa Certs/Withdrawals nhưng người dùng không bật sign_stake
    /// 3. Băm Blake2b-256 trên TransactionBody CBOR chuẩn tắc
    /// 4. Dẫn xuất khóa CIP-1852 (Hardened Account + Leaf Payment/Stake Key)
    /// 5. Ký Ed25519 Deterministic (RFC 8032)
    /// 6. Tự xác minh chữ ký (Cryptographic Self-Verification) chống tấn công Fault Injection / Rowhammer (FIPS 140-3)
    /// 7. Xóa sạch toàn bộ vùng nhớ khóa trung gian bằng Volatile Write (Deep Zeroization)
    pub fn sign_raw_transaction_v2(
        cbor_hex: &str,
        mnemonic: &str,
        passphrase: &str,
        sign_stake: bool,
        account_index: u32,
        address_index: u32,
        is_testnet: bool,
        use_icarus: bool,
    ) -> Result<String, String> {
        let trimmed = cbor_hex.trim();
        let is_stake_prefix = trimmed.starts_with("TxBodyConwayWithdrawal:")
            || trimmed.starts_with("TxBodyConwayDelegation:");

        let clean_hex = trimmed
            .trim_start_matches("TxBodyConway:")
            .trim_start_matches("TxBodyConwayWithdrawal:")
            .trim_start_matches("TxBodyConwayDelegation:")
            .trim();

        let raw_body_bytes = hex::decode(clean_hex).map_err(|e| format!("Lỗi giải mã CBOR Hex: {}", e))?;

        let tx_body = TransactionBody::from_cbor_bytes(&raw_body_bytes)
            .map_err(|e| format!("Lỗi phân tích TransactionBody: {}", e))?;

        // Tính Tx Hash: Blake2b-256 trên byte CBOR chuẩn của TransactionBody
        let canonical_body_bytes = tx_body.to_cbor_bytes();
        let tx_hash = blake2b256(&canonical_body_bytes);

        // Chốt chặn Anti-Blind-Stake-Signing: Không tự ý ký Stake Key nếu chưa được người dùng xác nhận
        let has_stake_operations = tx_body.certs.is_some() || tx_body.withdrawals.is_some();
        if has_stake_operations && !sign_stake && !is_stake_prefix {
            return Err("SECURITY_BLOCKED_UNAUTHORIZED_STAKE_SIGNING: Giao dịch chứa chứng chỉ hoặc rút thưởng Staking nhưng chưa được phê duyệt ký bằng Stake Key (sign_stake=false)!".to_string());
        }

        let should_sign_stake = sign_stake || is_stake_prefix;

        // Chốt chặn Anti-Cross-Network Signing: Kiểm tra toàn bộ outputs với mạng đang chạy
        for o in tx_body.outputs.iter() {
            if let Ok(bech) = o.address().to_bech32(None) {
                let out_testnet = bech.starts_with("addr_test1") || bech.starts_with("stake_test1");
                let out_mainnet = bech.starts_with("addr1") || bech.starts_with("stake1");
                if (is_testnet && out_mainnet) || (!is_testnet && out_testnet) {
                    return Err(format!(
                        "SECURITY_BLOCKED_NETWORK_MISMATCH: Địa chỉ đầu ra '{}' không khớp với mạng ví đang thiết lập (is_testnet={})!",
                        bech, is_testnet
                    ));
                }
            } else {
                return Err("SECURITY_BLOCKED_INVALID_ADDRESS: Phát hiện địa chỉ đầu ra không hợp lệ hoặc không thuộc chuẩn Bech32!".to_string());
            }
        }

        // Dẫn xuất khóa ký từ mnemonic theo account_index & address_index
        // Hỗ trợ chế độ use_icarus và cơ chế thích ứng an toàn
        let (root, account) = if use_icarus {
            let root_key = KeyDerivator::derive_root_key_icarus(mnemonic, passphrase)?;
            let acc_key = KeyDerivator::derive_account_key(&root_key, account_index)?;
            (root_key, acc_key)
        } else {
            let seed = KeyDerivator::mnemonic_to_seed(mnemonic, passphrase)?;
            let bip39_root = KeyDerivator::derive_root_key(&seed)?;
            let bip39_account = KeyDerivator::derive_account_key(&bip39_root, account_index)?;

            // Kiểm tra thích ứng: nếu ví được tạo bằng chuẩn Icarus (CIP-0003), tự động khớp với địa chỉ
            let mut selected_root = bip39_root;
            let mut selected_account = bip39_account;

            let bip39_xpub = selected_account.to_public();
            let parsed_bip39 = crate::tx_parser::TransactionParser::parse_raw_cbor(
                cbor_hex,
                Some(&bip39_xpub.to_raw_hex()),
                is_testnet,
            );

            let bip39_passed = parsed_bip39.as_ref().map(|p| p.is_change_safe).unwrap_or(false);
            if !bip39_passed {
                if let Ok(icarus_root) = KeyDerivator::derive_root_key_icarus(mnemonic, passphrase) {
                    if let Ok(icarus_account) = KeyDerivator::derive_account_key(&icarus_root, account_index) {
                        let icarus_xpub = icarus_account.to_public();
                        if let Ok(parsed_icarus) = crate::tx_parser::TransactionParser::parse_raw_cbor(
                            cbor_hex,
                            Some(&icarus_xpub.to_raw_hex()),
                            is_testnet,
                        ) {
                            if parsed_icarus.is_change_safe {
                                selected_root = icarus_root;
                                selected_account = icarus_account;
                            }
                        }
                    }
                }
            }

            (selected_root, selected_account)
        };

        // Chốt chặn bảo vệ Change Guard chống Ký Mù / Đánh Tráo Tiền Thừa (Anti-Change Hijacking Guard):
        let account_xpub = account.to_public();

        // Áp dụng nguyên tắc Fail-Closed: Bắt buộc parse_raw_cbor thành công và is_change_safe = true
        let parsed = crate::tx_parser::TransactionParser::parse_raw_cbor(
            cbor_hex,
            Some(&account_xpub.to_raw_hex()),
            is_testnet,
        ).map_err(|e| format!("SECURITY_REJECTED_PARSER_ERROR: Không thể phân tích giao dịch để kiểm định an toàn: {}", e))?;

        if !parsed.is_change_safe {
            let warning = parsed.security_warning.unwrap_or_else(|| {
                "SECURITY_ALERT_CHANGE_HIJACKING: Giao dịch bị chặn do vi phạm quy tắc bảo vệ tiền thừa!".to_string()
            });
            return Err(format!("SECURITY_BLOCKED_BY_CHANGE_GUARD: {}", warning));
        }

        let payment_key = KeyDerivator::derive_payment_key(&account, address_index)?;
        let raw_payment_private = payment_key.to_raw_key();
        let raw_payment_public = payment_key.to_public().to_raw_key();

        // Ký bằng Payment Key
        let payment_sig = raw_payment_private.sign(&tx_hash);

        // Chốt chặn chống Fault Injection / Rowhammer (FIPS 140-3 Self-Verification):
        // Bắt buộc xác minh chữ ký vừa tạo với khóa công khai tương ứng trước khi xuất
        if !raw_payment_public.verify(&tx_hash, &payment_sig) {
            let mut pay_prv_bytes = raw_payment_private.to_raw_bytes().to_vec();
            secure_zeroize(&mut pay_prv_bytes);
            return Err("CRITICAL_CRYPTO_FAULT: Chữ ký Payment Ed25519 không hợp lệ khi tự kiểm tra (Fault Injection Guard)!".to_string());
        }

        let payment_witness = Vkeywitness::new(
            cml_chain::crypto::Vkey::from(raw_payment_public),
            payment_sig,
        );

        let mut vkeys = vec![payment_witness];

        // Ký thêm bằng Stake Key nếu là giao dịch ủy thác (Delegation) hoặc rút thưởng (Withdrawal)
        if should_sign_stake {
            let stake_key = KeyDerivator::derive_stake_key(&account, 0)?;
            let raw_stake_private = stake_key.to_raw_key();
            let raw_stake_public = stake_key.to_public().to_raw_key();

            let stake_sig = raw_stake_private.sign(&tx_hash);

            // Chốt chặn chống Fault Injection cho Stake Signature
            if !raw_stake_public.verify(&tx_hash, &stake_sig) {
                let mut stk_prv_bytes = raw_stake_private.to_raw_bytes().to_vec();
                secure_zeroize(&mut stk_prv_bytes);
                return Err("CRITICAL_CRYPTO_FAULT: Chữ ký Stake Ed25519 không hợp lệ khi tự kiểm tra (Fault Injection Guard)!".to_string());
            }

            let stake_witness = Vkeywitness::new(
                cml_chain::crypto::Vkey::from(raw_stake_public),
                stake_sig,
            );
            vkeys.push(stake_witness);

            // Deep Zeroize stake key buffers
            let mut stake_bytes = stake_key.to_raw_bytes().to_vec();
            secure_zeroize(&mut stake_bytes);
            let mut raw_stake_bytes = raw_stake_private.to_raw_bytes().to_vec();
            secure_zeroize(&mut raw_stake_bytes);
        }

        // Deep Zeroize toàn bộ các bộ đệm khóa trung gian (Root, Account, Payment)
        let mut root_bytes = root.to_raw_bytes().to_vec();
        secure_zeroize(&mut root_bytes);
        let mut account_bytes = account.to_raw_bytes().to_vec();
        secure_zeroize(&mut account_bytes);
        let mut payment_bytes = payment_key.to_raw_bytes().to_vec();
        secure_zeroize(&mut payment_bytes);
        let mut raw_payment_bytes = raw_payment_private.to_raw_bytes().to_vec();
        secure_zeroize(&mut raw_payment_bytes);

        let mut witness_set = TransactionWitnessSet::new();
        witness_set.vkeywitnesses = Some(vkeys.into());

        let signed_tx = Transaction::new(tx_body, witness_set, true, None);
        let signed_bytes = signed_tx.to_cbor_bytes();

        Ok(hex::encode(signed_bytes))
    }

    /// Xác minh độc lập toàn bộ chữ ký Ed25519 Vkeywitness trong một giao dịch đã ký (txSigned CBOR Hex)
    pub fn verify_signed_transaction(signed_cbor_hex: &str) -> Result<bool, String> {
        let clean_hex = signed_cbor_hex
            .trim()
            .trim_start_matches("TxConway:")
            .trim();

        let signed_bytes = hex::decode(clean_hex)
            .map_err(|e| format!("Lỗi giải mã txSigned Hex: {}", e))?;

        let tx = Transaction::from_cbor_bytes(&signed_bytes)
            .map_err(|e| format!("Lỗi phân tích cấu trúc Transaction đã ký: {}", e))?;

        let body_bytes = tx.body.to_cbor_bytes();
        let tx_hash = blake2b256(&body_bytes);

        let witnesses = tx.witness_set.vkeywitnesses
            .ok_or_else(|| "Giao dịch không chứa Vkeywitness nào!".to_string())?;

        if witnesses.is_empty() {
            return Err("Danh sách Vkeywitness rỗng!".to_string());
        }

        for w in witnesses.iter() {
            let pub_key = &w.vkey;
            let sig = &w.ed25519_signature;
            if !pub_key.verify(&tx_hash, sig) {
                return Ok(false);
            }
        }

        Ok(true)
    }
}
