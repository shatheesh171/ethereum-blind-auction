// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract BlindAuction {
    struct Bid {
        bytes32 blindedBid;
        uint256 deposit;
    }

    address payable public beneficiary;
    uint256 public biddingEnd;
    uint256 public revealEnd;
    bool public ended;

    mapping(address => Bid[]) public bids;

    address public highestBidder;
    uint256 public highestBid;

    //Allowed withdrawals of previous bids
    mapping(address => uint256) pendingReturns;

    event AuctionEnded(address winner, uint256 highestBid);

    // Errors that describe failures.

    /// The function has been called too early.
    /// Try again at `time`.
    error TooEarly(uint256 time);

    /// The function has been called too late.
    /// It cannot be called after `time`
    error TooLate(uint256 time);

    /// The function auctionEnd has already been called
    error AuctionEndAlreadyCalled();

    // Function modifiers are used to validate inputs to function
    // New function body is modifier's body where '_' is replaced by old function body
    modifier onlyBefore(uint256 time) {
        // if (block.timestamp >= time) revert TooLate(time);
        require(block.timestamp < time, "Function is called too late");
        _;
    }

    modifier onlyAfter(uint256 time) {
        // if (block.timestamp <= time) revert TooEarly(time);
        require(block.timestamp > time, "Function is called too early");
        _;
    }

    constructor(
        uint256 biddingTime,
        uint256 revealTime,
        address payable beneficiaryAddress
    ) {
        beneficiary = beneficiaryAddress;
        biddingEnd = block.timestamp + biddingTime;
        revealEnd = biddingEnd + revealTime;
    }

    function getBlindedBidFromBytes(
        uint256 value,
        bool fake,
        bytes32 secret
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(value, fake, secret));
    }

    /// Place a blinded bid
    function bid(bytes32 blindedBid) external payable onlyBefore(biddingEnd) {
        bids[msg.sender].push(
            Bid({blindedBid: blindedBid, deposit: msg.value})
        );
    }

    /// Reveal blinded bids, refund all correctly blinded invlid bids and all bids except for the highest one
    function reveal(
        uint256[] calldata values,
        bool[] calldata fakes,
        bytes32[] calldata secrets
    ) external onlyAfter(biddingEnd) onlyBefore(revealEnd) {
        uint256 length = bids[msg.sender].length;
        require(
            values.length == length,
            "Lenght of values of not equal to number of bids"
        );
        require(
            fakes.length == length,
            "Lenght of fakes of not equal to number of bids"
        );
        require(
            secrets.length == length,
            "Length of secrets of not equal to number of bids"
        );

        uint256 refund;
        for (uint256 i = 0; i < length; i++) {
            Bid storage bidToCheck = bids[msg.sender][i];
            (uint256 value, bool fake, bytes32 secret) = (
                values[i],
                fakes[i],
                secrets[i]
            );

            if (
                bidToCheck.blindedBid !=
                keccak256(abi.encodePacked(value, fake, secret))
            ) {
                // Bid not actually revealed, do not refund deposit
                continue;
            }
            refund += bidToCheck.deposit;
            if (!fake && bidToCheck.deposit >= value) {
                if (placeBid(msg.sender, value)) refund -= value;
            }
            // Make it impossible for sender to reclaim the same deposit
            bidToCheck.blindedBid = bytes32(0);
        }
        payable(msg.sender).transfer(refund);
    }

    /// Withdraw a bid that was overbid
    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // set this to 0 as recipient can call the function again as part of recieving call
            // before `transfer` returns
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        }
    }

    /// End auction and send highest bid to beneficiary
    function auctionEnd() external onlyAfter(revealEnd) {
        if (ended) revert AuctionEndAlreadyCalled();
        ended = true;
        beneficiary.transfer(highestBid);
    }

    /// An internal function called during reveal function
    function placeBid(address bidder, uint256 value)
        internal
        returns (bool success)
    {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            // Refund previous highestBidder
            pendingReturns[highestBidder] += highestBid;
        }
        highestBid = value;
        highestBidder = bidder;
        return true;
    }
}
