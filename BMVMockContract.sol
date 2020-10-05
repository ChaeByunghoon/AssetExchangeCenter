pragma solidity >=0.4.22 <0.7.0;
import "./BMVContract.sol";

contract BMCMockContract{
    
    mapping(string => address) blockchainBMCs;
    mapping(string => address) serviceNames;
    mapping(address => bool) public isParticipateService;
    mapping(string => BMVContract) public bmvContracts;
    
    function handleRelayMessage(string memory prev, string memory str, uint seq, bytes memory msg) public {
        
    }
    
    function sendMessage(string memory _networkAddress, string memory _serviceName, uint256 _serialNumber, bytes memory message) public {
        address serviceContractAddress = serviceNames[_serviceName];
        // require(isParticipateService[serviceContractAddress] == true, "This service is not registered.");
        // require(serviceNames[_serviceName] == msg.sender);
        
        // Generate BTP Address
        string memory btpAddress = append("btp://", _networkAddress, "", "", "");
        // Emit BTP Message
        emit BTPMessage(btpAddress, _serialNumber, message);
    }
    
    function addService(string memory _serviceName, address _serviceContractAddress) public{
        serviceNames[_serviceName] = _serviceContractAddress;
        isParticipateService[_serviceContractAddress] = true;
    }
    
    function removeService(string memory _serviceName) public{
        delete serviceNames[_serviceName];
    }
    
    //Network addresss, BMV address
    function addVerifier(string memory _network, address _address) public {
        bmvContracts[_network] = BMVContract(_address);
    }
    
    function addLink(string memory link) public{
        
    }
    
    function removeLink(string memory link) public{
        
    }
    
    function addRoute(string memory destination, string memory link) public {
        
    }
    
    function removeRoute(string memory destination, string memory link) public {
        
    }
    
    function getServices() public {
        
    }
    
    function getVerifiers() public{
        
    }
    
    function getLinks() public{
        
    }
    
    function getRoutes() public {
        
    }
    
    function getStatus(string memory link) public{
        
    }
    //BSH can send messages through BTP Message Center(BMC) from any user request, the request can also come from other smart contracts. BSHs are also responsible for handling message from other BSHs.

// Before a BSH is registered to the BMC, it's unable to send messages, and unable to handle messages from others. To become a BSH, following criteria must be met,

// Registered to the BMC through BMC.addService
// After registration, it can send messages through BMC.sendMessage. If there is an error while delivering message, BSH will return error information though handleBTPError. If messages are successfully delivered, BMC will call handleBTPMessage of the target BSH. While processing the message, it can reply though BMC.sendMessage.
    function append(string memory a, string memory b, string memory c, string memory d, string memory e) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e));
    }


    // _next: String ( BTP Address of the BMC to handle the message )
    event BTPMessage(string next, uint seq, bytes msg);

}


