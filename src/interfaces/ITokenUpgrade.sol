// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IAccessControl } from "./IAccessControl.sol";
import { IERC20 } from "../token/IERC20.sol";

interface ITokenUpgrade is IAccessControl {
    struct TokenIn {
        IERC20 reverse;
        uint96 ratio;
        uint256 balance;
    }

    struct TokenOut {
        IERC20 reverse;
        uint256 balance;     
    }

    function tokensIn(IERC20 tokenIn) external view returns (TokenIn memory);
    function tokensOut(IERC20 tokenOut) external view returns (TokenOut memory);
    function register(IERC20 tokenIn, IERC20 tokenOut) external;
    function unregister(IERC20 tokenIn, address to) external;
    function swap(IERC20 tokenIn, address to) external;
    function extract(IERC20 tokenIn, address to) external;
    function recover(IERC20 token, address to) external;
}