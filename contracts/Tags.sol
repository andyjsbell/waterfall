// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IProvider {
    function isProvider(address providerAddress) external returns (bool);

    function registerProvider(address providerAddress) external;
}

interface IRewards {
    function maximumForTag() external returns (uint);

    function maximumReward() external returns (uint);
}

contract Tags is ERC20 {
    event TagIdGeneratedEvent(address indexed creator, bytes32 indexed tagId);
    event TagIdRemovedEvent(bytes32 indexed tagId);
    event ClaimGeneratedEvent(bytes32 indexed claimId);
    event ClaimAwardedEvent(bytes32 indexed claimId);
    event TagFedEvent(bytes32 indexed tagId, uint amount);

    IProvider provider;
    IRewards rewards;

    struct Claim {
        bytes32 id;
        uint timestamp;
    }

    struct Tag {
        address provider;
        uint balance;
    }

    uint tagNonce;
    uint claimNonce;

    mapping(address => address) providersForSponsor;
    mapping(bytes32 => Tag) public tags;
    mapping(address => mapping(bytes32 => Claim)) public userTagClaims;
    mapping(bytes32 => bytes32) claimsForTags;

    constructor(
        IProvider _provider,
        IRewards _rewards,
        uint256 _initialSupply,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        provider = _provider;
        rewards = _rewards;
        _mint(address(this), _initialSupply);
    }

    // Generate identifier hashing the creator's address and provided nonce
    function _generateId(
        address creator,
        uint nonce
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(creator, nonce, this));
    }

    // A provider would request a tag and if successful an event would be logged
    function createTag() public returns (bytes32) {
        require(provider.isProvider(msg.sender));
        tagNonce += 1;

        uint amountForTag = rewards.maximumForTag();
        require(balanceOf(address(this)) > amountForTag);
        
        bytes32 tagId = _generateId(msg.sender, tagNonce);
        tags[tagId].provider = msg.sender;
        tags[tagId].balance = amountForTag;

        emit TagIdGeneratedEvent(msg.sender, tagId);

        return tagId;
    }

    function feedTag(bytes32 _tagId) public {
        require(_tagId != bytes32(0x0));
        require(tags[_tagId].provider != address(0x0));

        // Top up tag to maximum amount
        uint amountToFeedTag = rewards.maximumForTag() - tags[_tagId].balance;
        require(amountToFeedTag > 0, "Tag is at maximum");

        transfer(address(this), amountToFeedTag);
        tags[_tagId].balance = rewards.maximumForTag();

        emit TagFedEvent(_tagId, amountToFeedTag);
    }

    // Clear tag by identifier.  Tags can only be cleared by the creators.
    function clearTag(bytes32 tagId) public {
        require(tags[tagId].provider == msg.sender);
        emit TagIdRemovedEvent(tagId);

        delete tags[tagId];
    }

    function createClaimForTag(bytes32 _tagId) public returns (bytes32) {
        // Confirm the sender isn't requesting a tag twice in a given period
        // If they haven't then we would expect a timestamp of 0 else we should
        // check that the timestamp is more than a day old so that they can claim again
        // for this tag
        require(
            userTagClaims[msg.sender][_tagId].timestamp == 0 ||
                block.timestamp >
                userTagClaims[msg.sender][_tagId].timestamp + 1 days
        );

        // Generate claim identifier
        claimNonce += 1;
        Claim memory newClaim;
        newClaim.id = _generateId(msg.sender, claimNonce);
        newClaim.timestamp = block.timestamp;

        // Track time of this request
        userTagClaims[msg.sender][_tagId] = newClaim;

        emit ClaimGeneratedEvent(newClaim.id);

        return newClaim.id;
    }

    function verifyMessage(
        bytes32 _hashedMessage,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public pure returns (address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(
            abi.encodePacked(prefix, _hashedMessage)
        );
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);

        return signer;
    }

    function claimReward(
        bytes32 _claimId,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public {
        // A user is claiming their reward which has now been signed by the sponsor
        require(_claimId != bytes32(0x0), "Invalid claim id");
        bytes32 tagId = claimsForTags[_claimId];
        require(
            userTagClaims[msg.sender][tagId].id == _claimId,
            "Claim not found for sender"
        );
        address sponsor = providersForSponsor[tags[tagId].provider];
        address signer = verifyMessage(_claimId, _v, _r, _s);
        require(signer == sponsor, "Sponsor not recognised");

        // Clear claim for user
        delete userTagClaims[msg.sender][tagId];
        delete claimsForTags[_claimId];

        // Transfer reward
        transfer(msg.sender, rewards.maximumReward());

        emit ClaimAwardedEvent(_claimId);
    }
}
