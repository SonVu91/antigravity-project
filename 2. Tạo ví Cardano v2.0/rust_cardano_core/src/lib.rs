pub mod key_derivation;
pub mod tx_parser;
pub mod change_guard;
pub mod tx_signer;
pub mod api;

pub use key_derivation::{KeyDerivator, WalletKeysInfo, SensitiveSeed};
pub use tx_parser::{TransactionParser, ParsedTransaction, ParsedOutput, ParsedTokenItem};
pub use change_guard::ChangeGuard;
pub use tx_signer::TransactionSigner;
pub use api::CardanoApi;

/// Xóa sạch bộ đệm nhạy cảm bằng write_volatile và compiler_fence ngăn compiler tối ưu hóa bỏ qua
#[inline(never)]
pub fn secure_zeroize(slice: &mut [u8]) {
    unsafe {
        for b in slice.iter_mut() {
            std::ptr::write_volatile(b, 0);
        }
    }
    std::sync::atomic::compiler_fence(std::sync::atomic::Ordering::SeqCst);
}
