
pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;

import "PurchaseStructs.sol";

interface IShoppingList {
    function addPurchase(string title, uint32 quantity) external;
    function deletePurchase(uint32 id) external;
    function confirmPurchase(uint32 id, uint32 price) external;

    function getPurchases() external view returns (Purchase[] purchases);
    function getSummary() external view returns (PurchasesSummary);
}