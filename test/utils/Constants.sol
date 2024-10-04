// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {ILaminator} from "src/interfaces/ILaminator.sol";

library Constants {
    function emptyDataValues() external view returns (ILaminator.AdditionalData[] memory dataValues) {
        ILaminator.AdditionalData memory emptyData = ILaminator.AdditionalData({name: "", datatype: "", value: ""});

        dataValues = new ILaminator.AdditionalData[](1);
        dataValues[0] = emptyData;
    }
}
