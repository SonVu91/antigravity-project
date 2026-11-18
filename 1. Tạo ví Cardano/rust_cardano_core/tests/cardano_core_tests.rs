use rust_cardano_core::api::CardanoApi;
use rust_cardano_core::key_derivation::KeyDerivator;
use rust_cardano_core::change_guard::ChangeGuard;
use rust_cardano_core::tx_signer::TransactionSigner;

#[test]
fn test_mnemonic_generation_and_validation() {
    for &count in &[12, 15, 24] {
        let json_resp = CardanoApi::generate_mnemonic(count);
        assert!(json_resp.contains("\"success\":true"), "Failed to generate {} words", count);

        let parsed: serde_json::Value = serde_json::from_str(&json_resp).unwrap();
        let mnemonic = parsed["data"].as_str().unwrap();
        let words: Vec<&str> = mnemonic.split_whitespace().collect();
        assert_eq!(words.len(), count);

        assert!(CardanoApi::validate_mnemonic(mnemonic));
    }
}

#[test]
fn test_wallet_creation_cip1852() {
    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    let wallet_json = CardanoApi::create_wallet(test_mnemonic, "", true, 0, 0);
    assert!(wallet_json.contains("\"success\":true"));

    let parsed: serde_json::Value = serde_json::from_str(&wallet_json).unwrap();
    let payment_addr = parsed["data"]["payment_address"].as_str().unwrap();
    let stake_addr = parsed["data"]["stake_address"].as_str().unwrap();
    let path = parsed["data"]["derivation_path"].as_str().unwrap();

    assert!(payment_addr.starts_with("addr_test1"), "Payment address must start with addr_test1 on testnet");
    assert!(stake_addr.starts_with("stake_test1"), "Stake address must start with stake_test1 on testnet");
    assert_eq!(path, "m/1852'/1815'/0'/0/0");

    // Mainnet test
    let mainnet_wallet_json = CardanoApi::create_wallet(test_mnemonic, "", false, 0, 0);
    let parsed_mainnet: serde_json::Value = serde_json::from_str(&mainnet_wallet_json).unwrap();
    let payment_addr_mainnet = parsed_mainnet["data"]["payment_address"].as_str().unwrap();
    let stake_addr_mainnet = parsed_mainnet["data"]["stake_address"].as_str().unwrap();

    assert!(payment_addr_mainnet.starts_with("addr1"), "Payment address must start with addr1 on mainnet");
    assert!(stake_addr_mainnet.starts_with("stake1"), "Stake address must start with stake1 on mainnet");
}

#[test]
fn test_custom_account_and_address_index_derivation() {
    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";

    // 1. Account 0, Address 0
    let w0_0_json = CardanoApi::create_wallet(test_mnemonic, "", true, 0, 0);
    let w0_0: serde_json::Value = serde_json::from_str(&w0_0_json).unwrap();
    let addr0_0 = w0_0["data"]["payment_address"].as_str().unwrap();
    let xpub0 = w0_0["data"]["account_xpub_hex"].as_str().unwrap();

    // 2. Account 0, Address 1 (cùng account, khác address index)
    let w0_1_json = CardanoApi::create_wallet(test_mnemonic, "", true, 0, 1);
    let w0_1: serde_json::Value = serde_json::from_str(&w0_1_json).unwrap();
    let addr0_1 = w0_1["data"]["payment_address"].as_str().unwrap();
    let xpub0_1 = w0_1["data"]["account_xpub_hex"].as_str().unwrap();

    assert_ne!(addr0_0, addr0_1, "Khác address index phải cho địa chỉ khác nhau");
    assert_eq!(xpub0, xpub0_1, "Cùng account index phải có cùng account xpub");
    assert_eq!(w0_1["data"]["derivation_path"].as_str().unwrap(), "m/1852'/1815'/0'/0/1");

    // 3. Account 1, Address 0 (khác account index)
    let w1_0_json = CardanoApi::create_wallet(test_mnemonic, "", true, 1, 0);
    let w1_0: serde_json::Value = serde_json::from_str(&w1_0_json).unwrap();
    let addr1_0 = w1_0["data"]["payment_address"].as_str().unwrap();
    let xpub1 = w1_0["data"]["account_xpub_hex"].as_str().unwrap();

    assert_ne!(addr0_0, addr1_0, "Khác account index phải cho địa chỉ khác nhau");
    assert_ne!(xpub0, xpub1, "Khác account index phải cho account xpub khác nhau");
    assert_eq!(w1_0["data"]["derivation_path"].as_str().unwrap(), "m/1852'/1815'/1'/0/0");

    // 4. Ký giao dịch với Account 1, Address 2
    let sample_tx = CardanoApi::create_sample_conway_tx(addr1_0, 5000000, 180000);
    let tx_obj: serde_json::Value = serde_json::from_str(&sample_tx).unwrap();
    let cbor_hex = tx_obj["data"].as_str().unwrap();

    let sign_res = CardanoApi::sign_transaction(cbor_hex, test_mnemonic, "", false, 1, 2);
    assert!(sign_res.contains("\"success\":true"), "Ký giao dịch thành công với account 1, address 2");
}

