// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {IERC173} from "../interfaces/IERC173.sol";

contract OwnershipFacet is IERC173 {
    AppStorage internal s;

    function transferOwnership(address _newOwner) external override {
        LibAppStorage.enforceIsContractOwner();
        LibAppStorage.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibAppStorage.contractOwner();
    }
}

