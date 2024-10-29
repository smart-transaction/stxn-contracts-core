// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {ILaminator, SolverData, DATATYPE} from "src/interfaces/ILaminator.sol";

library Constants {
    function emptyDataValues() external pure returns (SolverData[] memory dataValues) {
        SolverData memory emptyData = SolverData({name: "", datatype: DATATYPE.UINT256, value: ""});

        dataValues = new SolverData[](1);
        dataValues[0] = emptyData;
    }
}