#[test]
fn test_bip39_passphrase_25th_word() {
    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";

    // Ví chuẩn: Không có từ khóa 25 (passphrase rỗng)
    let standard_json = CardanoApi::create_wallet(test_mnemonic, "", true, 0, 0);
    let standard_val: serde_json::Value = serde_json::from_str(&standard_json).unwrap();
    let std_payment_addr = standard_val["data"]["payment_address"].as_str().unwrap();
    let std_stake_addr = standard_val["data"]["stake_address"].as_str().unwrap();
    let std_xpub = standard_val["data"]["account_xpub_hex"].as_str().unwrap();

    // Ví ẩn: Có từ khóa 25 "my_secret_passphrase_25"
    let hidden1_json = CardanoApi::create_wallet(test_mnemonic, "my_secret_passphrase_25", true, 0, 0);
    let hidden1_val: serde_json::Value = serde_json::from_str(&hidden1_json).unwrap();
    let h1_payment_addr = hidden1_val["data"]["payment_address"].as_str().unwrap();
    let h1_stake_addr = hidden1_val["data"]["stake_address"].as_str().unwrap();
    let h1_xpub = hidden1_val["data"]["account_xpub_hex"].as_str().unwrap();

    // Ví ẩn 2: Có từ khóa 25 khác "another_passphrase"
    let hidden2_json = CardanoApi::create_wallet(test_mnemonic, "another_passphrase", true, 0, 0);
    let hidden2_val: serde_json::Value = serde_json::from_str(&hidden2_json).unwrap();
    let h2_payment_addr = hidden2_val["data"]["payment_address"].as_str().unwrap();

    // Xác minh tính độc lập và phân tách bảo mật:
    assert_ne!(std_payment_addr, h1_payment_addr, "Ví có từ khóa 25 phải có Payment Address khác ví chuẩn");
    assert_ne!(std_stake_addr, h1_stake_addr, "Ví có từ khóa 25 phải có Stake Address khác ví chuẩn");
    assert_ne!(std_xpub, h1_xpub, "Ví có từ khóa 25 phải có Account Xpub khác ví chuẩn");
    assert_ne!(h1_payment_addr, h2_payment_addr, "Hai từ khóa 25 khác nhau phải tạo ra 2 ví hoàn toàn độc lập");

    // Ký giao dịch trên Ví Ẩn với từ khóa 25
    let sample_tx = CardanoApi::create_sample_conway_tx(h1_payment_addr, 3000000, 175000);
    let tx_obj: serde_json::Value = serde_json::from_str(&sample_tx).unwrap();
    let cbor_hex = tx_obj["data"].as_str().unwrap();

    let sign_hidden = CardanoApi::sign_transaction(cbor_hex, test_mnemonic, "my_secret_passphrase_25", false, 0, 0);
    assert!(sign_hidden.contains("\"success\":true"), "Ký giao dịch thành công với từ khóa thứ 25");
}

