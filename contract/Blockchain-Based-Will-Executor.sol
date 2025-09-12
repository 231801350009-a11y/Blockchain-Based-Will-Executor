// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Blockchain-Based Will Executor
 * @dev Smart contract for decentralized will creation and execution
 * @author Blockchain Will Executor Team
 */
contract WillExecutor {
    
    // Events
    event WillCreated(uint256 indexed willId, address indexed testator, string testatorName);
    event WillExecuted(uint256 indexed willId, address indexed executor);
    event BeneficiaryAdded(uint256 indexed willId, address indexed beneficiary, uint256 allocation);
    
    // Structs
    struct Beneficiary {
        address beneficiaryAddress;
        string name;
        uint256 allocationPercentage;
        string assetDescription;
        bool claimed;
    }
    
    struct Will {
        uint256 id;
        address testator;
        string testatorName;
        string executionConditions;
        bool isExecuted;
        bool isActive;
        uint256 creationTimestamp;
        uint256 executionTimestamp;
        mapping(uint256 => Beneficiary) beneficiaries;
        uint256 beneficiaryCount;
        uint256 totalValue;
    }
    
    // State variables
    mapping(uint256 => Will) public wills;
    mapping(address => uint256[]) public testatorWills;
    mapping(address => bool) public authorizedExecutors;
    
    uint256 public willCounter;
    address public owner;
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyTestator(uint256 _willId) {
        require(wills[_willId].testator == msg.sender, "Only testator can modify this will");
        _;
    }
    
    modifier onlyAuthorizedExecutor() {
        require(authorizedExecutors[msg.sender] || msg.sender == owner, "Not authorized to execute wills");
        _;
    }
    
    modifier willExists(uint256 _willId) {
        require(_willId > 0 && _willId <= willCounter, "Will does not exist");
        _;
    }
    
    modifier willNotExecuted(uint256 _willId) {
        require(!wills[_willId].isExecuted, "Will already executed");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        willCounter = 0;
        authorizedExecutors[msg.sender] = true;
    }
    
    /**
     * @dev Core Function 1: Create a new will
     * @param _testatorName Name of the person creating the will
     * @param _executionConditions Conditions required for will execution
     */
    function createWill(
        string memory _testatorName,
        string memory _executionConditions
    ) external payable returns (uint256) {
        require(bytes(_testatorName).length > 0, "Testator name cannot be empty");
        require(bytes(_executionConditions).length > 0, "Execution conditions cannot be empty");
        
        willCounter++;
        uint256 newWillId = willCounter;
        
        Will storage newWill = wills[newWillId];
        newWill.id = newWillId;
        newWill.testator = msg.sender;
        newWill.testatorName = _testatorName;
        newWill.executionConditions = _executionConditions;
        newWill.isExecuted = false;
        newWill.isActive = true;
        newWill.creationTimestamp = block.timestamp;
        newWill.beneficiaryCount = 0;
        newWill.totalValue = msg.value;
        
        testatorWills[msg.sender].push(newWillId);
        
        emit WillCreated(newWillId, msg.sender, _testatorName);
        
        return newWillId;
    }
    
    /**
     * @dev Core Function 2: Add beneficiary to a will
     * @param _willId ID of the will
     * @param _beneficiaryAddress Address of the beneficiary
     * @param _beneficiaryName Name of the beneficiary
     * @param _allocationPercentage Percentage allocation (0-100)
     * @param _assetDescription Description of assets allocated
     */
    function addBeneficiary(
        uint256 _willId,
        address _beneficiaryAddress,
        string memory _beneficiaryName,
        uint256 _allocationPercentage,
        string memory _assetDescription
    ) external 
      willExists(_willId) 
      onlyTestator(_willId) 
      willNotExecuted(_willId) 
    {
        require(_beneficiaryAddress != address(0), "Invalid beneficiary address");
        require(_allocationPercentage > 0 && _allocationPercentage <= 100, "Invalid allocation percentage");
        require(bytes(_beneficiaryName).length > 0, "Beneficiary name cannot be empty");
        
        Will storage will = wills[_willId];
        uint256 beneficiaryIndex = will.beneficiaryCount;
        
        // Check total allocation doesn't exceed 100%
        uint256 totalAllocation = _allocationPercentage;
        for (uint256 i = 0; i < will.beneficiaryCount; i++) {
            totalAllocation += will.beneficiaries[i].allocationPercentage;
        }
        require(totalAllocation <= 100, "Total allocation exceeds 100%");
        
        will.beneficiaries[beneficiaryIndex] = Beneficiary({
            beneficiaryAddress: _beneficiaryAddress,
            name: _beneficiaryName,
            allocationPercentage: _allocationPercentage,
            assetDescription: _assetDescription,
            claimed: false
        });
        
        will.beneficiaryCount++;
        
        emit BeneficiaryAdded(_willId, _beneficiaryAddress, _allocationPercentage);
    }
    
    /**
     * @dev Core Function 3: Execute a will and distribute assets
     * @param _willId ID of the will to execute
     */
    function executeWill(uint256 _willId) 
        external 
        willExists(_willId) 
        onlyAuthorizedExecutor 
        willNotExecuted(_willId) 
    {
        Will storage will = wills[_willId];
        require(will.isActive, "Will is not active");
        require(will.beneficiaryCount > 0, "No beneficiaries defined");
        
        // Mark will as executed
        will.isExecuted = true;
        will.executionTimestamp = block.timestamp;
        
        // Distribute assets to beneficiaries
        uint256 contractBalance = will.totalValue;
        
        for (uint256 i = 0; i < will.beneficiaryCount; i++) {
            Beneficiary storage beneficiary = will.beneficiaries[i];
            if (!beneficiary.claimed) {
                uint256 amount = (contractBalance * beneficiary.allocationPercentage) / 100;
                beneficiary.claimed = true;
                
                // Transfer funds to beneficiary
                if (amount > 0) {
                    payable(beneficiary.beneficiaryAddress).transfer(amount);
                }
            }
        }
        
        emit WillExecuted(_willId, msg.sender);
    }
    
    // Additional utility functions
    function getWillDetails(uint256 _willId) 
        external 
        view 
        willExists(_willId) 
        returns (
            address testator,
            string memory testatorName,
            string memory executionConditions,
            bool isExecuted,
            bool isActive,
            uint256 creationTimestamp,
            uint256 beneficiaryCount,
            uint256 totalValue
        ) 
    {
        Will storage will = wills[_willId];
        return (
            will.testator,
            will.testatorName,
            will.executionConditions,
            will.isExecuted,
            will.isActive,
            will.creationTimestamp,
            will.beneficiaryCount,
            will.totalValue
        );
    }
    
    function getBeneficiary(uint256 _willId, uint256 _beneficiaryIndex) 
        external 
        view 
        willExists(_willId) 
        returns (
            address beneficiaryAddress,
            string memory name,
            uint256 allocationPercentage,
            string memory assetDescription,
            bool claimed
        ) 
    {
        require(_beneficiaryIndex < wills[_willId].beneficiaryCount, "Beneficiary index out of bounds");
        
        Beneficiary storage beneficiary = wills[_willId].beneficiaries[_beneficiaryIndex];
        return (
            beneficiary.beneficiaryAddress,
            beneficiary.name,
            beneficiary.allocationPercentage,
            beneficiary.assetDescription,
            beneficiary.claimed
        );
    }
    
    function getTestatorWills(address _testator) external view returns (uint256[] memory) {
        return testatorWills[_testator];
    }
    
    function authorizeExecutor(address _executor) external onlyOwner {
        authorizedExecutors[_executor] = true;
    }
    
    function revokeExecutor(address _executor) external onlyOwner {
        authorizedExecutors[_executor] = false;
    }
    
    function deactivateWill(uint256 _willId) external willExists(_willId) onlyTestator(_willId) willNotExecuted(_willId) {
        wills[_willId].isActive = false;
    }
    
    function reactivateWill(uint256 _willId) external willExists(_willId) onlyTestator(_willId) willNotExecuted(_willId) {
        wills[_willId].isActive = true;
    }
    
    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    receive() external payable {}
}
