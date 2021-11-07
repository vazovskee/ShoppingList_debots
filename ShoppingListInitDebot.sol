
pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./base/tonlabs/Debot.sol";
import "./base/tonlabs/Terminal.sol";
import "./base/tonlabs/AddressInput.sol";
import "./base/tonlabs/ConfirmInput.sol";
import "./base/tonlabs/Sdk.sol";

import "./base/PurchaseStructs.sol";
import "./base/IShoppingList.sol";
import "./base/HasConstructorWithPubKey.sol";
import "./base/Transactable.sol";

abstract contract ShoppingListInitDebot is Debot {
    
    uint32 INITIAL_BALANCE =  200000000;  // начальный баланс контракта ShoppingList

    TvmCell m_shoppingListStateInit;

    address m_shoppingListAddress;  // адрес контракта ShoppingList
    address m_walletAddress;        // адрес кошелька пользователя
    uint256 m_userPubKey;           // открытый ключ пользователя m_userPubkey
    uint32 m_purchaseId;
    bytes m_icon;

    PurchasesSummary m_summary; // статистика покупок

    function actionMenu() internal virtual {}
    
    // предварительное сохранение байт-кода контракта ShoppingList
    function setShoppingListCode(TvmCell code, TvmCell data) public {
        require(msg.pubkey() == tvm.pubkey(), 101);
        tvm.accept();
        m_shoppingListStateInit = tvm.buildStateInit(code, data);
    }

    // дебот начинёт свою работу с метода start()
    function start() public override {
        Terminal.input(tvm.functionId(savePublicKey), "Please enter your public key", false);
    }

    function savePublicKey(string value) public {
        (uint pubkey, bool isConverted) = stoi("0x" + value); // перевод ключа из строкового в 16-ый формат
        if (isConverted) {
            m_userPubKey = pubkey;

            Terminal.print(0, "Checking if you already have a Shopping List ...");         // обычный вывод строки в терминал без передачи функции обратного вызова
            TvmCell deployState = tvm.insertPubkey(m_shoppingListStateInit, m_userPubKey); // добавляем к состоянию значение первичного ключа пользователя (это сделает состояние уникальным)
            m_shoppingListAddress = address(tvm.hash(deployState));                        // формируем адрес из состояния
            Terminal.print(0, format( "Info: your Shopping List contract address is {}", m_shoppingListAddress));
            Sdk.getAccountType(tvm.functionId(checkAccountStatus), m_shoppingListAddress);

        } else {
            // если конвертирование было некорректным, то ссылаемся на ту же функцию и просим входящие данные заново
            Terminal.input(tvm.functionId(savePublicKey), "Wrong public key. Try again!\nPlease enter your public key", false);
        }
    }

    function checkAccountStatus(int8 acc_type) public { // т.е. переменная acc_type получит значение из Sdk.getAccountType
        if (acc_type == 1) { // acc is active and  contract is already 
            _getStat(tvm.functionId(setStat));

        } else if (acc_type == -1)  { // acc is inactive
            Terminal.print(0, "You don't have a Shopping List list yet, so a new contract with an initial balance of 0.2 tokens will be deployed");
            // показывает пользователю опции со способами ввода адреса кошелька, с которого будет проводиться оплата
            AddressInput.get(tvm.functionId(creditAccount), "Select a wallet for payment. We will ask you to sign two transactions");

        } else if (acc_type == 0) { // acc is uninitialized
            Terminal.print(0, "Deploying new contract. If an error occurs, check if your Shopping List contract has enough tokens on its balance");
            deploy();

        } else if (acc_type == 2) {  // acc is frozen
            Terminal.print(0, format("Can not continue: account {} is frozen", m_shoppingListAddress));
        }
    }

    // перевод кристаллов на адрес, подготовка к деплою
    function creditAccount(address walletAddress) public {
        m_walletAddress = walletAddress;
        optional(uint256) none;
        TvmCell empty;
        Transactable(m_walletAddress).sendTransaction{ // производим транзакцию
            abiVer: 2,
            extMsg: true,
            sign: true,     // транзакция должна быть подписанной
            pubkey: none,   // none = 0, т.е. транзакция без открытого ключа
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(waitBeforeDeploy),    // вызываем функцию, ожидающую деплоя (в цикле)
            onErrorId: tvm.functionId(onErrorRepeatCredit)   // Just repeat if something went wrong
        }(m_shoppingListAddress, INITIAL_BALANCE, false, 3, empty);  // перевод суммы INITIAL_BALANCE на адрес m_shopListAddress
    }

    function waitBeforeDeploy() public  {
        Sdk.getAccountType(tvm.functionId(checkReadyToDepoy), m_shoppingListAddress);
    }

    function checkReadyToDepoy(int8 acc_type) public {
        if (acc_type ==  0) {   // acc is uninitialized
            deploy(); // кристаллы пришли на указанный адрес, можно деплоить контракт
        } else {
            waitBeforeDeploy(); // т.е. две функции образуют петлю, пока аккаунт не получит статус uninitialized
        }
    }

    function deploy() private view {
            TvmCell state = tvm.insertPubkey(m_shoppingListStateInit, m_userPubKey); // состояние с кодом контракта и открытым ключом
            optional(uint256) none;
            TvmCell deployMsg = tvm.buildExtMsg({ // формирование сообщения о деплое (передача параметров в конструктор контракта ShoppingList)
                abiVer: 2,
                dest: m_shoppingListAddress,
                callbackId: tvm.functionId(onSuccess),           // если деплой прошёл успешно
                onErrorId:  tvm.functionId(onErrorRepeatDeploy), // Just repeat if something went wrong
                time: 0,
                expire: 0,
                sign: true,
                pubkey: none,
                stateInit: state,
                call: {HasConstructorWithPubKey, m_userPubKey}  // т.е. будет произведён вызов конструктора ShoppingList с передачей в него открытого ключа пользователя
            });
            tvm.sendrawmsg(deployMsg, 1);
    }

    function onSuccess() public view {
        _getStat(tvm.functionId(setStat));
    }

    function onErrorRepeatDeploy(uint32 sdkError, uint32 exitCode) public view {
        sdkError;
        exitCode;
        deploy();
    }

    function onErrorRepeatCredit(uint32 sdkError, uint32 exitCode) public {
        sdkError;
        exitCode;
        creditAccount(m_walletAddress);
    }

    function _getStat(uint32 answerId) private view {
        optional(uint256) none;
        IShoppingList(m_shoppingListAddress).getSummary{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: 0
        }();
    }

    function setStat(PurchasesSummary stat) public {
        m_summary = stat; // устанавливаем статистику в деботе
        actionMenu(); // показываем  меню
    }

    // Заглушка
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "ShoppingListInit DeBot";
        version = "0.2.0";
        publisher = "TON Labs";
        key = "TODO list manager";
        author = "TON Labs";
        support = address.makeAddrStd(0, 0x66e01d6df5a8d7677d9ab2daf7f258f1e2a7fe73da5320300395f99e01dc3b5f);
        hello = "Hi, i'm a TODO DeBot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() virtual public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, AddressInput.ID, ConfirmInput.ID ];
    }
}