#[test]
fn test_change_guard_security() {
    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    let seed = KeyDerivator::mnemonic_to_seed(test_mnemonic, "").unwrap();
    let root = KeyDerivator::derive_root_key(&seed).unwrap();
    let account = KeyDerivator::derive_account_key(&root, 0).unwrap();
    let account_xpub = account.to_public();

    // 1. Địa chỉ thanh toán chuẩn (role 0, index 0) -> Phải hợp lệ
    let payment_vkey = KeyDerivator::derive_payment_key(&account, 0).unwrap().to_public();
    let stake_vkey = KeyDerivator::derive_stake_key(&account, 0).unwrap().to_public();
    let my_payment_addr = KeyDerivator::build_base_address(&payment_vkey, &stake_vkey, true).unwrap();

    let check_own = ChangeGuard::verify_change_address(&my_payment_addr, &account_xpub, true);
    assert!(check_own.is_ok(), "Own payment address should be verified as safe change address");

    // 2. Địa chỉ trả tiền thừa chuẩn (role 1, index 0) -> Phải hợp lệ
    let change_vkey = KeyDerivator::derive_change_key(&account, 0).unwrap().to_public();
    let my_change_addr = KeyDerivator::build_base_address(&change_vkey, &stake_vkey, true).unwrap();

    let check_change = ChangeGuard::verify_change_address(&my_change_addr, &account_xpub, true);
    assert!(check_change.is_ok(), "Own change address should be verified as safe change address");

    // 3. KỊCH BẢN TẤN CÔNG GIẢ LẬP: Địa chỉ ví của kẻ tấn công (sinh từ mnemonic khác)
    let hacker_mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    let hacker_seed = KeyDerivator::mnemonic_to_seed(hacker_mnemonic, "").unwrap();
    let hacker_root = KeyDerivator::derive_root_key(&hacker_seed).unwrap();
    let hacker_account = KeyDerivator::derive_account_key(&hacker_root, 0).unwrap();
    let hacker_payment_vkey = KeyDerivator::derive_payment_key(&hacker_account, 0).unwrap().to_public();
    let hacker_stake_vkey = KeyDerivator::derive_stake_key(&hacker_account, 0).unwrap().to_public();
    let attacker_address = KeyDerivator::build_base_address(&hacker_payment_vkey, &hacker_stake_vkey, true).unwrap();

    let attack_result = ChangeGuard::verify_change_address(&attacker_address, &account_xpub, true);
    assert!(attack_result.is_err(), "Change Guard MUST detect and reject attacker's change address!");
    let err_msg = attack_result.unwrap_err();
    assert!(err_msg.contains("SECURITY_ALERT_CHANGE_HIJACKING"), "Error message must identify change hijacking");
}

