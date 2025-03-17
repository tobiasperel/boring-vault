// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {IRecipeMarketHub} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";

abstract contract RoycoWeirollDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error RoycoWeirollDecoderAndSanitizer__TooManyOfferHashes();

    //============================== IMMUTABLES ===============================

    IRecipeMarketHub internal immutable recipeMarketHub;

    constructor(address _recipeMarketHub) {
        recipeMarketHub = IRecipeMarketHub(_recipeMarketHub);
    }

    function fillIPOffers(
        bytes32[] calldata ipOfferHashes,
        uint256[] calldata, /*fillAmounts*/
        address fundingVault,
        address frontendFeeRecipient
    ) external view virtual returns (bytes memory addressesFound) {
        if (ipOfferHashes.length != 1) revert RoycoWeirollDecoderAndSanitizer__TooManyOfferHashes();

        (, bytes32 marketHash,,,,) = recipeMarketHub.offerHashToIPOffer(ipOfferHashes[0]);

        address marketHash0 = address(bytes20(bytes16(marketHash)));
        address marketHash1 = address(bytes20(bytes16(marketHash << 128)));
        return abi.encodePacked(marketHash0, marketHash1, fundingVault, frontendFeeRecipient);
    }

    function executeWithdrawalScript(
        address weirollWallet
    ) external view virtual returns (bytes memory addressesFound) {
        //WeirollWallet will check that the caller is owner (boring vault)
        //but we check here before delegating for safety.
        address owner = IWeirollWalletHelper(weirollWallet).owner();
        return abi.encodePacked(owner);
    }

    function forfeit(
        address weirollWallet,
        bool /*executeWithdraw*/
    ) external view virtual returns (bytes memory addressesFound) {
        //WeirollWallet will check that the caller is owner (boring vault)
        //but we check here before delegating for safety.
        address owner = IWeirollWalletHelper(weirollWallet).owner();
        addressesFound = abi.encodePacked(owner);
    }

    function claim(address weirollWallet, address to) external view virtual returns (bytes memory addressesFound) {
        address owner = IWeirollWalletHelper(weirollWallet).owner();
        addressesFound = abi.encodePacked(owner, to);
    }

    function claim(
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to);
    }

    function merkleWithdraw() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdrawMerkleDeposit(
        address _weirollWallet,
        uint256, /*_merkleDepositNonce*/
        uint256, /*_amountDepositedOnSource*/
        bytes32[] calldata /*_merkleProof*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_weirollWallet);
    }

    //RecipeMarketHub
    function createAPOffer(
        bytes32 targetMarketHash,
        address fundingVault,
        uint256, /*quantity*/
        uint256, /*expiry*/
        address[] calldata incentivesRequested,
        uint256[] calldata /*incentiveAmountsRequested*/
    ) external payable virtual returns (bytes memory addressesFound) {
        // TODO: Decode the recipes from WeirollMarket
        (,address inputToken,,,,,) = recipeMarketHub.marketHashToWeirollMarket(targetMarketHash);
        for (uint256 i = 0; i < incentivesRequested.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, incentivesRequested[i]);
        }
        addressesFound = abi.encodePacked(inputToken, fundingVault, addressesFound);
    }

    function cancelAPOffer(
        DecoderCustomTypes.APOffer calldata offer
    ) external payable virtual returns (bytes memory addressesFound) {
        // TODO: Decode the recipes from WeirollMarket
        (,address inputToken,,,,,) = recipeMarketHub.marketHashToWeirollMarket(offer.targetMarketHash);
        for (uint256 i = 0; i < offer.incentivesRequested.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, offer.incentivesRequested[i]);
        }
        addressesFound = abi.encodePacked(inputToken, offer.ap, offer.fundingVault, addressesFound);
    }

    //VaultMarketHub
    function createAPOffer(
        address targetVault,
        address fundingVault,
        uint256, /*quantity*/
        uint256, /*expiry*/
        address[] calldata incentivesRequested,
        uint256[] calldata /*incentivesRatesRequested*/
    ) external virtual returns (bytes memory addressesFound) {
        for (uint256 i = 0; i < incentivesRequested.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, incentivesRequested[i]);
        }
        addressesFound = abi.encodePacked(targetVault, fundingVault, addressesFound);
    }

    //WrappedVault (other functions handled by ERC4626 decoder)
    function safeDeposit(
        uint256, /*assets*/
        address receiver,
        uint256 /*minShares*/
    ) external virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }
}

interface IWeirollWalletHelper {
    function owner() external view returns (address);
}
