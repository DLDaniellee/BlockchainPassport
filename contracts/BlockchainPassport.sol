// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title BlockchainPassport
 * @dev 管理護照的發行與狀態更新的智能合約，支持歷史操作記錄
 */
contract BlockchainPassport {
    /// @notice 發行機構（管理員）的地址
    address public admin;

    /// @notice 護照資訊結構
    struct PassportInfo {
        string holderName;     // 持有者姓名
        string nationality;    // 國籍
        uint256 birthDate;     // 出生日期
        uint256 issueDate;     // 發行日期
        uint256 expiryDate;    // 到期日期
        uint8 isValid;         // 狀態（1:有效, 0:無效）
    }

    /// @notice 歷史操作記錄結構
    struct History {
        address updatedBy;     // 更新者地址
        uint256 timestamp;     // 操作時間戳
        string fieldChanged;   // 修改的欄位
        string oldValue;       // 原始值
        string newValue;       // 新值
    }

    /// @dev 儲存護照ID對應的護照資訊
    mapping(string => PassportInfo) private passports;

    /// @dev 儲存護照ID對應的歷史操作記錄
    mapping(string => History[]) private passportHistory;

    /// @notice 發行護照時觸發的事件
    event PassportIssued(string indexed passportID, string holderName);

    /// @notice 更新護照狀態時觸發的事件
    event PassportStatusUpdated(string indexed passportID, uint8 newStatus);

    /// @dev 初始化合約，將管理員設為合約部署者
    constructor() {
        admin = msg.sender;
    }

    /// @dev 僅允許管理員調用的方法修飾符
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this action");
        _;
    }

    /**
     * @notice 發行新護照
     * @dev 僅限管理員操作
     * @param passportID 護照ID（唯一識別碼）
     * @param holderName 持有者姓名
     * @param nationality 國籍
     * @param birthDate 出生日期（Unix時間戳）
     * @param issueDate 發行日期（Unix時間戳）
     * @param expiryDate 到期日期（Unix時間戳）
     * @param isValid 初始狀態（1:有效, 0:無效）
     */
    function issuePassport(
        string memory passportID,
        string memory holderName,
        string memory nationality,
        uint256 birthDate,
        uint256 issueDate,
        uint256 expiryDate,
        uint8 isValid
    ) public onlyAdmin {
        require(bytes(passports[passportID].holderName).length == 0, "Passport ID already exists");
        require(isValid == 0 || isValid == 1, "Invalid status value (must be 0 or 1)");

        passports[passportID] = PassportInfo({
            holderName: holderName,
            nationality: nationality,
            birthDate: birthDate,
            issueDate: issueDate,
            expiryDate: expiryDate,
            isValid: isValid
        });

        // 記錄操作到歷史記錄
        passportHistory[passportID].push(History({
            updatedBy: msg.sender,
            timestamp: block.timestamp,
            fieldChanged: "Issue Passport",
            oldValue: "N/A",
            newValue: holderName
        }));

        emit PassportIssued(passportID, holderName);
    }

    /**
     * @notice 查詢護照資訊
     * @param passportID 護照ID
     * @return holderName 持有者姓名
     * @return nationality 國籍
     * @return birthDate 出生日期
     * @return issueDate 發行日期
     * @return expiryDate 到期日期
     * @return isValid 狀態（1:有效, 0:無效）
     */
    function getPassport(string memory passportID)
        public
        view
        returns (
            string memory holderName,
            string memory nationality,
            uint256 birthDate,
            uint256 issueDate,
            uint256 expiryDate,
            uint8 isValid
        )
    {
        require(bytes(passports[passportID].holderName).length != 0, "Passport ID does not exist");

        PassportInfo memory passport = passports[passportID];

        return (
            passport.holderName,
            passport.nationality,
            passport.birthDate,
            passport.issueDate,
            passport.expiryDate,
            passport.isValid
        );
    }

    /**
     * @notice 更新護照狀態
     * @dev 僅限管理員操作
     * @param passportID 護照ID
     * @param newStatus 新的狀態（1:有效, 0:無效）
     */
    function updatePassportStatus(
        string memory passportID,
        uint8 newStatus
    ) public onlyAdmin {
        require(bytes(passports[passportID].holderName).length != 0, "Passport ID does not exist");
        require(newStatus == 0 || newStatus == 1, "Invalid status value (must be 0 or 1)");

        uint8 oldStatus = passports[passportID].isValid;

        passports[passportID].isValid = newStatus;

        // 記錄操作到歷史記錄
        passportHistory[passportID].push(History({
            updatedBy: msg.sender,
            timestamp: block.timestamp,
            fieldChanged: "isValid",
            oldValue: oldStatus == 1 ? "1" : "0",
            newValue: newStatus == 1 ? "1" : "0"
        }));

        emit PassportStatusUpdated(passportID, newStatus);
    }

    /**
     * @notice 查詢護照的歷史操作記錄
     * @param passportID 護照ID
     * @return history 歷史記錄數組，以可讀格式返回
     */
    function getHistory(string memory passportID) public view returns (string[] memory) {
        require(bytes(passports[passportID].holderName).length != 0, "Passport ID does not exist");

        History[] memory histories = passportHistory[passportID];
        string[] memory formattedHistories = new string[](histories.length);

        for (uint256 i = 0; i < histories.length; i++) {
            History memory history = histories[i];

            formattedHistories[i] = string(
                abi.encodePacked(
                    "UpdatedBy: ", addressToString(history.updatedBy),
                    ", Timestamp: ", uintToString(history.timestamp),
                    ", FieldChanged: ", history.fieldChanged,
                    ", OldValue: ", history.oldValue,
                    ", NewValue: ", history.newValue
                )
            );
        }

        return formattedHistories;
    }

    // Helper function: Convert address to string
    function addressToString(address _addr) private pure returns (string memory) {
        bytes memory addressBytes = abi.encodePacked(_addr);
        bytes memory hexBytes = "0123456789abcdef";
        bytes memory str = new bytes(42);

        str[0] = "0";
        str[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = hexBytes[uint8(addressBytes[i] >> 4)];
            str[3 + i * 2] = hexBytes[uint8(addressBytes[i] & 0x0f)];
        }

        return string(str);
    }

    // Helper function: Convert uint to string
    function uintToString(uint256 _i) private pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 temp = _i;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_i != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(_i % 10)));
            _i /= 10;
        }
        return string(buffer);
    }
}

