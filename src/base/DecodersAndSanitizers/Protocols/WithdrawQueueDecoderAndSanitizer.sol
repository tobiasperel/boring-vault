// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract TellerDecoderAndSanitizer is BaseDecoderAndSanitizer {
    function requestWithdraw(address asset, uint96, /*shares*/ uint16, /*maxLoss*/ bool /*allowThirdPartyToComplete*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset);
    }
}
