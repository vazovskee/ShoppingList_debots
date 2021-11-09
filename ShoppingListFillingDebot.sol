
pragma ton-solidity >=0.35.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./base/tonlabs/Menu.sol";

import "./ShoppingListInitDebot.sol";

contract ShoppingListFillingDebot is ShoppingListInitDebot {

    string private productTitle;
    uint32 private productsCount;

    function shoppingListManipulationMenu() internal override {
        string sep = '----------------------------------------';
        Menu.select(
            format(
                "You have {} purchases ({} unpaid / {} paid with total price: {} cr.)",
                    m_summary.unpaidCount,
                    m_summary.paidCount,
                    m_summary.unpaidCount + m_summary.paidCount,
                    m_summary.totalPayment
            ),
            sep,
            // показываем опции для дальнейшего взаимодействия с деботом
            [
                MenuItem("Add new purchase","",tvm.functionId(addPurchase))
            ]
        );
    }

    function addPurchase(uint32 index) public {
        index = index; // index of selected menu option
        Terminal.input(tvm.functionId(addPurchase_), "Product name:", false);
    }

    function addPurchase_(string value) public {
        productTitle = value;
        Terminal.input(tvm.functionId(addPurchase__), "Number of products:", false);
    }

    function addPurchase__(string value) public {
        (uint num,) = stoi(value);
        productsCount = uint32(num);
        optional(uint256) none = 0;
        IShoppingList(m_shoppingListAddress).addPurchase{ // вызываем метод addPurchase у контракта ShoppingList
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: none,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(onSuccess), // удачно создано
                onErrorId: tvm.functionId(onErrorListInteraction)
            }(productTitle, productsCount);
    }
    
    function onErrorListInteraction(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Operation failed. sdkError {}, exitCode {}", sdkError, exitCode));
        shoppingListManipulationMenu();
    }
}
