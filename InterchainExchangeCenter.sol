pragma solidity >=0.4.22 <0.7.0;
import "./BMCMockContract.sol";
import "./NonFungibleTokenInterface.sol";
import "./IERC20.sol";

/**
 * @title Storage
 * @dev Store & retreive value in a variable
 */
contract InterchainExchangeCenter {

    // gwei
    uint public constant minimumIssueValue = 1000000000;
    string serviceName = "ExchangeCenter";
    
    mapping(address => bool) public participatingIssuingContract;
    mapping(string => string) public blockchainNetworkAddress;
    mapping(string => address) public issuingContractAddresses;
    string[] public issuingBlockchainsLUT;
    mapping(bytes32 => bool) public redeemedTransactions;
    BMCMockContract public bmcContract;
    uint256 public lockedBalances;
    mapping(string => IERC20) public fungibleTokens;
    mapping(string => NonFungibleTokenInterface) public nonFungibleTokens;
    mapping(string => uint256) public lockedFungibleTokens;
    mapping(string => uint256) public lockedNonFungibleTokens;
    
    // Delegate Call or BMC Contract
    constructor(address addr) public {
        bmcContract = BMCMockContract(addr);
    }

    struct RedeemData {
        address issueContractAddress;   // the contract which has burnt the tokens on the other blockchian
        address payable redeemerAddress;
        address depositContractAddress;
        uint value;        // the value to create on this chain
        bool isBurnValid;    // indicates whether the burning of tokens has taken place (didn't abort, e.g., due to require statement)
    }
    
    struct RedeemLog{
        uint redeemLogId;
        string tokenIdentifier;
        string blockchainName;
        address redeemerAddress;
        address redeemAddress;
        uint256 amount;
    }

    struct IssueRequest{
        uint issueRequestId;
        string tokenIdentifier;
        address cbaContractAddress;
        address issuerAddress;
        address issueAddress;
        uint256 amount;
    }
    
    uint256 issueRequestId = 0;
    uint256 redeemLogId = 0;
    uint256 messageId = 0;
    IssueRequest[] public issueRequests;
    RedeemLog[] public redeemLogs;

    function registerCBAContract(string memory _blockchainName, address _issuingContractAddress) public {
        require(_issuingContractAddress != address(0), "contract address must not be zero address");
        issuingContractAddresses[_blockchainName] = _issuingContractAddress;
        issuingBlockchainsLUT.push(_blockchainName);
        participatingIssuingContract[_issuingContractAddress] = true;
    }
    
    function registerFungibleToken(string memory _tokenName, address _serviceTokenAddress) public{
        fungibleTokens[_tokenName] = IERC20(_serviceTokenAddress);
    }
    
    function registerNonFungibleToken(string memory _tokenName, address _serviceTokenAddress) public{
        nonFungibleTokens[_tokenName] = NonFungibleTokenInterface(_serviceTokenAddress);
    }


    function issue(address _issueAddress, string memory blockchainName) public payable {
        require(msg.value > minimumIssueValue, "The value must higher than 1 gwei");
        address addr = issuingContractAddresses[blockchainName];
        require(participatingIssuingContract[addr] == true, "There is no participatingIssuing Contract");
        
        lockedBalances += msg.value;
        issueRequests.push(IssueRequest(issueRequestId, "cc",issuingContractAddresses[blockchainName], msg.sender, _issueAddress, msg.value));
        issueRequestId += 1;
        emit IssueRequestEvent(issueRequestId, address(this), issuingContractAddresses[blockchainName], msg.sender, _issueAddress, msg.value);
        bmcContract.sendMessage(blockchainName, serviceName, messageId, serialize(issueRequestId, address(this), issuingContractAddresses[blockchainName], msg.sender, _issueAddress, 0));
    }
    
     function issueERC(address _issueAddress, uint256 _amount, string memory _tokenName, string memory _blockchainName) public payable {
        // check Token Exist
        IERC20 fungibleToken = fungibleTokens[_tokenName];
        require(fungibleToken.transferFrom(msg.sender, address(this), _amount), "Insufficient funds");
        
        issueRequests.push(IssueRequest(issueRequestId, _tokenName, issuingContractAddresses[_blockchainName], msg.sender, _issueAddress, _amount));
        issueRequestId += 1;
        
        bmcContract.sendMessage(_blockchainName, serviceName, messageId, serialize(issueRequestId, address(this), issuingContractAddresses[_blockchainName], msg.sender, _issueAddress, _amount));
    }
    
    function issueNFT(address _issueAddress, string memory _tokenName, string memory _blockchainName, uint256 _tokenId) public payable{
        NonFungibleTokenInterface nonFungibleToken = nonFungibleTokens[_tokenName];
        require(nonFungibleToken.transferFrom(msg.sender, address(this), _tokenId), "Insufficient funds");
        // gomin...
        
        nonFungibleToken.transferFrom(msg.sender, address(this), _tokenId);
        nonFungibleTokens[_tokenName] = _tokenId;
        
        issueRequests.push(IssueRequest(issueRequestId, _tokenName, issuingContractAddresses[_blockchainName], msg.sender, _issueAddress, _tokenId));
        issueRequestId += 1;
        
        bmcContract.sendMessage(_blockchainName, serviceName, messageId, serialize(issueRequestId, address(this), issuingContractAddresses[_blockchainName], msg.sender, _issueAddress, msg.value));
    }
    
    function handleRedeem(uint256 _amount, string memory blockchainName, address _redeemerAddress, address payable _redeemAddress) public {
        _transfer(_amount, _redeemAddress);
        redeemLogs.push(RedeemLog(redeemLogId, "cc", blockchainName, _redeemerAddress, _redeemAddress, _amount));
        redeemLogId += 1;
    }
    
    function handleERCRedeem(uint256 _amount, string memory _tokenName, string memory _blockchainName, address _redeemerAddress, address payable _redeemAddress) public {
        IERC20 fungibleToken = fungibleTokens[_tokenName];
        fungibleToken.transferFrom(address(this), _redeemAddress,_amount);
        
        redeemLogs.push(RedeemLog(redeemLogId, _tokenName, _blockchainName,_redeemerAddress, _redeemAddress, _amount));
        redeemLogId += 1;
    }
    
    // function handleNFTRedeem(string memory _tokenName, string memory _blockchainName, uint256 _tokenId, address _redeemerAddress, address payable _redeemAddress) public {
    //     NonFungibleTokenInterface nonFungibleToken = nonFungibleTokens[_tokenName];
    //     nonFungibleToken.transferFrom(address(this), _redeemAddress, _tokenId);
        
    //     redeemLogs.push(RedeemLog(redeemLogId, _redeemerAddress, _redeemAddress, _tokenId));
    //     redeemLogId += 1;
    // }
    
    // Call at handle Redeem
    function _transfer(uint _amount, address payable redeemerAddress) public payable{
        lockedBalances -= _amount;
        redeemerAddress.transfer(_amount);
    }
    
    function issuingBlockchainsSize() public view returns (uint) {
        return issuingBlockchainsLUT.length;
    }
    
    function issueRequestsSize() public view returns (uint) {
        return issueRequests.length;
    }
    
    function redeemLogsSize() public view returns (uint){
        return redeemLogs.length;
    }
    
    function serialize(uint _issueRequestId, address _depositContractAddress, address _issuingContractAddress, address _issuerAddress, address _issueAddress, uint256 _amount) public returns (bytes memory){
        // RLP Serialize?
        return "0x3333";
    }

    event IssueRequestEvent(uint issueRequestId, address depositContractAddress, address cbaContractAddress, address issuerAddress, address issueAddress, uint amount);
    event RedeemEvent(address redeemerAddress, uint amount);

}


