use crate::key_derivation::KeyDerivator;
use crate::tx_parser::TransactionParser;
use crate::tx_signer::TransactionSigner;
use crate::change_guard::ChangeGuard;
use cml_crypto::{Bip32PublicKey, RawBytesEncoding};
use serde::{Serialize, Deserialize};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[derive(Serialize, Deserialize)]
pub struct ApiResult<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
}

impl<T> ApiResult<T> {
    pub fn ok(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    pub fn err(msg: String) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(msg),
        }
    }

    pub fn to_json(&self) -> String 
    where T: Serialize {
        serde_json::to_string(self).unwrap_or_else(|_| "{\"success\":false,\"error\":\"JSON Error\"}".to_string())
    }
}

pub struct CardanoApi;

impl CardanoApi {
    pub fn generate_mnemonic(word_count: usize) -> String {
        match KeyDerivator::generate_mnemonic(word_count) {
            Ok(phrase) => ApiResult::ok(phrase).to_json(),
            Err(e) => ApiResult::<String>::err(e).to_json(),
        }
    }

    pub fn validate_mnemonic(phrase: &str) -> bool {
        KeyDerivator::validate_mnemonic(phrase)
    }

    pub fn create_wallet(
        phrase: &str,
        passphrase: &str,
        is_testnet: bool,
        account_index: u32,
        address_index: u32,
    ) -> String {
        match KeyDerivator::create_wallet_info(phrase, passphrase, is_testnet, account_index, address_index) {
            Ok(info) => ApiResult::ok(info).to_json(),
            Err(e) => ApiResult::<crate::key_derivation::WalletKeysInfo>::err(e).to_json(),
        }
    }

    pub fn create_wallet_ext(
        phrase: &str,
        passphrase: &str,
        is_testnet: bool,
        account_index: u32,
        address_index: u32,
        use_icarus: bool,
    ) -> String {
        match KeyDerivator::create_wallet_info_ext(phrase, passphrase, is_testnet, account_index, address_index, use_icarus) {
            Ok(info) => ApiResult::ok(info).to_json(),
            Err(e) => ApiResult::<crate::key_derivation::WalletKeysInfo>::err(e).to_json(),
        }
    }

    pub fn parse_transaction(cbor_hex: &str, account_xpub_hex: Option<&str>, is_testnet: bool) -> String {
        match TransactionParser::parse_raw_cbor(cbor_hex, account_xpub_hex, is_testnet) {
            Ok(parsed) => ApiResult::ok(parsed).to_json(),
            Err(e) => ApiResult::<crate::tx_parser::ParsedTransaction>::err(e).to_json(),
        }
    }

    pub fn sign_transaction(
        cbor_hex: &str,
        mnemonic: &str,
        passphrase: &str,
        sign_stake: bool,
        account_index: u32,
        address_index: u32,
    ) -> String {
        Self::sign_transaction_ext(
            cbor_hex,
            mnemonic,
            passphrase,
            sign_stake,
            account_index,
            address_index,
            false,
        )
    }

    pub fn sign_transaction_ext(
        cbor_hex: &str,
        mnemonic: &str,
        passphrase: &str,
        sign_stake: bool,
        account_index: u32,
        address_index: u32,
        use_icarus: bool,
    ) -> String {
        match TransactionSigner::sign_raw_transaction_ext(
            cbor_hex,
            mnemonic,
            passphrase,
            sign_stake,
            account_index,
            address_index,
            use_icarus,
        ) {
            Ok(signed_hex) => ApiResult::ok(signed_hex).to_json(),
            Err(e) => ApiResult::<String>::err(e).to_json(),
        }
    }

    pub fn sign_transaction_v2(
        cbor_hex: &str,
        mnemonic: &str,
        passphrase: &str,
        sign_stake: bool,
        account_index: u32,
        address_index: u32,
        is_testnet: bool,
        use_icarus: bool,
    ) -> String {
        match TransactionSigner::sign_raw_transaction_v2(
            cbor_hex,
            mnemonic,
            passphrase,
            sign_stake,
            account_index,
            address_index,
            is_testnet,
            use_icarus,
        ) {
            Ok(signed_hex) => ApiResult::ok(signed_hex).to_json(),
            Err(e) => ApiResult::<String>::err(e).to_json(),
        }
    }

