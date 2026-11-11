use cml_chain::transaction::TransactionBody;
use cml_chain::certs::Certificate;
use cml_core::serialization::{Deserialize, Serialize as CmlSerialize};
use serde::{Serialize, Deserialize as SerdeDeserialize};
use crate::change_guard::ChangeGuard;
use cml_crypto::{blake2b256, Bip32PublicKey, RawBytesEncoding};

#[derive(Debug, Serialize, SerdeDeserialize, Clone)]
pub struct ParsedTokenItem {
    pub policy_id: String,
    pub asset_name_hex: String,
    pub asset_name_utf8: String,
    pub quantity: u64,
}

#[derive(Debug, Serialize, SerdeDeserialize, Clone)]
pub struct ParsedOutput {
    pub address: String,
    pub lovelace: u64,
    pub is_change: bool,
    pub is_change_verified: bool,
    #[serde(default)]
    pub tokens: Vec<ParsedTokenItem>,
}

#[derive(Debug, Serialize, SerdeDeserialize, Clone)]
pub struct ParsedTransaction {
    pub fee_lovelace: u64,
    pub ttl: Option<u64>,
    pub inputs_count: usize,
    pub outputs: Vec<ParsedOutput>,
    pub recipient_address: String,
    pub send_lovelace: u64,
    pub change_lovelace: u64,
    pub is_change_safe: bool,
    pub security_warning: Option<String>,
    #[serde(default)]
    pub tx_hash_hex: String,
    #[serde(default)]
    pub has_certs: bool,
    #[serde(default)]
    pub certs_count: usize,
    #[serde(default)]
    pub certificates_summary: Vec<String>,
    #[serde(default)]
    pub has_withdrawals: bool,
    #[serde(default)]
    pub withdrawals_total_lovelace: u64,
    #[serde(default)]
    pub withdrawals_summary: Vec<String>,
    #[serde(default)]
    pub requires_stake_signing: bool,
}

pub struct TransactionParser;