#[test]
fn test_multiasset_tx_parsing() {
    use cml_chain::transaction::{TransactionBody, TransactionInput, TransactionOutput};
    use cml_chain::assets::{MultiAsset, AssetName};
    use cml_chain::address::Address;
    use cml_crypto::{TransactionHash, ScriptHash};
    use cml_core::serialization::Serialize;
    use cml_core::ordered_hash_map::OrderedHashMap;
    use rust_cardano_core::tx_parser::TransactionParser;

    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    let wallet_json = CardanoApi::create_wallet(test_mnemonic, "", true, 0, 0);
    let parsed_wallet: serde_json::Value = serde_json::from_str(&wallet_json).unwrap();
    let payment_addr = parsed_wallet["data"]["payment_address"].as_str().unwrap();
    let account_xpub = parsed_wallet["data"]["account_xpub_hex"].as_str().unwrap();

    let rec_addr = Address::from_bech32(payment_addr).unwrap();
    let dummy_hash = TransactionHash::from([0xbb; 32]);
    let input = TransactionInput::new(dummy_hash, 0);

    // MultiAsset: PolicyID 28 bytes -> AssetName -> Quantity
    let policy_id = ScriptHash::from([0x11; 28]);
    let mut multiasset = MultiAsset::new();
    let mut assets = OrderedHashMap::new();
    let asset_name = AssetName::new(b"HOSKY".to_vec()).unwrap();
    assets.insert(asset_name, 1000000u64);
    multiasset.insert(policy_id, assets);

    let val = cml_chain::assets::Value::new(1500000u64, multiasset);

    let output = TransactionOutput::new(rec_addr, val, None, None);
    let tx_body = TransactionBody::new(vec![input].into(), vec![output], 180000u64);
    let cbor_hex = hex::encode(tx_body.to_cbor_bytes());

    let parsed = TransactionParser::parse_raw_cbor(&cbor_hex, Some(account_xpub), true).unwrap();
    assert_eq!(parsed.outputs.len(), 1);
    assert_eq!(parsed.outputs[0].tokens.len(), 1);
    assert_eq!(parsed.outputs[0].tokens[0].asset_name_utf8, "HOSKY");
    assert_eq!(parsed.outputs[0].tokens[0].quantity, 1000000);
    assert_eq!(parsed.tx_hash_hex.len(), 64, "TxHash Blake2b-256 must be 64 hex chars (32 bytes)");
}

#[test]
fn test_ed25519_signature_verification_and_tamper_resistance() {
    use rust_cardano_core::tx_signer::TransactionSigner;

    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    let wallet_json = CardanoApi::create_wallet(test_mnemonic, "", true, 0, 0);
    let parsed_wallet: serde_json::Value = serde_json::from_str(&wallet_json).unwrap();
    let payment_addr = parsed_wallet["data"]["payment_address"].as_str().unwrap();

    // 1. Ký giao dịch đơn (Payment Key) và xác minh chữ ký Ed25519
    let sample_tx_json = CardanoApi::create_sample_conway_tx(payment_addr, 10_000_000, 180_000);
    let tx_val: serde_json::Value = serde_json::from_str(&sample_tx_json).unwrap();
    let raw_cbor = tx_val["data"].as_str().unwrap();

    let signed_hex = TransactionSigner::sign_raw_transaction(raw_cbor, test_mnemonic, "", false, 0, 0).unwrap();
    assert!(
        TransactionSigner::verify_signed_transaction(&signed_hex).unwrap(),
        "Valid Ed25519 signature must pass verification"
    );

    // 2. Ký giao dịch kép (Payment Key + Stake Key) và xác minh cả 2 chữ ký Ed25519
    let dual_signed_hex = TransactionSigner::sign_raw_transaction(raw_cbor, test_mnemonic, "", true, 0, 0).unwrap();
    assert!(
        TransactionSigner::verify_signed_transaction(&dual_signed_hex).unwrap(),
        "Valid Dual (Payment + Stake) Ed25519 signatures must pass verification"
    );

    // 3. Deterministic Nonce (RFC 8032): Cùng thông điệp và khóa phải sinh chữ ký đồng nhất
    let signed_hex_again = TransactionSigner::sign_raw_transaction(raw_cbor, test_mnemonic, "", false, 0, 0).unwrap();
    assert_eq!(signed_hex, signed_hex_again, "Ed25519 signature must be deterministic per RFC 8032");

    // 4. Chống giả mạo chữ ký (Tamper Resistance): Thay đổi 1 bit bên trong vùng 64-byte chữ ký Ed25519
    let mut tampered_bytes = hex::decode(&signed_hex).unwrap();
    let sig_idx = tampered_bytes.len() - 10;
    tampered_bytes[sig_idx] ^= 0x01; // Lật 1 bit trong phần R/s của chữ ký Ed25519
    let tampered_hex = hex::encode(tampered_bytes);
    assert!(
        !TransactionSigner::verify_signed_transaction(&tampered_hex).unwrap(),
        "Tampered signature bit MUST fail Ed25519 verification!"
    );
}

