pragma solidity >=0.4.22 <0.7.0;
import "../RLPReader.sol";
import "../MerklePatriciaProof.sol";

/**
 * @title Storage
 * @dev Store & retreive value in a variable
 */
contract CBATokenV2 {

    string public backingBlockchainName;
    uint256 public totalSupply_;
    mapping(address => uint256) public balances;
    uint public issueRequestId = 0;
    uint public redeemRequestId = 0;
    address public depositContractAddress;
    mapping(bytes32 => bool) public claimedTransactions;

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;

    constructor(string memory _backingBlockchainName, address _depositContractAddress) public {
        backingBlockchainName = _backingBlockchainName;
        depositContractAddress = _depositContractAddress;
    }

    struct IssueData {
        address depositContractAddress;   // backing deposit contract Address
        address issuerAddress;
        address claimContract;
        uint value;        // the value to create on this chain
        bool isBurnValid;    // indicates whether the burning of tokens has taken place (didn't abort, e.g., due to require statement)
    }

    struct IssueLog{
        uint issueLogId;
        address issuerAddress;
        address issueAddress;
        uint256 amount;
    }

    struct RedeemRequest{
        uint redeemRequestId;
        uint256 amount;
        address redeemerAddress;
        address redeemAddress;
    }

    uint256 issueLogId = 0;
    IssueLog[] public issueLogs;
    RedeemRequest[] public redeemRequests;
    mapping(uint => address) public requestOwners;

    // For Contract Administrator
    function registerDepositContract(address tokenContract) public {
        require(tokenContract != address(0), "contract address must not be zero address");
        depositContractAddress = tokenContract;
    }


    // Issue Reqeust From User
    // TODO bytes memory rlpHeader, bytes memory rlpMerkleProofTx, bytes memory rlpMerkleProofReceipt, bytes memory path
    function handleIssue(bytes memory rlpHeader, bytes memory rlpEncodedTx, bytes memory rlpEncodedReceipt, bytes memory rlpMerkleProofTx, bytes memory rlpMerkleProofReceipt, bytes memory path) public {
        IssueData memory issueData = parsingIssueTransaction(rlpEncodedTx, rlpEncodedReceipt);
        bytes32 txHash = keccak256(rlpEncodedTx);
        // Check if tx is already claimed.
        require(claimedTransactions[txHash] == false, "The transaction is already submitted");
        // Check submitted tx contract address is equal in otherContractAddress
        require(depositContractAddress == issueData.depositContractAddress, "burn contract address is not registered");
        // Destination Check
        require(issueData.claimContract == address(this), "Different targetAddress please check the transaction");

        // verify inclusion of burn transaction
        // uint txExists = txInclusionVerifier.verifyTransaction(0, rlpHeader, REQUIRED_TX_CONFIRMATIONS, rlpEncodedTx, path, rlpMerkleProofTx);
        // require(txExists == 0, "burn transaction does not exist or has not enough confirmations");
        // // verify inclusion of receipt
        // uint receiptExists = txInclusionVerifier.verifyReceipt(0, rlpHeader, REQUIRED_TX_CONFIRMATIONS, rlpEncodedReceipt, path, rlpMerkleProofReceipt);
        claimedTransactions[keccak256(rlpEncodedTx)] = true;
        balances[msg.sender] += issueData.value;

        emit IssueEvent(issueData.issuerAddress, issueData.value);
    }
    
    function handleIssueV2(uint256 amount, address issuerAddress, address issueAddress) public{
        // From BMC, BMV
        totalSupply_ += amount;
        balances[issueAddress] += amount; // issue
        issueLogs.push(IssueLog(issueLogId, issuerAddress, issueAddress, amount));
        issueRequestId += 1;
    }

    function redeem(address _redeemerAddress, uint _amount) public payable{
        // require(msg.sender == ibcServerPublicKeyAddress);
        require(balances[msg.sender] >= _amount);
        burn(msg.sender, _amount);
        redeemRequests.push(RedeemRequest(redeemRequestId, _amount, msg.sender, _redeemerAddress));
        redeemRequestId += 1;
        emit RedeemRequestEvent(redeemRequestId, depositContractAddress, address(this), msg.sender, _redeemerAddress, _amount);
    }

    function balanceOf(address owner) public view returns (uint balance){
        return balances[owner];
    }

    function transfer(address to, uint256 value) public returns (bool success){
        require(to != address(0));
        require(value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender] - value;
        balances[to] = balances[to] + value;
        emit TransferEvent(msg.sender, to, value);
        return true;
    }

    function burn(address _targetAddress, uint256 _amount) private {
        balances[_targetAddress] -= _amount;
        totalSupply_ -= _amount;
    }

    function compareStrings (string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))) );
    }

    function parsingIssueTransaction(bytes memory rlpTransaction, bytes memory rlpReceipt) private pure returns (IssueData memory) {
        IssueData memory issueData;
        // parse transaction
        RLPReader.RLPItem[] memory transaction = rlpTransaction.toRlpItem().toList();
        issueData.depositContractAddress = transaction[3].toAddress();

        // parse receipt
        RLPReader.RLPItem[] memory receipt = rlpReceipt.toRlpItem().toList();

        // read logs
        RLPReader.RLPItem[] memory logs = receipt[4].toList();
        RLPReader.RLPItem[] memory issueEventTuple = logs[0].toList();  // logs[0] contains issue Request Event
        RLPReader.RLPItem[] memory issueEventTopics = issueEventTuple[1].toList();  // topics contain all indexed event fields

        // read value and recipient from issue event
        issueData.depositContractAddress = address(issueEventTopics[2].toUint());
        issueData.claimContract = address(issueEventTopics[3].toUint());
        // counterpartAddress
        issueData.issuerAddress = address(issueEventTopics[5].toUint());  // indices of indexed fields start at 1 (0 is reserved for the hash of the event signature)
        issueData.value = issueEventTopics[6].toUint();

        return issueData;
    }
    
    function redeemRequestsSize() public view returns (uint) {
        return redeemRequests.length;
    }
    
    function issueLogsSize() public view returns (uint){
        return issueLogs.length;
    }

    event TransferEvent(address indexed from, address indexed to, uint amount);
    event IssueEvent(address indexed issuerAddress, uint amount);
    event RedeemRequestEvent(uint redeemRequestId, address depositContractAddress, address cbaContractAddress, address redeemerAddress, address redeemAddress, uint amount);

}


