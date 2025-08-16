// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPieVault} from "../../contracts/interfaces/IPieVault.sol";

contract MockPieVault is IPieVault {
    string public name;
    string public symbol;
    address[] public assets;
    uint16[] public weightsBps;
    address public creator;
    address public feeReceiver;
    uint16 public mgmtFeeBps;
    uint32 public rebalanceWindowStartSecUTC;
    
    bool public initialized;
    
    function initialize(
        string memory _name,
        string memory _symbol,
        address[] memory _assets,
        uint16[] memory _weightsBps,
        address _creator,
        address _feeReceiver,
        uint16 _mgmtFeeBps,
        uint32 _rebalanceWindowStartSecUTC
    ) external override {
        require(!initialized, "Already initialized");
        initialized = true;
        
        name = _name;
        symbol = _symbol;
        assets = _assets;
        weightsBps = _weightsBps;
        creator = _creator;
        feeReceiver = _feeReceiver;
        mgmtFeeBps = _mgmtFeeBps;
        rebalanceWindowStartSecUTC = _rebalanceWindowStartSecUTC;
    }
    
    function asset() external pure override returns (address) {
        // Return USDC address on Base
        return 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    }
    
    function totalAssets() external pure override returns (uint256) {
        return 0;
    }
}