#[test]
fn test_delegation_and_withdrawal_cbor_dissection_and_hijack_guard() {
    use rust_cardano_core::tx_parser::TransactionParser;

    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    let wallet_json = CardanoApi::create_wallet(test_mnemonic, "", true, 0, 0);
    let parsed_wallet: serde_json::Value = serde_json::from_str(&wallet_json).unwrap();
    let own_xpub = parsed_wallet["data"]["account_xpub_hex"].as_str().unwrap();
    let own_stake_addr = parsed_wallet["data"]["stake_address"].as_str().unwrap();
    println!("OWN STAKE ADDR: {}", own_stake_addr);

    // Kẻ tấn công có xpub khác
    let hacker_mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    let hacker_json = CardanoApi::create_wallet(hacker_mnemonic, "", true, 0, 0);
    let parsed_hacker: serde_json::Value = serde_json::from_str(&hacker_json).unwrap();
    let hacker_xpub = parsed_hacker["data"]["account_xpub_hex"].as_str().unwrap();

    // Giao dịch Delegation Conway chuẩn (Output 0 trả về ví chủ, Cert mang stake credential của ví chủ: 4dc1f2bca2dd7748c0a4faf32f02c5be7a250435c3f9ceb26ec03874)
    let delegation_raw = "TxBodyConwayDelegation:a50081825820a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef00001818258390033eff4f12fadfbee9a44c027a8adef8b2409552a459defd25739582d4dc1f2bca2dd7748c0a4faf32f02c5be7a250435c3f9ceb26ec038741a02faf688021a0002f9b8031a042c1d800481840a8200581c4dc1f2bca2dd7748c0a4faf32f02c5be7a250435c3f9ceb26ec03874581cabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdef008200581c98765432109876543210987654321098765432109876543210987654";

    // 1. Khi kiểm tra với own_xpub -> An toàn, bóc tách đầy đủ chứng chỉ
    let parsed_safe = TransactionParser::parse_raw_cbor(delegation_raw, Some(own_xpub), true).unwrap();
    println!("DEBUG PARSED_SAFE: {:?}", parsed_safe);
    assert!(parsed_safe.is_change_safe, "Delegation output to own wallet must be safe. Warning: {:?}", parsed_safe.security_warning);
    assert!(parsed_safe.has_certs, "Must detect Conway certificates");
    assert_eq!(parsed_safe.certs_count, 1);
    assert!(parsed_safe.requires_stake_signing, "Must require stake signing");
    assert!(!parsed_safe.certificates_summary.is_empty());

    // 2. Khi kiểm tra với hacker_xpub (tức Output 0 không thuộc ví đang ký) -> BỊ CHẶN CỨNG!
    let parsed_hijacked = TransactionParser::parse_raw_cbor(delegation_raw, Some(hacker_xpub), true).unwrap();
    assert!(
        !parsed_hijacked.is_change_safe,
        "ChangeGuard MUST block 1-output delegation transaction if output address does not belong to wallet!"
    );
    assert!(parsed_hijacked.security_warning.unwrap().contains("SECURITY_ALERT_CHANGE_HIJACKING"));
}

#[test]
fn test_icarus_cip0003_strict_derivation() {
    use cml_crypto::RawBytesEncoding;
    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    let root_std = KeyDerivator::derive_root_key_icarus(test_mnemonic, "").unwrap();
    let root_pass = KeyDerivator::derive_root_key_icarus(test_mnemonic, "StrongPass#2026!").unwrap();

    let acc_std = KeyDerivator::derive_account_key(&root_std, 0).unwrap();
    let acc_pass = KeyDerivator::derive_account_key(&root_pass, 0).unwrap();

    assert_ne!(
        acc_std.to_public().to_raw_hex(),
        acc_pass.to_public().to_raw_hex(),
        "CIP-0003 Icarus derivation with passphrase must yield distinct account xpub"
    );

    // Test create_wallet_ext API
    let w_bip39 = CardanoApi::create_wallet_ext(test_mnemonic, "", true, 0, 0, false);
    let w_icarus = CardanoApi::create_wallet_ext(test_mnemonic, "", true, 0, 0, true);

    let parsed_bip39: serde_json::Value = serde_json::from_str(&w_bip39).unwrap();
    let parsed_icarus: serde_json::Value = serde_json::from_str(&w_icarus).unwrap();

    let addr_bip39 = parsed_bip39["data"]["payment_address"].as_str().unwrap();
    let addr_icarus = parsed_icarus["data"]["payment_address"].as_str().unwrap();

    assert_ne!(addr_bip39, addr_icarus, "BIP-39 seed and Icarus raw entropy must produce distinct addresses");
    assert!(addr_bip39.starts_with("addr_test1"));
    assert!(addr_icarus.starts_with("addr_test1"));
}

