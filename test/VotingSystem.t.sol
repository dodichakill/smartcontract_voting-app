// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {VotingSystem} from "../src/VotingSystem.sol";

contract VotingSystemTest is Test {
    VotingSystem public votingSystem;
    address public owner;
    address public voterA;
    address public voterB;
    address public voterC;
    
    uint256 public electionId;
    uint256 public startTime;
    uint256 public endTime;

    function setUp() public {
        owner = address(this);
        voterA = address(0x1);
        voterB = address(0x2);
        voterC = address(0x3);
        
        vm.warp(1000); // Set block timestamp
        
        votingSystem = new VotingSystem();
        
        // Setup for tests
        startTime = block.timestamp + 100;
        endTime = startTime + 1000;
    }
    
    function test_CreateElection() public {
        electionId = votingSystem.createElection(
            "Presidential Election",
            "Vote for your preferred candidate",
            startTime,
            endTime,
            VotingSystem.VotingType.SingleChoice,
            1,
            true,
            false
        );
        
        (
            string memory title,
            string memory description,
            address admin,
            uint256 _startTime,
            uint256 _endTime,
            VotingSystem.ElectionState state,
            VotingSystem.VotingType votingType,
            uint256 candidateCount,
            uint256 totalVotes,
            bool requiresRegistration,
            bool resultsVisible
        ) = votingSystem.getElectionInfo(electionId);
        
        assertEq(title, "Presidential Election");
        assertEq(description, "Vote for your preferred candidate");
        assertEq(admin, owner);
        assertEq(_startTime, startTime);
        assertEq(_endTime, endTime);
        assertEq(uint(state), uint(VotingSystem.ElectionState.Created));
        assertEq(uint(votingType), uint(VotingSystem.VotingType.SingleChoice));
        assertEq(candidateCount, 0);
        assertEq(totalVotes, 0);
        assertTrue(requiresRegistration);
        assertFalse(resultsVisible);
    }
    
    function test_AddCandidates() public {
        electionId = createTestElection();
        
        votingSystem.addCandidate(electionId, "Candidate A", "First candidate");
        votingSystem.addCandidate(electionId, "Candidate B", "Second candidate");
        
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 candidateCount,
            ,
            ,
            
        ) = votingSystem.getElectionInfo(electionId);
        
        assertEq(candidateCount, 2);
        
        (uint256 id, string memory name, string memory description, ) = votingSystem.getCandidate(electionId, 1);
        assertEq(id, 1);
        assertEq(name, "Candidate A");
        assertEq(description, "First candidate");
        
        (id, name, description, ) = votingSystem.getCandidate(electionId, 2);
        assertEq(id, 2);
        assertEq(name, "Candidate B");
        assertEq(description, "Second candidate");
    }
    
    function test_RegisterVoters() public {
        electionId = createTestElection();
        addTestCandidates(electionId);
        
        votingSystem.registerVoter(electionId, voterA, 1);
        votingSystem.registerVoter(electionId, voterB, 2); // Voter B gets double voting power
        
        (bool isRegistered, bool hasVoted, uint256 weight) = votingSystem.getVoterStatus(electionId, voterA);
        assertTrue(isRegistered);
        assertFalse(hasVoted);
        assertEq(weight, 1);
        
        (isRegistered, hasVoted, weight) = votingSystem.getVoterStatus(electionId, voterB);
        assertTrue(isRegistered);
        assertFalse(hasVoted);
        assertEq(weight, 2);
    }
    
    function test_StartElection() public {
        electionId = createTestElection();
        addTestCandidates(electionId);
        
        // Warp to start time
        vm.warp(startTime);
        
        votingSystem.startElection(electionId);
        
        (
            ,
            ,
            ,
            ,
            ,
            VotingSystem.ElectionState state,
            ,
            ,
            ,
            ,
            
        ) = votingSystem.getElectionInfo(electionId);
        
        assertEq(uint(state), uint(VotingSystem.ElectionState.Active));
    }
    
    function test_CastVote() public {
        electionId = createTestElection();
        addTestCandidates(electionId);
        
        // Register voters
        votingSystem.registerVoter(electionId, voterA, 1);
        votingSystem.registerVoter(electionId, voterB, 2); // Voter B has weight 2
        
        // Warp to start time and start election
        vm.warp(startTime);
        votingSystem.startElection(electionId);
        
        // Vote as Voter A for Candidate 1
        vm.prank(voterA);
        votingSystem.castVote(electionId, 1);
        
        // Vote as Voter B for Candidate 2
        vm.prank(voterB);
        votingSystem.castVote(electionId, 2);
        
        // End the election to see results
        vm.warp(endTime + 1);
        votingSystem.endElection(electionId);
        
        // Check voter status
        (bool isRegistered, bool hasVoted, ) = votingSystem.getVoterStatus(electionId, voterA);
        assertTrue(isRegistered);
        assertTrue(hasVoted);
        
        // Check vote counts
        (, , , uint256 voteCount) = votingSystem.getCandidate(electionId, 1);
        assertEq(voteCount, 1); // Voter A gave 1 vote
        
        (, , , voteCount) = votingSystem.getCandidate(electionId, 2);
        assertEq(voteCount, 2); // Voter B gave 2 votes due to weight
        
        // Check total votes
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 totalVotes,
            ,
            
        ) = votingSystem.getElectionInfo(electionId);
        
        assertEq(totalVotes, 3); // 1 + 2 = 3 total votes
    }
    
    function test_MultipleChoiceVoting() public {
        // Create multiple choice election
        electionId = votingSystem.createElection(
            "Board Election",
            "Vote for up to 2 board members",
            startTime,
            endTime,
            VotingSystem.VotingType.MultipleChoice,
            2, // max 2 votes per voter
            true,
            false
        );
        
        // Add candidates
        votingSystem.addCandidate(electionId, "Candidate A", "First candidate");
        votingSystem.addCandidate(electionId, "Candidate B", "Second candidate");
        votingSystem.addCandidate(electionId, "Candidate C", "Third candidate");
        
        // Register voter
        votingSystem.registerVoter(electionId, voterA, 1);
        
        // Start election
        vm.warp(startTime);
        votingSystem.startElection(electionId);
        
        // Cast multiple votes
        uint256[] memory candidateIds = new uint256[](2);
        candidateIds[0] = 1; // Candidate A
        candidateIds[1] = 3; // Candidate C
        
        vm.prank(voterA);
        votingSystem.castMultipleVotes(electionId, candidateIds);
        
        // End election to see results
        vm.warp(endTime + 1);
        votingSystem.endElection(electionId);
        
        // Check vote counts
        (, , , uint256 voteCountA) = votingSystem.getCandidate(electionId, 1);
        assertEq(voteCountA, 1);
        
        (, , , uint256 voteCountB) = votingSystem.getCandidate(electionId, 2);
        assertEq(voteCountB, 0);
        
        (, , , uint256 voteCountC) = votingSystem.getCandidate(electionId, 3);
        assertEq(voteCountC, 1);
        
        // Check voter's choices
        vm.prank(voterA);
        uint256[] memory voterChoices = votingSystem.getVoterChoices(electionId, voterA);
        assertEq(voterChoices.length, 2);
        assertEq(voterChoices[0], 1);
        assertEq(voterChoices[1], 3);
    }
    
    function test_PauseAndResumeElection() public {
        electionId = createTestElection();
        addTestCandidates(electionId);
        
        // Start election
        vm.warp(startTime);
        votingSystem.startElection(electionId);
        
        // Pause election
        votingSystem.pauseElection(electionId);
        
        (
            ,
            ,
            ,
            ,
            ,
            VotingSystem.ElectionState state,
            ,
            ,
            ,
            ,
            
        ) = votingSystem.getElectionInfo(electionId);
        
        assertEq(uint(state), uint(VotingSystem.ElectionState.Paused));
        
        // Resume election
        votingSystem.resumeElection(electionId);
        
        (
            ,
            ,
            ,
            ,
            ,
            state,
            ,
            ,
            ,
            ,
            
        ) = votingSystem.getElectionInfo(electionId);
        
        assertEq(uint(state), uint(VotingSystem.ElectionState.Active));
    }
    
    // Helper functions
    function createTestElection() internal returns (uint256) {
        return votingSystem.createElection(
            "Test Election",
            "Election for testing",
            startTime,
            endTime,
            VotingSystem.VotingType.SingleChoice,
            1,
            true,
            false
        );
    }
    
    function addTestCandidates(uint256 _electionId) internal {
        votingSystem.addCandidate(_electionId, "Candidate A", "First candidate");
        votingSystem.addCandidate(_electionId, "Candidate B", "Second candidate");
    }
}
