
pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;

import "./base/IShoppingList.sol";
import "./base/HasConstructorWithPubKey.sol";

contract ShoppingList is IShoppingList {

    uint32 m_lastId;       // идентификатор последней добавленной покупки
    uint256 m_ownerPubkey; // открытый ключ владельца контракта 

    mapping(uint32 => Purchase) m_purchases; // идентификатор покупки => покупка

    constructor(uint256 pubkey) public {
        require(pubkey != 0, 120);
        tvm.accept();
        m_ownerPubkey = pubkey; // сохранение ключа владельца при деплое 
    }

    modifier onlyOwner() {
        require(msg.pubkey() == m_ownerPubkey, 101);
        _;
    }

    function addPurchase(string title, uint32 quantity) public override onlyOwner {
        tvm.accept();
        m_lastId++;
        m_purchases[m_lastId] = Purchase(m_lastId, title, quantity, 0, false, now);
    }

    function deletePurchase(uint32 id) public override onlyOwner {
        require(m_purchases.exists(id), 102);
        tvm.accept();
        delete m_purchases[id];
    }

    function confirmPurchase(uint32 id, uint32 _price) external override onlyOwner {
        require(m_purchases.exists(id), 102);
        require(!m_purchases[id].isConfirmed, 103);
        tvm.accept();
        m_purchases[id].price = _price;
        m_purchases[id].isConfirmed = true;
    }

    function getPurchases() external view override returns (Purchase[] purchases) {
        string itemName;
        uint64 createdAt;
        bool isDone;

        for((uint32 id, Purchase purchase) : m_purchases) {
            purchases.push(Purchase(id,
                                    purchase.title,
                                    purchase.quantity,
                                    purchase.price,
                                    purchase.isConfirmed,
                                    purchase.createdAt));
       }
    }

    function getSummary() external view override returns (PurchasesSummary) {
        uint32 unpaidCount;
        uint32 paidCount;
        uint32 totalPayment;

        for((, Purchase purchase) : m_purchases) {
            if  (purchase.isConfirmed) {
                paidCount ++;
                totalPayment += purchase.price;
            } else {
                unpaidCount ++;
            }
        }
        return PurchasesSummary(unpaidCount, paidCount, totalPayment);
    }
}