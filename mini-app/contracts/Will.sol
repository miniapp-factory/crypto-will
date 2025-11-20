pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CryptoWill
 * @notice A contract that transfers all funds to a designated will wallet
 *         after a configurable period of inactivity. The owner can
 *         configure the will address, inactivity period, and revoke the will.
 */
contract CryptoWill is Ownable, ReentrancyGuard {
    /// @notice Address that will receive the funds after inactivity
    address public willAddress;

    /// @notice Inactivity period in seconds (default 6 months)
    uint256 public inactivityPeriod;

    /// @notice Timestamp of the last activity (any transaction to this contract)
    uint256 public lastActivity;

    /// @notice Indicates whether the will has been revoked
    bool public revoked;

    event WillSet(address indexed will, uint256 period);
    event WillRevoked();
    event FundsTransferred(address indexed to, uint256 amount);

    constructor(address _will, uint256 _period) {
        require(_will != address(0), "Invalid will address");
        require(_period > 0, "Period must be > 0");
        willAddress = _will;
        inactivityPeriod = _period;
        lastActivity = block.timestamp;
    }

    /**
     * @notice Update the will address and inactivity period.
     * @dev Only callable by the owner.
     */
    function setWill(address _will, uint256 _period) external onlyOwner {
        require(_will != address(0), "Invalid will address");
        require(_period > 0, "Period must be > 0");
        willAddress = _will;
        inactivityPeriod = _period;
        revoked = false;
        emit WillSet(_will, _period);
    }

    /**
     * @notice Revoke the will. After revocation, the owner can set a new will.
     */
    function revokeWill() external onlyOwner {
        revoked = true;
        emit WillRevoked();
    }

    /**
     * @notice Fallback function to accept ETH and update activity timestamp.
     */
    receive() external payable {
        lastActivity = block.timestamp;
    }

    /**
     * @notice Transfer all funds to the will address if inactivity period has elapsed.
     * @dev Can be called by anyone. Reverts if the will is revoked or period not elapsed.
     */
    function executeWill() external nonReentrant {
        require(!revoked, "Will revoked");
        require(block.timestamp >= lastActivity + inactivityPeriod, "Inactivity period not elapsed");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to transfer");
        (bool sent, ) = willAddress.call{value: balance}("");
        require(sent, "Transfer failed");
        emit FundsTransferred(willAddress, balance);
    }

    /**
     * @notice Allows the owner to withdraw any ERC20 tokens accidentally sent to this contract.
     * @dev Only callable by the owner.
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
