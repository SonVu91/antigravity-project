import '../network/blockfrost_client.dart';

/// Tiện ích liên kết và tra cứu dữ liệu on-chain độc lập trên Cardanoscan Explorer
class CardanoscanHelper {
  /// Lấy URL gốc của Cardanoscan theo môi trường mạng
  static String getBaseUrl(CardanoNetwork network) {
    switch (network) {
      case CardanoNetwork.mainnet:
        return 'https://cardanoscan.io';
      case CardanoNetwork.preview:
        return 'https://preview.cardanoscan.io';
      case CardanoNetwork.preprod:
      default:
        return 'https://preprod.cardanoscan.io';
    }
  }

  /// URL tra cứu địa chỉ ví (Address)
  static String getAddressUrl(CardanoNetwork network, String address) {
    final clean = address.trim();
    return '${getBaseUrl(network)}/address/$clean';
  }

  /// URL tra cứu mã băm giao dịch (Transaction TxID)
  static String getTxUrl(CardanoNetwork network, String txId) {
    final clean = txId.trim();
    return '${getBaseUrl(network)}/transaction/$clean';
  }

  /// URL tra cứu Stake Pool
  static String getPoolUrl(CardanoNetwork network, String poolId) {
    final clean = poolId.trim();
    return '${getBaseUrl(network)}/pool/$clean';
  }

  /// URL tra cứu DRep (CIP-1694)
  static String getDRepUrl(CardanoNetwork network, String drepId) {
    final clean = drepId.trim();
    return '${getBaseUrl(network)}/drep/$clean';
  }

  /// URL tra cứu Stake Key (stake1... hoặc stake_test1...)
  static String getStakeKeyUrl(CardanoNetwork network, String stakeAddress) {
    final clean = stakeAddress.trim();
    return '${getBaseUrl(network)}/stakekey/$clean';
  }
}
