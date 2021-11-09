
pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./base/tonlabs/Menu.sol";

import "./ShoppingListInitDebot.sol";

contract ShoppingListFillingDebot is ShoppingListInitDebot {

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
                MenuItem("Delete purchase","",tvm.functionId(showPurchases))
            ]
        );
    }

    function showPurchases(uint32 index) public view {
        index = index;
        optional(uint256) none;
        IShoppingList(m_shoppingListAddress).getPurchases{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(showPurchases_),
            onErrorId: 0
        }();
    }

    function showPurchases_(Purchase[] purchases) public {
        string confirmedMark;
        string priceInfo;
        if (purchases.length > 0 ) {
            Terminal.print(0, "Your shopping list:");
            for (uint32 i = 0; i < purchases.length; i++) {
                Purchase purchase = purchases[i];
                if (purchase.isConfirmed) {
                    confirmedMark = "🛒";
                    priceInfo = format(" with total price {} cr. ", purchase.price);
                } else {
                    confirmedMark = " ";
                    priceInfo = "";
                }
                Terminal.print(0, format("[{}]{} {} units of {}{} | added at {} |",
                    purchase.id, confirmedMark, purchase.quantity, purchase.title, priceInfo, purchase.createdAt));
            }
        }
        listActionsMenu();
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

    function deletePurchase(uint32 index) public {
        index = index;
        if (m_summary.unpaidCount + m_summary.paidCount > 0) {
            Terminal.input(tvm.functionId(deletePurchase_), "Enter product's id:", false);
        } else {
            Terminal.print(0, "There are no products to remove in the list yet");
            listActionsMenu();
        }
    }

    function deletePurchase_(string value) public view {
        (uint id,) = stoi(value);
        optional(uint) none;
        IShoppingList(m_shoppingListAddress).deletePurchase{
                abiVer: 2,
                extMsg: true,
                sign: true,
                pubkey: none,
                time: uint64(now),
                expire: 0,
                callbackId: tvm.functionId(onSuccess),
                onErrorId: tvm.functionId(onErrorListAction)
            }(uint32(id));
    }

    function onErrorListAction(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Operation failed. sdkError {}, exitCode {}", sdkError, exitCode));
        listActionsMenu();
    }
}
