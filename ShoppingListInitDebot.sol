
pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./base/tonlabs/Debot.sol";
import "./base/tonlabs/Terminal.sol";
import "./base/tonlabs/AddressInput.sol";
import "./base/tonlabs/ConfirmInput.sol";
import "./base/tonlabs/Menu.sol";
import "./base/tonlabs/Sdk.sol";

import "./base/PurchaseStructs.sol";
import "./base/IShoppingList.sol";
import "./base/HasConstructorWithPubKey.sol";
import "./base/Transactable.sol";

abstract contract ShoppingListInitDebot is Debot {
    
    uint32 INITIAL_BALANCE =  200000000;  // начальный баланс контракта ShoppingList

    TvmCell m_shoppingListStateInit; // для формирования состояния перед деплоем

    address m_shoppingListAddress;   // адрес контракта ShoppingList
    address m_walletAddress;         // адрес кошелька пользователя
    uint256 m_userPubKey;            // открытый ключ пользователя
    bytes m_icon;

    PurchasesSummary m_summary;      // статистика покупок

    // деботы-потомки должны будут реализовать меню
    function listActionsMenu() internal virtual {}

    // формируем состояние из кода и данных контракта ShoppingList
    function setShoppingListCode(TvmCell code, TvmCell data) public {
        require(msg.pubkey() == tvm.pubkey(), 101);
        tvm.accept();
        m_shoppingListStateInit = tvm.buildStateInit(code, data);
    }

    // дебот начинает свою работу с метода start()
    function start() public override {
        Terminal.input(tvm.functionId(savePublicKey), "Please enter your public key", false);
    }

    function savePublicKey(string value) public {
        (uint pubKey, bool isConverted) = stoi("0x" + value); // перевод значения из строкового в 16-ый формат
        if (isConverted) {
            m_userPubKey = pubKey;

            Terminal.print(0, "Checking if you already have a Shopping List ...");
            TvmCell deployState = tvm.insertPubkey(m_shoppingListStateInit, m_userPubKey); // добавляем к исходному состоянию значение первичного ключа пользователя
            m_shoppingListAddress = address(tvm.hash(deployState));                        // формируем адрес из состояния
            Terminal.print(0, format( "Info: your Shopping List contract address is {}", m_shoppingListAddress));
            Sdk.getAccountType(tvm.functionId(checkAccountStatus), m_shoppingListAddress);

        } else {
            // если конвертирование было некорректным, то ссылаемся на ту же функцию и просим входящие данные заново
            Terminal.input(tvm.functionId(savePublicKey), "Wrong public key. Try again!\nPlease enter your public key", false);
        }
    }

    // производит различные действия в зависимости от текущего состояния аккаунта
    function checkAccountStatus(int8 acc_type) public {
        if (acc_type == 1) {         // аккаунт активен и контракт уже задеплоен 
            _getSummary(tvm.functionId(setSummary));

        } else if (acc_type == -1) { // аккаунт неактивен (нет средств)
            Terminal.print(0, "You don't have a Shopping List list yet, so a new contract with an initial balance of 0.2 tokens will be deployed");
            // показывает пользователю опции со способами ввода адреса кошелька, с которого будет проводиться оплата
            AddressInput.get(tvm.functionId(creditAccount), "Select a wallet for payment. We will ask you to sign two transactions");

        } else if (acc_type == 0) { // аккаунт неинициализирован (есть средства, но ещё не задеплоен)
            Terminal.print(0, "Deploying new contract. If an error occurs, check if your Shopping List contract has enough tokens on its balance");
            deploy();

        } else if (acc_type == 2) { // аккаунт заморожен
            Terminal.print(0, format("Can not continue: account {} is frozen", m_shoppingListAddress));
        }
    }

    // перевод кристаллов на адрес контракта ShoppingList, подготовка к деплою
    function creditAccount(address value) public {
        m_walletAddress = value;
        optional(uint256) none;
        TvmCell empty;
        Transactable(m_walletAddress).sendTransaction{ // производим транзакцию
            abiVer: 2,
            extMsg: true,
            sign: true,     // транзакция должна быть подписана
            pubkey: none,   // транзакция без открытого ключа
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(waitBeforeDeploy),    // вызываем функцию, ожидающую деплоя
            onErrorId: tvm.functionId(onError)
        }(m_shoppingListAddress, INITIAL_BALANCE, false, 3, empty);  // перевод суммы INITIAL_BALANCE на адрес m_shoppingListAddress
    }

    // ожидание деплоя (образует петлю с checkReadyToDepoy)
    function waitBeforeDeploy() public  {
        Sdk.getAccountType(tvm.functionId(checkReadyToDepoy), m_shoppingListAddress);
    }

    // во время ожидания каждый раз проверяем, заделоился ли аккаунт
    function checkReadyToDepoy(int8 acc_type) public {
        if (acc_type ==  0) {
            deploy();           // кристаллы пришли на указанный адрес, можно деплоить контракт
        } else {
            waitBeforeDeploy(); // т.е. две функции образуют петлю, пока аккаунт не получит статус "неинициализированный"
        }
    }

    function deploy() private view {
        TvmCell state = tvm.insertPubkey(m_shoppingListStateInit, m_userPubKey); // состояние с кодом контракта и открытым ключом
        optional(uint256) none;
        TvmCell deployMsg = tvm.buildExtMsg({ // формирование сообщения о деплое (передача параметров в конструктор контракта ShoppingList)
            abiVer: 2,
            dest: m_shoppingListAddress,
            callbackId: tvm.functionId(onSuccess), // если деплой прошёл успешно
            onErrorId:  tvm.functionId(onError),
            time: 0,
            expire: 0,
            sign: true,
            pubkey: none,
            stateInit: state,
            call: {HasConstructorWithPubKey, m_userPubKey}  // т.е. будет произведён вызов конструктора ShoppingList с передачей в него открытого ключа пользователя
        });
        tvm.sendrawmsg(deployMsg, 1);
    }

    // в случае успешного выполнения операции получаем и запоминаем сводку о покупках
    function onSuccess() public view {
        _getSummary(tvm.functionId(setSummary));
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("ERROR: sdkError {}, exitCode {}", sdkError, exitCode));
    }

    // получаем сводку о покупках у контракта ShoppingList
    function _getSummary(uint32 answerId) private view {
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

    function setSummary(PurchasesSummary summary) public {
        m_summary = summary;  // устанавливаем сводку о покупках в деботе
        listActionsMenu();    // показываем меню
    }

    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Shopping List DeBot";
        author = "vazovskee";
        hello = "It's a Shopping List DeBot.";
        language = "en";
        dabi = m_debotAbi.get();
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, AddressInput.ID, ConfirmInput.ID, Menu.ID ];
    }
}
