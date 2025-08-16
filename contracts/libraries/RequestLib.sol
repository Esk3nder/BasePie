// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPieVault} from "../interfaces/IPieVault.sol";

library RequestLib {
    // Custom errors
    error InvalidRequest();
    error RequestNotPending();
    error RequestAlreadyExecuted();
    error UnauthorizedCaller();
    error WindowMismatch();
    
    uint256 constant DECIMAL_CONVERSION = 1e12; // 10^(18-6) for USDC to shares conversion
    
    function validateClaim(IPieVault.Request memory request, address caller) internal pure {
        if (request.status != IPieVault.RequestStatus.Executed) {
            revert RequestAlreadyExecuted();
        }
        if (caller != request.receiver && caller != request.owner) {
            revert UnauthorizedCaller();
        }
        if (request.executedAmount == 0) {
            revert InvalidRequest();
        }
    }
    
    function validateCancel(IPieVault.Request memory request, address caller) internal pure {
        if (request.status != IPieVault.RequestStatus.Pending) {
            revert RequestNotPending();
        }
        if (caller != request.owner) {
            revert UnauthorizedCaller();
        }
    }
    
    function validateExecution(IPieVault.Request memory request, uint40 windowId) internal pure {
        if (request.status != IPieVault.RequestStatus.Pending) {
            revert RequestNotPending();
        }
        if (request.windowId > windowId) {
            revert WindowMismatch();
        }
    }
    
    function transitionStatus(
        IPieVault.Request storage request,
        IPieVault.RequestStatus newStatus
    ) internal {
        // Validate state transition
        IPieVault.RequestStatus currentStatus = request.status;
        
        // Valid transitions:
        // None -> Pending
        // Pending -> Executed, Cancelled
        // Executed -> Claimed
        // Cancelled -> (terminal)
        // Claimed -> (terminal)
        
        if (currentStatus == IPieVault.RequestStatus.None && newStatus != IPieVault.RequestStatus.Pending) {
            revert InvalidRequest();
        }
        if (currentStatus == IPieVault.RequestStatus.Pending) {
            if (newStatus != IPieVault.RequestStatus.Executed && 
                newStatus != IPieVault.RequestStatus.Cancelled) {
                revert InvalidRequest();
            }
        }
        if (currentStatus == IPieVault.RequestStatus.Executed && newStatus != IPieVault.RequestStatus.Claimed) {
            revert InvalidRequest();
        }
        if (currentStatus == IPieVault.RequestStatus.Cancelled || 
            currentStatus == IPieVault.RequestStatus.Claimed) {
            revert InvalidRequest(); // Terminal states
        }
        
        request.status = newStatus;
    }
    
    function calculateSharesForDeposit(
        uint256 assetsIn,
        uint256 totalSupplyBefore,
        uint256 navBefore
    ) internal pure returns (uint256) {
        if (totalSupplyBefore == 0 || navBefore == 0) {
            // First deposit: 1 USDC = 1e12 shares (scaling from 6 to 18 decimals)
            return assetsIn * DECIMAL_CONVERSION;
        } else {
            // Proportional shares: shares = (totalSupply * assetsIn) / navBefore
            return (totalSupplyBefore * assetsIn) / navBefore;
        }
    }
    
    function calculateAssetsForRedeem(
        uint256 sharesToBurn,
        uint256 totalSupplyBefore,
        uint256 navBefore
    ) internal pure returns (uint256) {
        if (totalSupplyBefore == 0) {
            return 0;
        }
        // assets = (navBefore * sharesToBurn) / totalSupplyBefore
        return (navBefore * sharesToBurn) / totalSupplyBefore;
    }
}