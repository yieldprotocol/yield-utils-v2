// SPDX-License-Identifier: MIT
// Taken from https://github.com/Uniswap/uniswap-lib/blob/master/contracts/libraries/TransferHelper.sol
pragma solidity ^0.8.0;

library Address {
    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= 0, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: 0}(data);
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(target.code.length > 0, "Address: call to non-contract");
            }
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