impl TransactionParser {
    pub fn parse_raw_cbor(
        cbor_hex: &str,
        account_xpub_hex: Option<&str>,
        is_testnet: bool,
    ) -> Result<ParsedTransaction, String> {
        let trimmed_input = cbor_hex.trim();
        let is_withdrawal_prefix = trimmed_input.starts_with("TxBodyConwayWithdrawal:");
        let is_delegation_prefix = trimmed_input.starts_with("TxBodyConwayDelegation:");

        let clean_hex = trimmed_input
            .trim_start_matches("TxBodyConway:")
            .trim_start_matches("TxBodyConwayWithdrawal:")
            .trim_start_matches("TxBodyConwayDelegation:")
            .trim();

        let bytes = hex::decode(clean_hex).map_err(|e| format!("Lỗi giải mã CBOR Hex: {}", e))?;

        let tx_body = TransactionBody::from_cbor_bytes(&bytes)
            .map_err(|e| format!("Lỗi phân tích cú pháp TransactionBody Conway: {}", e))?;

        // Đồng bộ hóa tx_hash chuẩn xác với TransactionBody canonical bytes
        let canonical_body_bytes = tx_body.to_cbor_bytes();
        let tx_hash_hex = hex::encode(blake2b256(&canonical_body_bytes));
        let fee_lovelace = tx_body.fee;
        let ttl = tx_body.ttl;
        let inputs_count = tx_body.inputs.len();

        let account_xpub = if let Some(xpub_str) = account_xpub_hex {
            if !xpub_str.trim().is_empty() {
                let xpub_bytes = hex::decode(xpub_str.trim()).map_err(|e| format!("Lỗi xpub hex: {}", e))?;
                Some(Bip32PublicKey::from_raw_bytes(&xpub_bytes).map_err(|e| format!("Lỗi Bip32PublicKey: {:?}", e))?)
            } else {
                None
            }
        } else {
            None
        };

        // Trích xuất stake key hash dự kiến của ví nếu có account_xpub (m/1852'/1815'/account'/2/0)
        let expected_stake_hash = if let Some(ref xpub) = account_xpub {
            match xpub.derive(2).and_then(|r| r.derive(0)) {
                Ok(stake_pub) => Some(stake_pub.to_raw_key().hash()),
                Err(_) => None,
            }
        } else {
            None
        };

        let mut is_change_safe = true;
        let mut security_warnings: Vec<String> = Vec::new();

        // 1. Phân tích toàn diện Certificates (Chống ký mù chứng chỉ Conway)
        let mut has_certs = false;
        let mut certs_count = 0usize;
        let mut certificates_summary = Vec::new();
        let mut has_unauthorized_cert = false;

        if let Some(ref certs) = tx_body.certs {
            has_certs = !certs.is_empty();
            certs_count = certs.len();
            for cert in certs.iter() {
                match cert {
                    Certificate::StakeRegistration(sr) => {
                        if let Some(ref expected_hash) = expected_stake_hash {
                            if sr.stake_credential != cml_chain::certs::StakeCredential::new_pub_key(*expected_hash) {
                                is_change_safe = false;
                                security_warnings.push("SECURITY_ALERT_UNAUTHORIZED_CERTIFICATE: Chứng chỉ đăng ký Stake Key không thuộc ví của bạn!".to_string());
                            }
                        }
                        certificates_summary.push("Đăng ký Khóa Stake (StakeRegistration)".to_string());
                    }
                    Certificate::RegCert(reg) => {
                        if let Some(ref expected_hash) = expected_stake_hash {
                            if reg.stake_credential != cml_chain::certs::StakeCredential::new_pub_key(*expected_hash) {
                                is_change_safe = false;
                                security_warnings.push("SECURITY_ALERT_UNAUTHORIZED_CERTIFICATE: Chứng chỉ đăng ký Stake Key không thuộc ví của bạn!".to_string());
                            }
                        }
                        certificates_summary.push(format!(
                            "Đăng ký Khóa Stake Conway (RegCert - Cọc: {:.2} ADA)",
                            reg.deposit as f64 / 1_000_000.0
                        ));
                    }
                    Certificate::StakeDelegation(del) => {
                        if let Some(ref expected_hash) = expected_stake_hash {
                            if del.stake_credential != cml_chain::certs::StakeCredential::new_pub_key(*expected_hash) {
                                is_change_safe = false;
                                security_warnings.push("SECURITY_ALERT_UNAUTHORIZED_CERTIFICATE: Chứng chỉ ủy thác Stake Pool không thuộc ví của bạn!".to_string());
                            }
                        }
                        let pool_hex = hex::encode(del.pool.to_raw_bytes());
                        certificates_summary.push(format!("Ủy thác Stake Pool (Pool Hash: {}...)", &pool_hex[..16.min(pool_hex.len())]));
                    }
                    Certificate::VoteDelegCert(vd) => {
                        if let Some(ref expected_hash) = expected_stake_hash {
                            if vd.stake_credential != cml_chain::certs::StakeCredential::new_pub_key(*expected_hash) {
                                is_change_safe = false;
                                security_warnings.push("SECURITY_ALERT_UNAUTHORIZED_CERTIFICATE: Chứng chỉ ủy thác DRep không thuộc ví của bạn!".to_string());
                            }
                        }
                        certificates_summary.push("Ủy quyền Biểu quyết Quản trị DRep (VoteDelegCert)".to_string());
                    }
                    Certificate::StakeVoteDelegCert(sv) => {
                        if let Some(ref expected_hash) = expected_stake_hash {
                            if sv.stake_credential != cml_chain::certs::StakeCredential::new_pub_key(*expected_hash) {
                                is_change_safe = false;
                                security_warnings.push("SECURITY_ALERT_UNAUTHORIZED_CERTIFICATE: Chứng chỉ ủy thác Kép không thuộc ví của bạn!".to_string());
                            }
                        }
                        let pool_hex = hex::encode(sv.pool.to_raw_bytes());
                        certificates_summary.push(format!(
                            "Ủy thác Kép Stake Pool ({}...) & DRep (StakeVoteDelegCert)",
                            &pool_hex[..16.min(pool_hex.len())]
                        ));
                    }
                    Certificate::StakeRegDelegCert(srd) => {
                        if let Some(ref expected_hash) = expected_stake_hash {
                            if srd.stake_credential != cml_chain::certs::StakeCredential::new_pub_key(*expected_hash) {
                                is_change_safe = false;
                                security_warnings.push("SECURITY_ALERT_UNAUTHORIZED_CERTIFICATE: Chứng chỉ đăng ký & ủy thác không thuộc ví của bạn!".to_string());
                            }
                        }
                        let pool_hex = hex::encode(srd.pool.to_raw_bytes());
                        certificates_summary.push(format!(
                            "Đăng ký & Ủy thác Stake Pool ({}..., Cọc: {:.2} ADA)",
                            &pool_hex[..16.min(pool_hex.len())],
                            srd.deposit as f64 / 1_000_000.0
                        ));
                    }
                    Certificate::VoteRegDelegCert(vrd) => {
                        if let Some(ref expected_hash) = expected_stake_hash {
                            if vrd.stake_credential != cml_chain::certs::StakeCredential::new_pub_key(*expected_hash) {
                                is_change_safe = false;
                                security_warnings.push("SECURITY_ALERT_UNAUTHORIZED_CERTIFICATE: Chứng chỉ đăng ký & ủy quyền DRep không thuộc ví của bạn!".to_string());
                            }
                        }
                        certificates_summary.push(format!(
                            "Đăng ký & Ủy quyền DRep (Cọc: {:.2} ADA)",
                            vrd.deposit as f64 / 1_000_000.0
                        ));
                    }
                    Certificate::StakeVoteRegDelegCert(svrd) => {
                        if let Some(ref expected_hash) = expected_stake_hash {
                            if svrd.stake_credential != cml_chain::certs::StakeCredential::new_pub_key(*expected_hash) {
                                is_change_safe = false;
                                security_warnings.push("SECURITY_ALERT_UNAUTHORIZED_CERTIFICATE: Chứng chỉ đăng ký & ủy thác Kép không thuộc ví của bạn!".to_string());
                            }
                        }
                        certificates_summary.push(format!(
                            "Đăng ký & Ủy thác Kép Pool + DRep (Cọc: {:.2} ADA)",
                            svrd.deposit as f64 / 1_000_000.0
                        ));
                    }
                    Certificate::StakeDeregistration(_) | Certificate::UnregCert(_) => {
                        has_unauthorized_cert = true;
                        certificates_summary.push("CẢNH BÁO: Hủy đăng ký Khóa Stake (StakeDeregistration/UnregCert)".to_string());
                    }
                    _ => {
                        has_unauthorized_cert = true;
                        certificates_summary.push("CẢNH BÁO: Chứng chỉ quản trị/hệ thống đặc biệt".to_string());
                    }
                }
            }
        }

        // 2. Phân tích toàn diện Withdrawals (Rút thưởng Staking)
        let mut has_withdrawals = false;
        let mut withdrawals_total_lovelace = 0u64;
        let mut withdrawals_summary = Vec::new();

        if let Some(ref withdrawals) = tx_body.withdrawals {
            has_withdrawals = !withdrawals.is_empty();
            for (reward_acc, &coin) in withdrawals.iter() {
                withdrawals_total_lovelace = withdrawals_total_lovelace.saturating_add(coin);
                let stake_bech32 = reward_acc
                    .clone()
                    .to_address()
                    .to_bech32(None)
                    .unwrap_or_else(|_| hex::encode(reward_acc.clone().to_address().to_raw_bytes()));
                withdrawals_summary.push(format!(
                    "Rút {:.6} ADA từ {}",
                    coin as f64 / 1_000_000.0,
                    stake_bech32
                ));

                // Chốt chặn xác thực quyền sở hữu địa chỉ Stake rút thưởng (Anti-Foreign Stake Drain)
                if let Some(ref expected_hash) = expected_stake_hash {
                    let expected_cred = cml_chain::certs::StakeCredential::new_pub_key(*expected_hash);
                    if reward_acc.payment != expected_cred {
                        is_change_safe = false;
                        security_warnings.push(format!(
                            "SECURITY_ALERT_UNAUTHORIZED_WITHDRAWAL: Địa chỉ Stake rút thưởng '{}' KHÔNG thuộc ví của bạn!",
                            stake_bech32
                        ));
                    }
                }
            }
        }

        let requires_stake_signing = has_certs || has_withdrawals || is_delegation_prefix || is_withdrawal_prefix;

        let mut outputs = Vec::new();
        let mut recipient_address = String::new();
        let mut send_lovelace = 0u64;
        let mut change_lovelace = 0u64;

        // 3. Kiểm tra các trường Conway nhạy cảm chống Blind Signing (Mint, Treasury Donation, Collateral, Scripts)
        if let Some(donation) = tx_body.donation {
            let donation_val: u64 = donation.into();
            if donation_val > 0 {
                is_change_safe = false;
                security_warnings.push(format!(
                    "SECURITY_ALERT_BLIND_SIGNING: Phát hiện lệnh quyên góp ngầm (Treasury Donation: {} Lovelace) trong giao dịch!",
                    donation_val
                ));
            }
        }
        if tx_body.mint.is_some() {
            is_change_safe = false;
            security_warnings.push(
                "SECURITY_ALERT_BLIND_SIGNING: Giao dịch chứa lệnh đúc/đốt tài sản (Mint/Burn) không được phép!".to_string(),
            );
        }
        if has_unauthorized_cert {
            is_change_safe = false;
            security_warnings.push(
                "SECURITY_ALERT_BLIND_SIGNING: Giao dịch chứa chứng chỉ Hủy đăng ký khóa Stake hoặc chứng chỉ lạ!".to_string(),
            );
        }
        if tx_body.collateral_inputs.is_some() || tx_body.collateral_return.is_some() || tx_body.total_collateral.is_some() {
            is_change_safe = false;
            security_warnings.push(
                "SECURITY_ALERT_BLIND_SIGNING: Giao dịch chứa trường Thế chấp (Collateral) Smart Contract không được phép!".to_string(),
            );
        }
        if tx_body.script_data_hash.is_some() {
            is_change_safe = false;
            security_warnings.push(
                "SECURITY_ALERT_BLIND_SIGNING: Giao dịch chứa mã băm Plutus ScriptDataHash không được phép!".to_string(),
            );
        }
        if tx_body.proposal_procedures.is_some() {
            is_change_safe = false;
            security_warnings.push(
                "SECURITY_ALERT_BLIND_SIGNING: Giao dịch chứa đề xuất Quản trị (Governance Proposal) không được phép!".to_string(),
            );
        }
        if tx_body.voting_procedures.is_some() {
            is_change_safe = false;
            security_warnings.push(
                "SECURITY_ALERT_BLIND_SIGNING: Giao dịch chứa quy trình Biểu quyết Quản trị (VotingProcedures) không được phép!".to_string(),
            );
        }
        if tx_body.required_signers.is_some() {
            is_change_safe = false;
            security_warnings.push(
                "SECURITY_ALERT_BLIND_SIGNING: Giao dịch chứa danh sách chữ ký phụ bắt buộc (RequiredSigners) không được phép!".to_string(),
            );
        }

        let is_single_output_self_tx = tx_body.outputs.len() == 1 && (has_certs || has_withdrawals || is_delegation_prefix || is_withdrawal_prefix);

        for (idx, out) in tx_body.outputs.iter().enumerate() {
            let addr_str = out.address().to_bech32(None).unwrap_or_else(|_| "Unknown Address".to_string());
            let coin = out.amount().coin;

            // Kiểm tra Network Tag của địa chỉ đầu ra (Mainnet = addr1, Testnet = addr_test1)
            let addr_is_testnet = addr_str.starts_with("addr_test1") || addr_str.starts_with("stake_test1");
            let addr_is_mainnet = addr_str.starts_with("addr1") || addr_str.starts_with("stake1");
            if (is_testnet && addr_is_mainnet) || (!is_testnet && addr_is_testnet) {
                is_change_safe = false;
                security_warnings.push(format!(
                    "SECURITY_ALERT_NETWORK_MISMATCH: Địa chỉ đầu ra '{}' không khớp với mạng lưới hiện tại (Testnet={})!",
                    addr_str, is_testnet
                ));
            } else if !addr_is_testnet && !addr_is_mainnet {
                is_change_safe = false;
                security_warnings.push(format!(
                    "SECURITY_ALERT_INVALID_ADDRESS_FORMAT: Địa chỉ đầu ra '{}' không đúng định dạng Bech32 chuẩn (Shelley/Conway)!",
                    addr_str
                ));
            }

            let is_change = idx > 0 || is_single_output_self_tx;
            let mut is_verified = false;

            if is_change {
                change_lovelace = change_lovelace.saturating_add(coin);
                if let Some(ref xpub) = account_xpub {
                    match ChangeGuard::verify_change_address(&addr_str, xpub, is_testnet) {
                        Ok(true) => {
                            is_verified = true;
                        }
                        Ok(false) => {
                            is_change_safe = false;
                            security_warnings.push(format!(
                                "SECURITY_ALERT_CHANGE_HIJACKING: Địa chỉ nhận tiền thừa/ủy thác '{}' KHÔNG thuộc danh sách quản lý của ví!",
                                addr_str
                            ));
                        }
                        Err(warning) => {
                            is_change_safe = false;
                            security_warnings.push(warning);
                        }
                    }
                } else {
                    is_change_safe = false;
                    security_warnings.push(format!(
                        "SECURITY_ALERT_UNVERIFIED_CHANGE: Không có khóa công khai mở rộng (xpub) để xác minh địa chỉ tiền thừa '{}'!",
                        addr_str
                    ));
                }
            } else {
                recipient_address = addr_str.clone();
                send_lovelace = send_lovelace.saturating_add(coin);
            }

            let mut tokens = Vec::new();
            for (policy, assets) in out.amount().multiasset.iter() {
                let policy_hex = hex::encode(policy.to_raw_bytes());
                for (asset_name, &quantity) in assets.iter() {
                    let name_bytes = asset_name.to_raw_bytes();
                    let asset_name_hex = hex::encode(&name_bytes);
                    let asset_name_utf8 = String::from_utf8(name_bytes.to_vec())
                        .unwrap_or_else(|_| asset_name_hex.clone());
                    tokens.push(ParsedTokenItem {
                        policy_id: policy_hex.clone(),
                        asset_name_hex,
                        asset_name_utf8,
                        quantity,
                    });
                }
            }

            outputs.push(ParsedOutput {
                address: addr_str,
                lovelace: coin,
                is_change,
                is_change_verified: is_verified,
                tokens,
            });
        }

        let security_warning = if security_warnings.is_empty() {
            None
        } else {
            Some(security_warnings.join("; "))
        };

        Ok(ParsedTransaction {
            fee_lovelace,
            ttl,
            inputs_count,
            outputs,
            recipient_address,
            send_lovelace,
            change_lovelace,
            is_change_safe,
            security_warning,
            tx_hash_hex,
            has_certs,
            certs_count,
            certificates_summary,
            has_withdrawals,
            withdrawals_total_lovelace,
            withdrawals_summary,
            requires_stake_signing,
        })
    }
}
