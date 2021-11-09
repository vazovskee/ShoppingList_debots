
pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./base/tonlabs/Menu.sol";

import "./ShoppingListInteractionDebot.sol";

contract ShoppingListFillingDebot is ShoppingListInteractionDebot {

    string private productTitle;
    uint32 private productsCount;

    function listActionsMenu() internal override {
        string sep = '----------------------------------------';
        string menuIntro;
        uint32 totalCount = m_summary.unpaidCount + m_summary.paidCount;
        if (m_summary.unpaidCount + m_summary.paidCount == 0) {
            menuIntro = "Your shopping list is empty";
        } else {
            menuIntro = format("You have {} purchases", totalCount);
            if (m_summary.unpaidCount != 0) {
                menuIntro = format("{} ({} unpaid)", menuIntro, m_summary.unpaidCount);
            }
            if (m_summary.paidCount != 0) {
                menuIntro = format("{} ({} paid with total price {} cr.)", menuIntro, m_summary.unpaidCount, m_summary.totalPayment);
            }
        }

        Menu.select(
            menuIntro,
            sep,
            // показываем опции для дальнейшего взаимодействия с деботом
            [
                MenuItem("Show purchases","",tvm.functionId(showPurchases)),
                MenuItem("Add new purchase","",tvm.functionId(addPurchase)),
                MenuItem("Delete purchase","",tvm.functionId(deletePurchase))
            ]
        );
    }

    function addPurchase(uint32 index) public {
        index = index; // index of selected menu option
        Terminal.input(tvm.functionId(addPurchase_), "Enter product name:", false);
    }

    function addPurchase_(string value) public {
        productTitle = value;
        Terminal.input(tvm.functionId(addPurchase__), "Enter the number of products:", false);
    }

    function addPurchase__(string value) public {
        (uint num,) = stoi(value);
        productsCount = uint32(num);
        optional(uint) none;
        IShoppingList(m_shoppingListAddress).addPurchase{ // вызываем метод addPurchase у контракта ShoppingList
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: none,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(onSuccess),
                onErrorId: tvm.functionId(onErrorListAction)
            }(productTitle, productsCount);
    }
}