    pub fn verify_signed_transaction(signed_cbor_hex: &str) -> String {
        match TransactionSigner::verify_signed_transaction(signed_cbor_hex) {
            Ok(is_valid) => ApiResult::ok(is_valid).to_json(),
            Err(e) => ApiResult::<bool>::err(e).to_json(),
        }
    }

    pub fn verify_change_address(change_address: &str, account_xpub_hex: &str, is_testnet: bool) -> String {
        let xpub_bytes = match hex::decode(account_xpub_hex) {
            Ok(b) => b,
            Err(e) => return ApiResult::<bool>::err(format!("Lỗi hex: {}", e)).to_json(),
        };

        let xpub = match Bip32PublicKey::from_raw_bytes(&xpub_bytes) {
            Ok(k) => k,
            Err(e) => return ApiResult::<bool>::err(format!("Lỗi xpub: {:?}", e)).to_json(),
        };

        match ChangeGuard::verify_change_address(change_address, &xpub, is_testnet) {
            Ok(is_safe) => ApiResult::ok(is_safe).to_json(),
            Err(err) => ApiResult::<bool>::err(err).to_json(),
        }
    }

    pub fn create_sample_conway_tx(recipient_addr: &str, send_lovelace: u64, fee_lovelace: u64) -> String {
        use cml_chain::transaction::{TransactionBody, TransactionInput, TransactionOutput};
        use cml_chain::assets::Coin;
        use cml_chain::address::Address;
        use cml_crypto::TransactionHash;
        use cml_core::serialization::Serialize;

        let dummy_hash = TransactionHash::from([0xaa; 32]);
        let input = TransactionInput::new(dummy_hash, 0);

        let rec_addr = match Address::from_bech32(recipient_addr) {
            Ok(a) => a,
            Err(e) => return ApiResult::<String>::err(format!("Invalid address: {}", e)).to_json(),
        };

        let output = TransactionOutput::new(rec_addr, Coin::from(send_lovelace).into(), None, None);

        let tx_body = TransactionBody::new(
            vec![input].into(),
            vec![output],
            Coin::from(fee_lovelace),
        );

        let cbor_bytes = tx_body.to_cbor_bytes();
        ApiResult::ok(hex::encode(cbor_bytes)).to_json()
    }
}

// ==========================================
// C-FFI EXPORTS FOR FLUTTER DART:FFI
// ==========================================

