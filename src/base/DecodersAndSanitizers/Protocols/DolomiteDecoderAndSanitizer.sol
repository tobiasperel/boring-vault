// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract DolomiteDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Errors  ===============================
   
    error DolomiteDecoderAndSanitizer__ArrayLengthGTOne(); 
    
    //============================== DepositWithdrawalProxy Functions ===============================

    /////////////////// WAD Scaled Functions //////////////////

    //account numbers are owned by wallet address, so no need to sanitize
    function depositWei(uint256, /*_toAccountNumber*/ uint256 _marketId, uint256 /*_amountWei*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_marketId);
    }

    function depositWeiIntoDefaultAccount(uint256 _marketId, uint256 /*_amountWei*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_marketId);
    }

    function withdrawWei(
        uint256, /*_fromAccountNumber*/
        uint256 _marketId,
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_marketId);
    }

    function withdrawWeiFromDefaultAccount(
        uint256 _marketId,
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_marketId);
    }

    /////////////////// Native ETH Functions //////////////////

    function depositETH(uint256 /*_toAccountNumber*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function depositETHIntoDefaultAccount() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdrawETH(
        uint256, /*_fromAccountNumber*/
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdrawETHFromDefaultAccount(
        uint256, /*_amountWei*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    /////////////////// Par Scaled Functions //////////////////

    function depositPar(uint256, /*_toAccountNumber*/ uint256 _marketId, uint256 /*_amountPar*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_marketId);
    }

    function depositParIntoDefaultAccount(uint256 _marketId, uint256 /*_amountPar*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_marketId);
    }

    function withdrawPar(
        uint256, /*_fromAccountNumber*/
        uint256 _marketId,
        uint256, /*_amountPar*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_marketId);
    }

    function withdrawParFromDefaultAccount(
        uint256 _marketId,
        uint256, /*_amountPar*/
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_marketId);
    }

    //============================== BorrowPositionProxy Functions ===============================

    function openBorrowPosition(
        uint256 /*_fromAccountNumber*/,
        uint256 /*_toAccountNumber*/,
        uint256 _marketId,
        uint256 /*_amountWei*/,
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_marketId);   
    }

    function closeBorrowPosition(
        uint256 /*_borrowAccountNumber*/,
        uint256 /*_toAccountNumber*/,
        uint256[] calldata _collateralMarketIds
    ) external pure virtual returns (bytes memory addressesFound) {
        if (_collateralMarketIds.length > 1) revert DolomiteDecoderAndSanitizer__ArrayLengthGTOne(); 
        addressesFound = abi.encodePacked(_collateralMarketIds[0]); 
     }

    function repayAllForBorrowPosition(
        uint256 /*_fromAccountNumber*/,
        uint256 /*_borrowAccountNumber*/,
        uint256 _marketId,
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_marketId); 
    }

    function transferBetweenAccounts(
        uint256 /*_fromAccountNumber*/,
        uint256 /*_amountWei*/,
        uint256 _marketId,
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_marketId); 
     }

    function openBorrowPositionWithDifferentAccounts(
        address _fromAccountOwner,
        uint256 /*_fromAccountNumber*/,
        address _toAccountOwner,
        uint256 /*_toAccountNumber*/,
        uint256 _marketId,
        uint256 /*_amountWei*/,
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_fromAccountOwner, _toAccountOwner, _marketId); 
    }

    function closeBorrowPositionWithDifferentAccounts(
        address _borrowAccountOwner,
        uint256 /*_borrowAccountNumber*/,
        address _toAccountOwner,
        uint256 /*_toAccountNumber*/,
        uint256[] calldata _collateralMarketIds
    ) external pure virtual returns (bytes memory addressesFound) {
        if (_collateralMarketIds.length > 1) revert DolomiteDecoderAndSanitizer__ArrayLengthGTOne(); 
        addressesFound = abi.encodePacked(_borrowAccountOwner, _toAccountOwner, _collateralMarketIds[0]); 
    }

     function transferBetweenAccountsWithDifferentAccounts(
        address _fromAccountOwner,
        uint256 /*_fromAccountNumber*/,
        address _toAccountOwner,
        uint256 /*_toAccountNumber*/,
        uint256 _marketId,
        uint256 /*_amountWei*/,
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_fromAccountOwner, _toAccountOwner, _marketId); 
    }

    function repayAllForBorrowPositionWithDifferentAccounts(
        address _fromAccountOwner,
        uint256 /*_fromAccountNumber*/,
        address _borrowAccountOwner,
        uint256 /*_borrowAccountNumber*/,
        uint256 _marketId,
        DecoderCustomTypes.BalanceCheckFlag /*_balanceCheckFlag*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_fromAccountOwner, _borrowAccountOwner, _marketId); 
    }
}
