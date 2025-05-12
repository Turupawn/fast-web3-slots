// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TwoPartySlotGame {
    enum State { NotStarted, Committed, Revealed }

    struct Game {
        address player;
        address house;
        bytes32 playerCommit;
        bytes32 houseCommit;
        bytes32 playerSecret;
        bytes32 houseSecret;
        uint256 playerStake;
        uint256 houseStake;
        State playerState;
        State houseState;
        uint256 result;
        address winner;
    }

    Game public game;

    uint256 public constant STAKE_AMOUNT = 0.0000000003 ether;

    event GameResult(address winner, uint256 result);

    modifier onlyPlayer() {
        require(msg.sender == game.player, "Not player");
        _;
    }

    modifier onlyHouse() {
        require(msg.sender == game.house, "Not house");
        _;
    }

    modifier hasStaked() {
        require(msg.value == STAKE_AMOUNT, "Incorrect stake amount");
        _;
    }

    constructor(address _player, address _house) {
        game.player = _player;
        game.house = _house;
    }

    /// @dev Player and house commit to the game by sending ETH and a hash of their secret
    function commit(bytes32 _commitHash) external payable hasStaked {
        if (msg.sender == game.player) {
            require(game.playerState == State.NotStarted, "Player already committed");
            game.playerCommit = _commitHash;
            game.playerStake = msg.value;
            game.playerState = State.Committed;
        } else if (msg.sender == game.house) {
            require(game.houseState == State.NotStarted, "House already committed");
            game.houseCommit = _commitHash;
            game.houseStake = msg.value;
            game.houseState = State.Committed;
        } else {
            revert("Unknown sender");
        }
    }

    /// @dev Reveal the secret and validate the commitment. The result is computed once both sides reveal.
    function reveal(bytes32 _secret) external {
        if (msg.sender == game.player) {
            require(game.playerState == State.Committed, "Player not ready to reveal");
            require(_secret == game.playerCommit, "Player secret invalid");
            game.playerState = State.Revealed;
        } else if (msg.sender == game.house) {
            require(game.houseState == State.Committed, "House not ready to reveal");
            require(_secret == game.houseCommit, "House secret invalid");
            game.houseState = State.Revealed;
        } else {
            revert("Unknown sender");
        }

        // Generate result if both revealed
        if (game.playerState == State.Revealed && game.houseState == State.Revealed) {
            uint256 xorResult = (uint256(game.playerSecret) ^ uint256(game.houseSecret)) & 0xFFFFFFFF;
            
            address winner = (xorResult % 2 == 0) ? game.player : game.house;
            uint256 totalStake = game.houseStake + game.playerStake;
            
            // Reset game state BEFORE transfer
            _resetGame();
            
            // Emit event and transfer after reset
            emit GameResult(winner, xorResult);
            payable(winner).transfer(totalStake);
        }
    }

    /// @dev Internal function to reset the game
    function _resetGame() internal {
        address player = game.player;
        address house = game.house;
        
        game.playerCommit = bytes32(0);
        game.houseCommit = bytes32(0);
        game.playerSecret = bytes32(0);
        game.houseSecret = bytes32(0);
        game.playerStake = 0;
        game.houseStake = 0;
        game.playerState = State.NotStarted;
        game.houseState = State.NotStarted;
        game.result = 0;
        game.winner = address(0);
        
        game.player = player;
        game.house = house;
    }

    // Add a function to check contract balance
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Add a function to withdraw stuck funds (only owner)
    function withdrawStuckFunds() external {
        require(msg.sender == game.player || msg.sender == game.house, "Not authorized");
        require(address(this).balance > 0, "No funds to withdraw");
        
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function helperKeccakString(string memory str) public pure returns(bytes32)
    {
        return keccak256(abi.encodePacked(str));
    }

    function helperString(string memory str) public pure returns(bytes32)
    {
        return bytes32(abi.encodePacked(str));
    }

    function HelperBytes32(bytes32 b32) public pure returns(bytes32)
    {
        return keccak256(abi.encodePacked(b32));
    }
}
