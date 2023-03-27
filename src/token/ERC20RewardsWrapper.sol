// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "./ERC20.sol";
import { AccessControl } from "../access/AccessControl.sol";
import { TransferHelper } from "./TransferHelper.sol";

/**
 * @dev This ERC20 tokenized vault overcomes the ERC20Rewards limitation of not being able to change the rewards token.
 * A permissioned function allows to mint shares to an address.
 * A permissioned function allows to set or change the asset.
 * When changing the asset, the caller may consider keeping the price per share constant.
 * A permissioned function allows to extract any tokens except the asset to any address.
 * On transfer, the token is burned and the recipient receives his share of assets.
 * Two helper functions allow to convert between assets and shares.
 */
contract ERC20RewardsWrapper is ERC20, AccessControl() {
    using TransferHelper for ERC20;

    event AssetSet(ERC20 newAsset);
    event Skimmed(ERC20 token, address to);

    ERC20 public asset;

    constructor (string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_, decimals_) {}

    /// @dev Total assets held by the contract.
    function totalAssets() external view virtual returns (uint256) {
        return asset != ERC20(address(0)) ? asset.balanceOf(address(this)) : 0;
    }

    /// @dev Convert shares to assets.
    function convertToAssets(uint256 shares) external view virtual returns (uint256) {
        require(asset != ERC20(address(0)), "Asset not set");
        return _totalSupply > 0 ? asset.balanceOf(address(this)) * shares / _totalSupply : 0;
    }
    
    /// @dev Convert assets to shares.
    function convertToShares(uint256 assets) external view returns (uint256) {
        require(asset != ERC20(address(0)), "Asset not set");
        uint _totalAssets = asset.balanceOf(address(this));
        return _totalAssets > 0 ? assets * _totalSupply / _totalAssets : 0;
    }

    /// @dev A permissioned function that allows to set or change the asset.
    /// @notice If changing the asset, the caller may consider keeping the price per share constant in USD or ETH terms.
    /// After changing the asset, use `skim` to remove any old funds.
    /// Be careful what address you pass on as an ERC20, it is not validated in any way.
    /// Funds should be transferred before this call. Consider rounding.
    function set(ERC20 asset_) external virtual auth {
        asset = asset_;

        emit AssetSet(asset_);
    }

    /// @dev A permissioned function that allows to extract any tokens except the asset to any address.
    /// @notice Be careful what address you pass on as an ERC20, it is not validated in any way.
    function skim(ERC20 token, address to) external virtual auth {
        require(token != asset, "Cannot skim asset");
        token.safeTransfer(to, token.balanceOf(address(this)));

        emit Skimmed(token, to);
    }

    /// @dev A permissioned function that allows to mint shares to an address, if the asset is set.
    /// @notice If minting with a non-zero supply, the price per share will change unless funds are added in the exact amount needed.
    function mint(address to, uint256 amount) external virtual auth {
        _mint(to, amount);
    }

    /// @dev On transfer, the token is burned and the recipient receives his share of assets.
    /// @notice If the asset is not a valid ERC20, the transfer may fail.
    function _transfer(address sender, address recipient, uint256 shares) internal virtual override returns (bool) {
        uint assetAmount = asset.balanceOf(address(this)) * shares / _totalSupply;
        _burn(sender, shares);
        asset.safeTransfer(recipient, assetAmount);
        return true;
    }
}