#[test]
fn test_signing_blocked_when_change_is_hijacked() {
    use rust_cardano_core::tx_signer::TransactionSigner;

    // Ví chính chủ
    let user_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";

    // Kịch bản tấn công: Giao dịch có 2 outputs:
    // Output 0: 10 ADA gửi cho bạn bè (addr_test1...)
    // Output 1: 90 ADA tiền thừa bị hacker tráo thành địa chỉ lạ (addr_test1...)
    let attack_tx_raw = "TxBodyConway:a40081825820a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a10001828258390033eff4f12fadfbee9a44c027a8adef8b2409552a459defd25739582d4dc1f2bca2dd7748c0a4faf32f02c5be7a250435c3f9ceb26ec038741a009896808258390015cda6ba2f35ec82d52d21d4ecddb531796e51e4b21284e234c060cc9e5ed7e8bdc33cc76bbf62aff0364bd3770fb51d5f06a39239fd9cae1a01312d00021a0002bf20031a043c52a0";

    let sign_attempt = TransactionSigner::sign_raw_transaction(
        attack_tx_raw,
        user_mnemonic,
        "",
        false,
        0,
        0,
    );

    assert!(
        sign_attempt.is_err(),
        "TransactionSigner MUST REJECT signing an attack transaction with hijacked change address!"
    );
    let err_msg = sign_attempt.unwrap_err();
    assert!(
        err_msg.contains("SECURITY_BLOCKED_BY_CHANGE_GUARD"),
        "Error message must indicate blocked by Change Guard: {}",
        err_msg
    );
}

#[test]
fn test_sign_raw_transaction_ext_icarus_mode() {
    use rust_cardano_core::tx_signer::TransactionSigner;

    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    // Ví Icarus
    let icarus_wallet_json = CardanoApi::create_wallet_ext(test_mnemonic, "", true, 0, 0, true);
    let parsed_wallet: serde_json::Value = serde_json::from_str(&icarus_wallet_json).unwrap();
    let payment_addr = parsed_wallet["data"]["payment_address"].as_str().unwrap();

    let sample_tx = CardanoApi::create_sample_conway_tx(payment_addr, 5_000_000, 180_000);
    let tx_val: serde_json::Value = serde_json::from_str(&sample_tx).unwrap();
    let raw_cbor = tx_val["data"].as_str().unwrap();

    // Ký với use_icarus = true
    let signed_icarus = TransactionSigner::sign_raw_transaction_ext(
        raw_cbor,
        test_mnemonic,
        "",
        false,
        0,
        0,
        true,
    ).expect("Ký với Icarus mode thành công");

    assert!(
        TransactionSigner::verify_signed_transaction(&signed_icarus).unwrap(),
        "Icarus signature must pass Ed25519 verification"
    );
}

