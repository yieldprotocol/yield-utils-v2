// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.15;

import "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import "./TransferHelper.sol";
import "../access/AccessControl.sol";
import "../interfaces/ITokenUpgrade.sol";
import "../utils/Cast.sol";
import "../utils/Math.sol";

/// @dev TokenUpgrade is a contract that can be used upgrade tokens at a fixed rate, with
/// the aim of completely replacing the supply of a token by the funds supplied to
/// this contract. It is meant to be used as a token upgrade, when other mechanisms fail.
/// @dev This contract is currently under audit and not eligible for any bounties.
contract TokenUpgrade is AccessControl {
    using Cast for uint256;
    using Math for uint256;
    using TransferHelper for IERC20;

    error SameToken(address token);
    error TokenInNotRegistered(address tokenIn);
    error TokenInAlreadyRegistered(address tokenIn);
    error TokenOutNotRegistered(address tokenOut);
    error TokenOutAlreadyRegistered(address tokenOut);
    error TotalSupplyNotPresent();
    error AlreadyClaimed();
    error NotInMerkleTree();

    event Registered(
        IERC20 indexed tokenIn, IERC20 indexed tokenOut, uint256 tokenInBalance, uint256 tokenOutBalance, uint96 ratio
    );
    event Unregistered(
        IERC20 indexed tokenIn, IERC20 indexed tokenOut, uint256 tokenInBalance, uint256 tokenOutBalance
    );
    event Upgraded(IERC20 indexed tokenIn, IERC20 indexed tokenOut, uint256 tokenInAmount, uint256 tokenOutAmount);
    event Extracted(IERC20 indexed tokenIn, uint256 tokenInBalance);
    event Recovered(IERC20 indexed token, uint256 recovered);

    struct TokenIn {
        IERC20 reverse;
        uint96 ratio;
        uint256 balance;
        bytes32 merkleRoot;
    }

    struct TokenOut {
        IERC20 reverse;
        uint256 balance;
    }

    mapping(IERC20 => TokenIn) public tokensIn;
    mapping(IERC20 => TokenOut) public tokensOut;
    mapping(bytes32 => bool) public isClaimed;

    /// @dev Register a token to be replaced, and the token to replace it with.
    /// The ratio is calculated as the funds of the replacement token divided by the supply of the token to be replaced.
    /// The tokens used as a replacement must have been sent to the contract before this call.
    /// @param tokenIn_ The token to be replaced
    /// @param tokenOut_ The token to replace it with
    /// @param merkleRoot_ the root of the merkle tree for tokenIn_
    function register(IERC20 tokenIn_, IERC20 tokenOut_, bytes32 merkleRoot_) external auth {
        if (address(tokenIn_) == address(tokenOut_)) revert SameToken(address(tokenIn_));
        if (address(tokensIn[tokenIn_].reverse) != address(0)) revert TokenInAlreadyRegistered(address(tokenIn_));
        if (address(tokensOut[tokenOut_].reverse) != address(0)) revert TokenOutAlreadyRegistered(address(tokenOut_));
        if (tokenOut_.balanceOf(address(this)) != tokenOut_.totalSupply()) revert TotalSupplyNotPresent();

        uint96 ratio = tokenOut_.balanceOf(address(this)).wdiv(tokenIn_.totalSupply()).u96();
        uint256 tokenInBalance = tokenIn_.balanceOf(address(this));
        uint256 tokenOutBalance = tokenOut_.balanceOf(address(this));
        tokensIn[tokenIn_] = TokenIn(tokenOut_, ratio, tokenInBalance, merkleRoot_);
        tokensOut[tokenOut_] = TokenOut(tokenIn_, tokenOutBalance);

        emit Registered(tokenIn_, tokenOut_, tokenInBalance, tokenOutBalance, ratio);
    }

    /// @dev Unregister a token to be replaced, and the token to replace it with. Send all related tokens to a given address.
    /// @param tokenIn_ The token to be replaced
    /// @param to The address to send all tokens to
    function unregister(IERC20 tokenIn_, address to) external auth {
        TokenIn memory tokenIn = tokensIn[tokenIn_];
        if (address(tokenIn.reverse) == address(0)) revert TokenInNotRegistered(address(tokenIn_));
        IERC20 tokenOut_ = tokenIn.reverse;

        delete tokensIn[tokenIn_];
        delete tokensOut[tokenOut_];

        // We send all related funds to the given address to make sure it's a clean sweep, not just the tracked balances.
        uint256 tokenInBalance = tokenIn_.balanceOf(address(this));
        uint256 tokenOutBalance = tokenOut_.balanceOf(address(this));
        tokenIn_.safeTransfer(to, tokenInBalance);
        tokenOut_.safeTransfer(to, tokenOutBalance);

        emit Unregistered(tokenIn_, tokenOut_, tokenInBalance, tokenOutBalance);
    }

    /// @dev Extract tokens replaced by this contract.
    /// @param tokenIn_ The token to be replaced
    /// @param to The address to send the tokens to
    function extract(IERC20 tokenIn_, address to) external auth {
        TokenIn memory tokenIn = tokensIn[tokenIn_];
        if (address(tokenIn.reverse) == address(0)) revert TokenInNotRegistered(address(tokenIn_));

        tokensIn[tokenIn_].balance = 0;
        tokenIn_.safeTransfer(to, tokenIn.balance);

        emit Extracted(tokenIn_, tokenIn.balance);
    }

    /// @dev Recover tokens deposited to the contract by mistake
    /// Be careful, the address passed on as a token is not verified to be a valid ERC20 token.
    /// @param token The token to be recovered
    /// @param to The address to send the tokens to
    function recover(IERC20 token, address to) external auth {
        if (address(tokensIn[token].reverse) != address(0)) revert TokenInAlreadyRegistered(address(token));
        if (address(tokensOut[token].reverse) != address(0)) revert TokenOutAlreadyRegistered(address(token));
        uint256 recovered = token.balanceOf(address(this));
        token.safeTransfer(to, recovered);

        emit Recovered(token, recovered);
    }

    /// @dev Upgrade a token for its replacement, at the registered ratio.
    /// The rounding for tokenOutAmount means that the TokenUpgrade contract
    /// gets the left over wei.
    /// @param tokenIn_ The token to be replaced
    /// @param from the owner of tokenIn_
    /// @param tokenInAmount The amount of tokenIn_ to upgrade
    /// @param proof The merkle proof to verify the upgrade
    function upgrade(IERC20 tokenIn_, address from, uint256 tokenInAmount, bytes32[] calldata proof)
        external
    {
        TokenIn memory tokenIn = tokensIn[tokenIn_];
        if (address(tokenIn.reverse) == address(0)) revert TokenInNotRegistered(address(tokenIn_));
        IERC20 tokenOut_ = tokenIn.reverse;

        bytes32 leaf = keccak256(abi.encodePacked(from, tokenInAmount));
        if (isClaimed[leaf]) revert AlreadyClaimed();
        isClaimed[leaf] = true;
        bool isValidLeaf = MerkleProof.verifyCalldata(proof, tokenIn.merkleRoot, leaf);
        if (!isValidLeaf) revert NotInMerkleTree();

        tokenIn_.safeTransferFrom(from, address(this), tokenInAmount);
        uint256 tokenOutAmount = tokenInAmount.wmul(tokenIn.ratio);

        tokensIn[tokenIn_].balance += tokenInAmount;
        tokensOut[tokenOut_].balance -= tokenOutAmount;

        tokenOut_.safeTransfer(from, tokenOutAmount);

        emit Upgraded(tokenIn_, tokenOut_, tokenInAmount, tokenOutAmount);
    }
}
