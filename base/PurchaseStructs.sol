
pragma ton-solidity >= 0.35.0;

struct Purchase {
    uint32 id;         // идентификатор
    string title;      // название товара
    uint32 quantity;   // количество товаров
    uint32 price;      // общая цена всех единиц товара
    bool isConfirmed;  // флаг, что куплена
    uint64 createdAt;  // когда заведена
}

struct PurchasesSummary {
    uint32 unpaidCount;  // сколько предметов в списке "не оплачено"
    uint32 paidCount;    // сколько предметов в списке "оплачено"
    uint32 totalPayment; // на какую сумму всего было оплачено
}