#[test]
fn test_anti_blind_signing_foreign_stake_withdrawal_blocked() {
    use rust_cardano_core::tx_parser::TransactionParser;

    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    let wallet_json = CardanoApi::create_wallet(test_mnemonic, "", true, 0, 0);
    let parsed_wallet: serde_json::Value = serde_json::from_str(&wallet_json).unwrap();
    let own_xpub = parsed_wallet["data"]["account_xpub_hex"].as_str().unwrap();

    // Giao dịch Rút thưởng nhưng Stake Address rút thưởng lại thuộc về kẻ tấn công (foreign stake key)
    let attack_withdrawal_raw = "TxBodyConwayWithdrawal:a50081825820a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef00001818258390033eff4f12fadfbee9a44c027a8adef8b2409552a459defd25739582d4dc1f2bca2dd7748c0a4faf32f02c5be7a250435c3f9ceb26ec038741a0186b388021a0002f9b8031a085b6da105a1581de0ffffffffffffffffffffffffffffffffffffffffffffffffffffffff1a00f116c0";

    let parsed = TransactionParser::parse_raw_cbor(attack_withdrawal_raw, Some(own_xpub), true).unwrap();
    assert!(
        !parsed.is_change_safe,
        "ChangeGuard MUST block foreign stake address withdrawal!"
    );
    assert!(
        parsed.security_warning.unwrap().contains("SECURITY_ALERT_UNAUTHORIZED_WITHDRAWAL"),
        "Warning must report unauthorized withdrawal"
    );
}

#[test]
fn test_cross_network_signing_blocked() {
    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    // Tạo ví Mainnet (is_testnet = false)
    let mainnet_wallet_json = CardanoApi::create_wallet(test_mnemonic, "", false, 0, 0);
    let parsed_mainnet: serde_json::Value = serde_json::from_str(&mainnet_wallet_json).unwrap();
    let mainnet_addr = parsed_mainnet["data"]["payment_address"].as_str().unwrap();
    assert!(mainnet_addr.starts_with("addr1"), "Mainnet address starts with addr1");

    // Tạo giao dịch Mainnet
    let mainnet_tx = CardanoApi::create_sample_conway_tx(mainnet_addr, 2_000_000, 170_000);
    let tx_val: serde_json::Value = serde_json::from_str(&mainnet_tx).unwrap();
    let raw_cbor = tx_val["data"].as_str().unwrap();

    // Cố gắng ký giao dịch Mainnet này khi ví đang ở chế độ Testnet (is_testnet = true) -> BỊ CHẶN NGAY!
    let sign_attempt = TransactionSigner::sign_raw_transaction_v2(
        raw_cbor,
        test_mnemonic,
        "",
        false,
        0,
        0,
        true, // is_testnet = true
        false,
    );

    assert!(sign_attempt.is_err(), "Must reject signing mainnet tx on testnet wallet");
    let err_msg = sign_attempt.err().unwrap();
    assert!(
        err_msg.contains("SECURITY_BLOCKED_NETWORK_MISMATCH"),
        "Error message must indicate network mismatch: {}",
        err_msg
    );
}

#[test]
fn test_unauthorized_stake_signing_blocked() {
    let test_mnemonic = "test walk nut penalty hip pave soap entry language right filter choice";
    // Delegation CBOR (mang chứng chỉ Conway)
    let delegation_raw = "a50081825820a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef00001818258390033eff4f12fadfbee9a44c027a8adef8b2409552a459defd25739582d4dc1f2bca2dd7748c0a4faf32f02c5be7a250435c3f9ceb26ec038741a02faf688021a0002f9b8031a042c1d800481840a8200581c4dc1f2bca2dd7748c0a4faf32f02c5be7a250435c3f9ceb26ec03874581cabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdef008200581c98765432109876543210987654321098765432109876543210987654";

    // Ký giao dịch mang Cert nhưng sign_stake = false và không có tiền tố TxBodyConwayDelegation -> BỊ CHẶN!
    let sign_attempt = TransactionSigner::sign_raw_transaction_v2(
        delegation_raw,
        test_mnemonic,
        "",
        false, // sign_stake = false
        0,
        0,
        true,
        false,
    );

    assert!(sign_attempt.is_err(), "Must block unauthorized stake signing");
    let err_msg = sign_attempt.err().unwrap();
    assert!(
        err_msg.contains("SECURITY_BLOCKED_UNAUTHORIZED_STAKE_SIGNING"),
        "Error message must indicate unauthorized stake signing: {}",
        err_msg
    );
}
