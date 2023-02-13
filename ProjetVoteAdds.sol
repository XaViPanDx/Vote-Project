// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

/*
 * @dev import Ownable contract from openZeppelin library. 
 */
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/*
 * @dev import Timers library from openZeppelin library.
 */
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Timers.sol";


contract Voting is Ownable {

    /*
     * @dev Timer library configuration with a 3 days deadline example.
     */
    using Timers for Timers.Timestamp;
    Timers.Timestamp public _timer;
    uint64 _deadline = 3 days;


    /*
     * @dev structs.
     */
    struct VoterStatus {
        bool alreadyVoted;
    }

    mapping (address => VoterStatus) status;

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    mapping (address => Voter) voters;

    struct Proposal {
        string description;
        uint voteCount;
    }

    Proposal[] proposals;

    struct Whitelist {
        bool isWhitelisted;
        bool isNotWhitlisted;
    }

    mapping (address => Whitelist) whitelist;

    struct VoteStatus {
        bool RegisteringVoters;
        bool ProposalsRegistrationStarted;
        bool ProposalsRegistrationEnded;
        bool VotingSessionStarted;
        bool VotingSessionEnded;
        bool VotesTallied;
    }

    VoteStatus private votestatus; 

    /*
     * @dev Vote enum.
     */
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus private workflowStatus; 

    /* 
     * @dev Vote events.
     */
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    /*
     * @dev Eth reception events.
     */
    event EthReceived (address _addr, uint _value);
    event Transfert (address indexed from, address indexed to, uint value);

    /* 
     * @dev private function to check Whitelisted address 
     * before voters interactions.
     */
    function _checkWhitelist() private view returns(bool) {
        if (whitelist[msg.sender].isWhitelisted==true){
            return true;
        } else {
            return false;
        }
    }

    /*
     * @dev private function whitch only allow owner to add whitelisted 
     * addresses provided by organisation.
     */
    function _addVoter(address _address) private onlyOwner {
        whitelist [_address].isWhitelisted = true;
        voters [_address].isRegistered = true;
        votestatus.RegisteringVoters = true;
        workflowStatus = WorkflowStatus.RegisteringVoters;
        emit VoterRegistered (_address);     
    }

    /*
     * @dev private function witch forbid voters to register proposals before 
     * the proposal registration's start. Only owner can start this session.
     * Timer is started.
     */
    function _proposalsSessionStart() private onlyOwner { 
        votestatus.ProposalsRegistrationStarted = true;
        votestatus.ProposalsRegistrationEnded = false;
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;       
        emit WorkflowStatusChange (WorkflowStatus.RegisteringVoters,
        WorkflowStatus.ProposalsRegistrationStarted);
        _timer.isStarted();
    }

    /*
     * @dev function witch allow voters to register as much proposals they want from 
     * the proposal registration's start. Timer is pending for 3 days from addProposal
     * owner activation.
     */
    function addProposal(string memory _description) external {
        require(votestatus.ProposalsRegistrationStarted == true," Proposal registration not yet started");
        require(votestatus.ProposalsRegistrationEnded != true," Proposal registration ended");
        require(_checkWhitelist(),"You are not able to add proposal");
        proposals.push(Proposal({description: _description,voteCount: 0}));
        uint proposalId = proposals.length;
        emit ProposalRegistered (proposalId);
        _timer.isPending();
    }

    /*
     * @dev private function witch forbid voters to register proposals after 
     * the proposal registration's end. Only owner can close this session.
     * Timer is expired.
     */
    function _proposalsSessionEnd() private onlyOwner {      
        votestatus.ProposalsRegistrationEnded = true;
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange (WorkflowStatus.ProposalsRegistrationStarted,
        WorkflowStatus.ProposalsRegistrationEnded);
        _timer.isExpired();
    }

    /*
     * @dev private function witch forbid voters to vote before voting session's start.
     * Only owner can start this session. Timer is started.
     */
    function _voteStarts() private onlyOwner {  
        votestatus.VotingSessionStarted = true;
        votestatus.VotingSessionEnded = false;
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange (WorkflowStatus.ProposalsRegistrationEnded,
        WorkflowStatus.VotingSessionStarted);
        _timer.isStarted();
    }

    /*
     * @dev function vote whitch only allows rights to vote for whitelisted address
     * from voting session starts. Also forbid voters to vote twice and input wrong
     * proposalId. Timer is pending for 3 days from voteStart owner activation.
     */
    function vote(uint _proposalId) external {
        require(votestatus.VotingSessionStarted == true, "Voting session not yet started");
        require(votestatus.VotingSessionEnded != true, " Voting session ended");
        require(_checkWhitelist(),"You are not authorized to vote");
        require(status[msg.sender].alreadyVoted != true,"You can't vote twice");
        require(_proposalId < proposals.length, "Invalid proposalId");
        voters [msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;
        voters [msg.sender].hasVoted = true;
        status[msg.sender].alreadyVoted = true;
        emit Voted (msg.sender, _proposalId);
        _timer.isPending();
    }

    /* 
     $ @dev function whitch allow voters to know every vote by voters addresses.
     */
    function getVotedProposalId(address _address) external view returns(uint) {
        return (voters[_address].votedProposalId);
    }

    /*
     * @dev function whitch allow voters to know the description of every 
     * propositions by votedProposalId
     */
    function getProposalDescription(uint _votedProposalId) external view 
    returns (string memory) {
        return proposals[_votedProposalId].description;
    }

    /*
     * @dev private function witch forbid voters to vote after voting session's end.
     * Only owner can close this session.
     */
    function _votesEnd() private onlyOwner {
        votestatus.VotingSessionEnded = true;
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange (WorkflowStatus.VotingSessionStarted,
        WorkflowStatus.VotingSessionEnded);
        _timer.isExpired();
    }

    /*
     * @dev private function whitch forbid access to results before votes count.
     * Only owner can allow acces to the public function getWinner.
     */
    function _votesCount() private onlyOwner {
        votestatus.VotesTallied = true;
        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange (WorkflowStatus.VotingSessionEnded,
        WorkflowStatus.VotesTallied);
    }

    /*
     * @dev getWinner public function to allow everyone to check winning 
     * proposalId and description (Voters and other persons).
     */
    function getWinner() public view returns (uint _winningProposalId, string memory) {
        require(votestatus.VotesTallied == true,"Votes are not yet tallied");
        uint winningVoteCount = 0;
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                _winningProposalId = i;
            }
        }
        return (_winningProposalId, proposals[_winningProposalId].description);
    }

    /*
     * @dev function Donate who allows everyone to transfert Eth
     * to the organisation Smart Contract
     */
    function Donate() public payable returns (string memory _thanks){
        _thanks = "Thank you for your donation!";

    }

    /*
     * @dev functions fallback() end receive() witch allow Smart 
     * Contract to receive Eth and data from outside (a minimum
     * amount is required for most security.
     */
    address _caller;
    uint _balance;

    mapping (address => uint) Amount;

    fallback (bytes calldata _msg) external payable returns (bytes memory) {
        require(msg.value >= 1 wei, "you can't send less than 1 wei");
        _caller = msg.sender;
        _balance = _balance + msg.value;
        Amount [msg.sender] = msg.value;
        emit EthReceived (msg.sender, msg.value);
        return (_msg);
    }

    receive () external payable {
        require(msg.value >= 1 wei, "you can't send less than 1 wei");
        _caller = msg.sender;
        _balance = _balance + msg.value;
        Amount [msg.sender] = msg.value;
        emit EthReceived (msg.sender, msg.value);
    }

    /*
     * @dev functions whitch allow organisation's members to know
     * the detail of transactions to this Smart Contract.
     */
    function getcaller() external view returns(address){
        return _caller;
    }

    function getBalance() external view returns(uint){
        return _balance;
    }

    function getAmountSend (address _addressCaller) external view returns(uint){
        return Amount [_addressCaller];
    }

    /*
     * @dev function witch allow to transfert Eth received to a new
     * Smart Contract "OrganisationFunds" to allow organisation 
     $ use money for community members.
     */
    function _transfertEth(address _to, uint _amount) public onlyOwner returns(string memory) {
        (bool success, ) = _to.call{value: _amount}("");
        require (success,"Transfert failled");
        return "Transfert to the OrganistaionFunds Contract done!";
    }
}


    /*
     * @dev this new contract "OrganisationFunds" = _to address, is 
     * deployed whith a new Smart Contract adress and permit to  
     * receive tranfered Eth from the contract "Vote" and collect 
     * funds in a unique public place.
     */
contract OrganisationFunds {

    event ethReceived (string _ethReceived);
    event EthReceived (address _addr, uint _value);
    event Transfert (address indexed from, address indexed to, uint value);

    address _caller;
    uint _balance;

    mapping (address => uint) Amount;

    /* 
     * @dev function to receive Eth transfert from "Vote" Smart Contract
     */
    function receptEth() public payable returns (string memory _thanks) {

        emit ethReceived ("Transfert done");
        return "Thank you for your donation!";
    }

    /* 
     * @dev functions fallback() and receive() witch can receive Eth and data
     * from outside.
     */
    fallback (bytes calldata _msg) external payable returns (bytes memory) {
        require(msg.value >= 1 wei, "you can't send less than 1 wei");
        _caller = msg.sender;
        _balance = _balance + msg.value;
        Amount [msg.sender] = msg.value;
        emit EthReceived (msg.sender, msg.value);
        return (_msg);
    }

    receive () external payable {
        require(msg.value >= 1 wei, "you can't send less than 1 wei");
        _caller = msg.sender;
        _balance = _balance + msg.value;
        Amount [msg.sender] = msg.value;
        emit EthReceived (msg.sender, msg.value);
    }
}