import Combine
import Foundation

private let host = "https://api.blockchair.com"
private let token = "PA__A7AmX35RoCXNBMUTKsR2xVR5u7IB"

struct BlockchairBlockchainRepository: BlockchainRepository {
    
    func balance(for wallet: Wallet) -> AnyPublisher<WalletInfo, Error> {
        switch wallet.asset {
        case .btc:
            return bitcoinBalance(address: wallet.address)
        case .eth:
            return etheriumBalance(address: wallet.address)
        default:
            fatalError("Not supported")
        }
    }
}

//MARK: - Bitcoin
extension BlockchairBlockchainRepository {
    
    private func bitcoinBalance(address: String) -> AnyPublisher<WalletInfo, Error> {
        let address = "\(host)/bitcoin/dashboards/address/\(address)" + "?limit=1"
        let url = URL(string: address)!
        return URLSession.shared.dataTaskPublisher(for: url)
            .extractData()
            .decode(type: BalancesResponse<BitcoinData>.self, decoder: JSONDecoder())
            .map {
                let data = $0.data.first!.value
                let balance = data.address.balance ?? 0
                let transactions = data.transactions
                    .sorted(by: { $0.time > $1.time })
                    .map { Transaction(date: $0.time, value: $0.balanceChange) }
                    .reversed()
                return WalletInfo(balance: balance, transactions: Array(transactions))
            }
            .eraseToAnyPublisher()
    }
    
    private struct BitcoinData: Codable {
        let address: BitcoinBalance
        let transactions: [BitcoinTransaction]
    }

    private struct BitcoinBalance: Codable {
        let balance: Double?
        let balanceUSD: Double
        
        enum CodingKeys: String, CodingKey {
            case balance = "balance"
            case balanceUSD = "balance_usd"
        }
    }

    private struct BitcoinTransaction: Codable {
        let time: Date
        let balanceChange: Double
        
        enum CodingKeys: String, CodingKey {
            case time = "time"
            case balanceChange = "balance_change"
        }
    }
}

//MARK: - Etherium
extension BlockchairBlockchainRepository {
    
    private func etheriumBalance(address: String) -> AnyPublisher<WalletInfo, Error> {
        let address = "\(host)/ethereum/dashboards/address/\(address)" + "?limit=1"
        let url = URL(string: address)!
        return URLSession.shared.dataTaskPublisher(for: url)
            .extractData()
            .decode(type: BalancesResponse<EtheriumData>.self, decoder: JSONDecoder())
            .map {
                let data = $0.data.first!.value
                let balance = data.address.balance ?? 0
                let transactions = data.calls
                    .sorted(by: { $0.time > $1.time })
                    .map { Transaction(date: $0.time, value: $0.value) }
                    .reversed()
                return WalletInfo(balance: balance, transactions: Array(transactions))
            }
            .eraseToAnyPublisher()
    }
    
    private struct EtheriumData: Codable {
        let address: EtheriumBalance
        let calls: [EtheriumCall]
    }

    private struct EtheriumBalance: Codable {
        let balance: Double?
        let balanceUSD: Double
        
        enum CodingKeys: String, CodingKey {
            case balance = "balance"
            case balanceUSD = "balance_usd"
        }
    }

    private struct EtheriumCall: Codable {
        let time: Date
        let value: Double
        
        enum CodingKeys: String, CodingKey {
            case time = "time"
            case value = "value"
        }
    }
}

private struct BalancesResponse<T: Codable>: Codable {
    let data: [String: T]
}
