// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Voting System Smart Contract
 * @dev A comprehensive voting system with admin and voter roles
 */
contract VotingSystem {
    // Events
    event ElectionCreated(uint256 indexed electionId, string title, uint256 startTime, uint256 endTime);
    event CandidateAdded(uint256 indexed electionId, uint256 indexed candidateId, string name);
    event VoterRegistered(uint256 indexed electionId, address voter);
    event VoterRemoved(uint256 indexed electionId, address voter);
    event VoteCast(uint256 indexed electionId, address indexed voter, uint256 indexed candidateId);
    event ElectionStateChanged(uint256 indexed electionId, ElectionState state);

    // Enum for election state
    enum ElectionState { 
        Created,    // Election created but not started
        Active,     // Election is active and voting is allowed
        Paused,     // Election is paused
        Ended,      // Election has ended
        Canceled    // Election was canceled
    }

    // Enum for voting type
    enum VotingType { 
        SingleChoice,  // One vote per voter
        MultipleChoice // Multiple votes allowed per voter (up to a max)
    }

    // Struct for candidate information
    struct Candidate {
        uint256 id;
        string name;
        string description;
        uint256 voteCount;
    }

    // Struct for voter information
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256[] votedCandidateIds; // For multiple choice voting
        uint256 weight; // For weighted voting (default 1)
    }

    // Struct for election information
    struct Election {
        uint256 id;
        string title;
        string description;
        address admin;
        uint256 startTime;
        uint256 endTime;
        ElectionState state;
        VotingType votingType;
        uint256 maxVotesPerVoter; // For multiple choice voting
        uint256 totalVotes;
        uint256 candidateCount;
        mapping(uint256 => Candidate) candidates;
        mapping(address => Voter) voters;
        bool requiresRegistration; // Whether voters need to be registered by admin
        bool resultsVisible; // Whether results are visible before election ends
    }

    // Contract owner/admin
    address public owner;
    
    // Counter for election IDs
    uint256 private _electionIdCounter;
    
    // Mapping from election ID to Election struct
    mapping(uint256 => Election) public elections;
    
    // Constructor sets the contract owner
    constructor() {
        owner = msg.sender;
        _electionIdCounter = 1;
    }
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyElectionAdmin(uint256 _electionId) {
        require(elections[_electionId].admin == msg.sender, "Only election admin can call this function");
        _;
    }
    
    modifier electionExists(uint256 _electionId) {
        require(_electionId > 0 && _electionId < _electionIdCounter, "Election does not exist");
        _;
    }

    modifier electionActive(uint256 _electionId) {
        require(
            elections[_electionId].state == ElectionState.Active &&
            block.timestamp >= elections[_electionId].startTime &&
            block.timestamp <= elections[_electionId].endTime,
            "Election is not active"
        );
        _;
    }

    // Admin Functions
    
    /**
     * @dev Create a new election
     */
    function createElection(
        string memory _title,
        string memory _description,
        uint256 _startTime,
        uint256 _endTime,
        VotingType _votingType,
        uint256 _maxVotesPerVoter,
        bool _requiresRegistration,
        bool _resultsVisible
    ) external returns (uint256) {
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        
        uint256 electionId = _electionIdCounter++;
        
        Election storage election = elections[electionId];
        election.id = electionId;
        election.title = _title;
        election.description = _description;
        election.admin = msg.sender;
        election.startTime = _startTime;
        election.endTime = _endTime;
        election.state = ElectionState.Created;
        election.votingType = _votingType;
        election.maxVotesPerVoter = _votingType == VotingType.MultipleChoice ? _maxVotesPerVoter : 1;
        election.requiresRegistration = _requiresRegistration;
        election.resultsVisible = _resultsVisible;
        
        emit ElectionCreated(electionId, _title, _startTime, _endTime);
        
        return electionId;
    }

    /**
     * @dev Add a candidate to an election
     */
    function addCandidate(
        uint256 _electionId,
        string memory _name,
        string memory _description
    ) external electionExists(_electionId) onlyElectionAdmin(_electionId) {
        require(elections[_electionId].state == ElectionState.Created, "Cannot add candidate after election has started");
        
        Election storage election = elections[_electionId];
        uint256 candidateId = election.candidateCount + 1;
        
        election.candidates[candidateId] = Candidate({
            id: candidateId,
            name: _name,
            description: _description,
            voteCount: 0
        });
        
        election.candidateCount++;
        
        emit CandidateAdded(_electionId, candidateId, _name);
    }

    /**
     * @dev Register a voter for an election
     */
    function registerVoter(uint256 _electionId, address _voter, uint256 _weight) 
        external 
        electionExists(_electionId) 
        onlyElectionAdmin(_electionId) 
    {
        require(!elections[_electionId].voters[_voter].isRegistered, "Voter already registered");
        require(_weight > 0, "Weight must be greater than 0");
        
        elections[_electionId].voters[_voter].isRegistered = true;
        elections[_electionId].voters[_voter].weight = _weight;
        
        emit VoterRegistered(_electionId, _voter);
    }

    /**
     * @dev Remove a voter from an election
     */
    function removeVoter(uint256 _electionId, address _voter) 
        external 
        electionExists(_electionId) 
        onlyElectionAdmin(_electionId) 
    {
        require(elections[_electionId].voters[_voter].isRegistered, "Voter not registered");
        require(!elections[_electionId].voters[_voter].hasVoted, "Cannot remove voter after they've voted");
        
        elections[_electionId].voters[_voter].isRegistered = false;
        
        emit VoterRemoved(_electionId, _voter);
    }

    /**
     * @dev Start an election
     */
    function startElection(uint256 _electionId) 
        external 
        electionExists(_electionId) 
        onlyElectionAdmin(_electionId) 
    {
        Election storage election = elections[_electionId];
        
        require(election.state == ElectionState.Created, "Election must be in Created state");
        require(election.candidateCount >= 2, "Election must have at least 2 candidates");
        require(block.timestamp >= election.startTime, "Election start time has not been reached");
        
        election.state = ElectionState.Active;
        
        emit ElectionStateChanged(_electionId, ElectionState.Active);
    }

    /**
     * @dev Pause an election
     */
    function pauseElection(uint256 _electionId) 
        external 
        electionExists(_electionId) 
        onlyElectionAdmin(_electionId) 
    {
        Election storage election = elections[_electionId];
        
        require(election.state == ElectionState.Active, "Election must be active to pause");
        
        election.state = ElectionState.Paused;
        
        emit ElectionStateChanged(_electionId, ElectionState.Paused);
    }

    /**
     * @dev Resume a paused election
     */
    function resumeElection(uint256 _electionId) 
        external 
        electionExists(_electionId) 
        onlyElectionAdmin(_electionId) 
    {
        Election storage election = elections[_electionId];
        
        require(election.state == ElectionState.Paused, "Election must be paused to resume");
        require(block.timestamp <= election.endTime, "Election end time has passed");
        
        election.state = ElectionState.Active;
        
        emit ElectionStateChanged(_electionId, ElectionState.Active);
    }

    /**
     * @dev End an election
     */
    function endElection(uint256 _electionId) 
        external 
        electionExists(_electionId) 
        onlyElectionAdmin(_electionId) 
    {
        Election storage election = elections[_electionId];
        
        require(
            election.state == ElectionState.Active || 
            election.state == ElectionState.Paused, 
            "Election must be active or paused to end"
        );
        
        election.state = ElectionState.Ended;
        
        emit ElectionStateChanged(_electionId, ElectionState.Ended);
    }

    /**
     * @dev Cancel an election
     */
    function cancelElection(uint256 _electionId) 
        external 
        electionExists(_electionId) 
        onlyElectionAdmin(_electionId) 
    {
        Election storage election = elections[_electionId];
        
        require(
            election.state == ElectionState.Created || 
            election.state == ElectionState.Active || 
            election.state == ElectionState.Paused, 
            "Election cannot be canceled in its current state"
        );
        
        election.state = ElectionState.Canceled;
        
        emit ElectionStateChanged(_electionId, ElectionState.Canceled);
    }

    // Voter Functions
    
    /**
     * @dev Cast a vote in a single choice election
     */
    function castVote(uint256 _electionId, uint256 _candidateId) 
        external 
        electionExists(_electionId) 
        electionActive(_electionId) 
    {
        Election storage election = elections[_electionId];
        Voter storage voter = election.voters[msg.sender];
        
        if (election.requiresRegistration) {
            require(voter.isRegistered, "Voter is not registered for this election");
        }
        
        require(!voter.hasVoted, "Voter has already voted");
        require(_candidateId > 0 && _candidateId <= election.candidateCount, "Invalid candidate ID");
        
        // Set weight to 1 if voter was not explicitly registered with a weight
        uint256 weight = voter.weight > 0 ? voter.weight : 1;
        
        // Record the vote
        voter.hasVoted = true;
        voter.votedCandidateIds.push(_candidateId);
        election.candidates[_candidateId].voteCount += weight;
        election.totalVotes += weight;
        
        emit VoteCast(_electionId, msg.sender, _candidateId);
    }
    
    /**
     * @dev Cast multiple votes in a multiple choice election
     */
    function castMultipleVotes(uint256 _electionId, uint256[] memory _candidateIds) 
        external 
        electionExists(_electionId) 
        electionActive(_electionId) 
    {
        Election storage election = elections[_electionId];
        
        require(election.votingType == VotingType.MultipleChoice, "Election is not multiple choice");
        require(_candidateIds.length <= election.maxVotesPerVoter, "Too many votes cast");
        require(_candidateIds.length > 0, "Must cast at least one vote");
        
        Voter storage voter = election.voters[msg.sender];
        
        if (election.requiresRegistration) {
            require(voter.isRegistered, "Voter is not registered for this election");
        }
        
        require(!voter.hasVoted, "Voter has already voted");
        
        // Check for duplicate votes and invalid candidate IDs
        for (uint256 i = 0; i < _candidateIds.length; i++) {
            require(_candidateIds[i] > 0 && _candidateIds[i] <= election.candidateCount, "Invalid candidate ID");
            
            // Check for duplicates
            for (uint256 j = i + 1; j < _candidateIds.length; j++) {
                require(_candidateIds[i] != _candidateIds[j], "Duplicate votes not allowed");
            }
        }
        
        // Set weight to 1 if voter was not explicitly registered with a weight
        uint256 weight = voter.weight > 0 ? voter.weight : 1;
        
        // Record the votes
        voter.hasVoted = true;
        
        for (uint256 i = 0; i < _candidateIds.length; i++) {
            uint256 candidateId = _candidateIds[i];
            voter.votedCandidateIds.push(candidateId);
            election.candidates[candidateId].voteCount += weight;
            election.totalVotes += weight;
            
            emit VoteCast(_electionId, msg.sender, candidateId);
        }
    }
    
    // View Functions
    
    /**
     * @dev Get candidate information
     */
    function getCandidate(uint256 _electionId, uint256 _candidateId) 
        external 
        view 
        electionExists(_electionId)
        returns (uint256 id, string memory name, string memory description, uint256 voteCount) 
    {
        require(_candidateId > 0 && _candidateId <= elections[_electionId].candidateCount, "Invalid candidate ID");
        
        Candidate storage candidate = elections[_electionId].candidates[_candidateId];
        
        // Only show vote count if results are visible or election has ended
        uint256 votes = 0;
        if (elections[_electionId].resultsVisible || elections[_electionId].state == ElectionState.Ended) {
            votes = candidate.voteCount;
        }
        
        return (candidate.id, candidate.name, candidate.description, votes);
    }

    /**
     * @dev Get election information
     */
    function getElectionInfo(uint256 _electionId) 
        external 
        view 
        electionExists(_electionId)
        returns (
            string memory title,
            string memory description,
            address admin,
            uint256 startTime,
            uint256 endTime,
            ElectionState state,
            VotingType votingType,
            uint256 candidateCount,
            uint256 totalVotes,
            bool requiresRegistration,
            bool resultsVisible
        ) 
    {
        Election storage election = elections[_electionId];
        
        // Only show totalVotes if results are visible or election has ended
        uint256 votes = 0;
        if (election.resultsVisible || election.state == ElectionState.Ended) {
            votes = election.totalVotes;
        }
        
        return (
            election.title,
            election.description,
            election.admin,
            election.startTime,
            election.endTime,
            election.state,
            election.votingType,
            election.candidateCount,
            votes,
            election.requiresRegistration,
            election.resultsVisible
        );
    }
    
    /**
     * @dev Check if a voter is registered and has voted
     */
    function getVoterStatus(uint256 _electionId, address _voter) 
        external 
        view 
        electionExists(_electionId)
        returns (bool isRegistered, bool hasVoted, uint256 weight) 
    {
        Voter storage voter = elections[_electionId].voters[_voter];
        
        return (voter.isRegistered, voter.hasVoted, voter.weight);
    }
    
    /**
     * @dev Get the candidates a voter has voted for
     */
    function getVoterChoices(uint256 _electionId, address _voter) 
        external 
        view 
        electionExists(_electionId)
        returns (uint256[] memory candidateIds) 
    {
        Voter storage voter = elections[_electionId].voters[_voter];
        
        // Only the voter themselves or the election admin can see their choices
        require(
            msg.sender == _voter || 
            msg.sender == elections[_electionId].admin || 
            msg.sender == owner, 
            "Not authorized to view voter choices"
        );
        
        return voter.votedCandidateIds;
    }
    
    /**
     * @dev Get total number of elections
     */
    function getElectionCount() external view returns (uint256) {
        return _electionIdCounter - 1;
    }
}
