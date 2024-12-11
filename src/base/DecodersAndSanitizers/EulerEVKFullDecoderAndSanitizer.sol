// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";

contract EulerEVKFullDecoderAndSanitizer is EulerEVKDecoderAndSanitizer {

    constructor(address _boringVault) EulerEVKDecoderAndSanitizer(_boringVault) {}

}
