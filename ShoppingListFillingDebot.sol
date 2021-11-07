
pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./base/tonlabs/Menu.sol";

import "./ShoppingListInitDebot.sol";

contract ShoppingListFillingDebot is ShoppingListInitDebot {

    function actionMenu() internal override {
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
            // показываем кнопки для дальнейшего взаимодействия с деботом
            [
                MenuItem("Add new purchase","",tvm.functionId(addPurchase))
            ]
        );
    }

    function addPurchase(uint32 index) public {
        index = index; // index of selected menu option
        Terminal.input(tvm.functionId(addPurchase_), "One line please:", true);
    }

    function addPurchase_(string title) public view {
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
            }(title, 42);
    }
    
    function onErrorListInteraction(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Operation failed. sdkError {}, exitCode {}", sdkError, exitCode));
        actionMenu();
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, AddressInput.ID, ConfirmInput.ID, Menu.ID ];
    }
}