fn str_to_c_char(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

unsafe fn c_char_to_str<'a>(ptr: *const c_char) -> &'a str {
    if ptr.is_null() {
        ""
    } else {
        CStr::from_ptr(ptr).to_str().unwrap_or("")
    }
}

fn catch_to_json<F>(f: F) -> *mut c_char
where
    F: FnOnce() -> String + std::panic::UnwindSafe,
{
    match std::panic::catch_unwind(f) {
        Ok(json) => str_to_c_char(json),
        Err(_) => str_to_c_char(ApiResult::<String>::err("Internal Panic in Rust core".to_string()).to_json()),
    }
}

#[no_mangle]
pub extern "C" fn cardano_core_generate_mnemonic(word_count: u32) -> *mut c_char {
    catch_to_json(move || CardanoApi::generate_mnemonic(word_count as usize))
}

#[no_mangle]
pub extern "C" fn cardano_core_validate_mnemonic(phrase: *const c_char) -> bool {
    let s = unsafe { c_char_to_str(phrase) };
    std::panic::catch_unwind(move || CardanoApi::validate_mnemonic(s)).unwrap_or(false)
}

#[no_mangle]
pub extern "C" fn cardano_core_create_wallet(
    phrase: *const c_char,
    passphrase: *const c_char,
    is_testnet: bool,
    account_index: u32,
    address_index: u32,
) -> *mut c_char {
    let ph = unsafe { c_char_to_str(phrase) };
    let pass = unsafe { c_char_to_str(passphrase) };
    catch_to_json(move || CardanoApi::create_wallet(ph, pass, is_testnet, account_index, address_index))
}

#[no_mangle]
pub extern "C" fn cardano_core_create_wallet_ext(
    phrase: *const c_char,
    passphrase: *const c_char,
    is_testnet: bool,
    account_index: u32,
    address_index: u32,
    use_icarus: bool,
) -> *mut c_char {
    let ph = unsafe { c_char_to_str(phrase) };
    let pass = unsafe { c_char_to_str(passphrase) };
    catch_to_json(move || CardanoApi::create_wallet_ext(ph, pass, is_testnet, account_index, address_index, use_icarus))
}

#[no_mangle]
pub extern "C" fn cardano_core_parse_transaction(
    cbor_hex: *const c_char,
    account_xpub_hex: *const c_char,
    is_testnet: bool,
) -> *mut c_char {
    let cbor = unsafe { c_char_to_str(cbor_hex) };
    let xpub = unsafe { c_char_to_str(account_xpub_hex) };
    let xpub_opt = if xpub.is_empty() { None } else { Some(xpub) };
    catch_to_json(move || CardanoApi::parse_transaction(cbor, xpub_opt, is_testnet))
}

#[no_mangle]
pub extern "C" fn cardano_core_sign_transaction(
    cbor_hex: *const c_char,
    mnemonic: *const c_char,
    passphrase: *const c_char,
    sign_stake: bool,
    account_index: u32,
    address_index: u32,
) -> *mut c_char {
    let cbor = unsafe { c_char_to_str(cbor_hex) };
    let phrase = unsafe { c_char_to_str(mnemonic) };
    let pass = unsafe { c_char_to_str(passphrase) };
    catch_to_json(move || CardanoApi::sign_transaction(cbor, phrase, pass, sign_stake, account_index, address_index))
}

#[no_mangle]
pub extern "C" fn cardano_core_sign_transaction_ext(
    cbor_hex: *const c_char,
    mnemonic: *const c_char,
    passphrase: *const c_char,
    sign_stake: bool,
    account_index: u32,
    address_index: u32,
    use_icarus: bool,
) -> *mut c_char {
    let cbor = unsafe { c_char_to_str(cbor_hex) };
    let phrase = unsafe { c_char_to_str(mnemonic) };
    let pass = unsafe { c_char_to_str(passphrase) };
    catch_to_json(move || CardanoApi::sign_transaction_ext(cbor, phrase, pass, sign_stake, account_index, address_index, use_icarus))
}

#[no_mangle]
pub extern "C" fn cardano_core_sign_transaction_v2(
    cbor_hex: *const c_char,
    mnemonic: *const c_char,
    passphrase: *const c_char,
    sign_stake: bool,
    account_index: u32,
    address_index: u32,
    is_testnet: bool,
    use_icarus: bool,
) -> *mut c_char {
    let cbor = unsafe { c_char_to_str(cbor_hex) };
    let phrase = unsafe { c_char_to_str(mnemonic) };
    let pass = unsafe { c_char_to_str(passphrase) };
    catch_to_json(move || CardanoApi::sign_transaction_v2(cbor, phrase, pass, sign_stake, account_index, address_index, is_testnet, use_icarus))
}

#[no_mangle]
pub extern "C" fn cardano_core_verify_change(
    change_address: *const c_char,
    account_xpub_hex: *const c_char,
    is_testnet: bool,
) -> *mut c_char {
    let addr = unsafe { c_char_to_str(change_address) };
    let xpub = unsafe { c_char_to_str(account_xpub_hex) };
    catch_to_json(move || CardanoApi::verify_change_address(addr, xpub, is_testnet))
}

#[no_mangle]
pub extern "C" fn cardano_core_create_sample_conway_tx(
    recipient_addr: *const c_char,
    send_lovelace: u64,
    fee_lovelace: u64,
) -> *mut c_char {
    let addr = unsafe { c_char_to_str(recipient_addr) };
    catch_to_json(move || CardanoApi::create_sample_conway_tx(addr, send_lovelace, fee_lovelace))
}

#[no_mangle]
pub extern "C" fn cardano_core_verify_signed_tx(
    signed_cbor_hex: *const c_char,
) -> *mut c_char {
    let signed_cbor = unsafe { c_char_to_str(signed_cbor_hex) };
    catch_to_json(move || CardanoApi::verify_signed_transaction(signed_cbor))
}

#[no_mangle]
pub extern "C" fn cardano_core_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let c_str = CString::from_raw(ptr);
            let mut vec = c_str.into_bytes_with_nul();
            crate::secure_zeroize(&mut vec);
        }
    }
}
