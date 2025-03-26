// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {IBoringChef} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";

abstract contract BoringChefDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== IMMUTABLES ===============================
    IBoringChef internal immutable boringChef;

    constructor(address _boringChef) {
        boringChef = IBoringChef(_boringChef);
    }

    // BoringVault that inherits from BoringChef
    function claimRewards(uint256[] calldata rewardIds) external view virtual returns (bytes memory addressesFound) {
        for (uint256 i = 0; i < rewardIds.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, boringChef.rewards(rewardIds[i]).token);
        }
    }

    function claimRewardsOnBehalfOfUser(uint256[] calldata rewardIds, address user)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i = 0; i < rewardIds.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, boringChef.rewards(rewardIds[i]).token);
        }
        addressesFound = abi.encodePacked(addressesFound, user);
    }
}
