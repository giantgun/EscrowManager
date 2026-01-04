// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EscrowManager is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotBuyer();
    error NotSeller();
    error NotArbiter();
    error InvalidState();
    error InvalidInput();
    error TimeoutNotReached();
    error ArbiterCannotBeBuyerOrSeller();

    /*//////////////////////////////////////////////////////////////
                            TYPES
    //////////////////////////////////////////////////////////////*/

    enum EscrowStatus {
        NONE,
        AWAITING_DELIVERY,
        DISPUTED,
        COMPLETED,
        REFUNDED
    }

    struct Escrow {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        uint64 createdAt;
        uint64 timeout; // seconds
        EscrowStatus status;
    }

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private constant PLATFORM_FEE_BPS = 10; // 0.1%
    uint256 private constant ARBITER_FEE_BPS = 100; // 1%
    uint256 private constant BPS_DENOMINATOR = 10_000;
    address public immutable I_OWNER;
    IERC20 public immutable I_MNEE;
    uint256 public escrowCount;
    mapping(uint256 => Escrow) public escrows;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event EscrowCreated(
        uint256 id,
        address indexed buyer,
        address indexed seller,
        address indexed arbiter,
        uint256 amount,
        uint256 timeout
    );

    event Released(uint256 indexed id);
    event Disputed(uint256 indexed id);
    event Arbitrated(uint256 indexed id, bool releasedToSeller);
    event AutoReleased(uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyBuyer(uint256 id) {
        if (msg.sender != escrows[id].buyer) revert NotBuyer();
        _;
    }

    modifier onlySeller(uint256 id) {
        if (msg.sender != escrows[id].seller) revert NotSeller();
        _;
    }

    modifier onlyArbiter(uint256 id) {
        if (msg.sender != escrows[id].arbiter) revert NotArbiter();
        _;
    }

    modifier inState(uint256 id, EscrowStatus s) {
        if (escrows[id].status != s) revert InvalidState();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _mnee) {
        I_MNEE = IERC20(_mnee);
        I_OWNER = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                         ESCROW CREATION
    //////////////////////////////////////////////////////////////*/

    function createEscrow(
        address seller,
        address arbiter,
        uint256 amount,
        uint64 timeoutSeconds
    ) external nonReentrant returns (uint256 id) {
        if (seller == address(0)) revert InvalidInput();
        if (arbiter == address(0)) revert InvalidInput();
        if (amount <= 0) revert InvalidInput();
        if (timeoutSeconds <= 0) revert InvalidInput();
        if (arbiter == seller) revert ArbiterCannotBeBuyerOrSeller();
        if (arbiter == msg.sender) revert ArbiterCannotBeBuyerOrSeller();
        

        I_MNEE.safeTransferFrom(msg.sender, address(this), amount);

        id = ++escrowCount;

        escrows[id] = Escrow({
            buyer: msg.sender,
            seller: seller,
            arbiter: arbiter,
            amount: amount,
            createdAt: uint64(block.timestamp),
            timeout: timeoutSeconds,
            status: EscrowStatus.AWAITING_DELIVERY
        });

        emit EscrowCreated(
            id,
            msg.sender,
            seller,
            arbiter,
            amount,
            timeoutSeconds
        );
    }

    /*//////////////////////////////////////////////////////////////
                         BUYER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function release(
        uint256 id
    )
        external
        nonReentrant
        onlyBuyer(id)
        inState(id, EscrowStatus.AWAITING_DELIVERY)
    {
        _releaseToSeller(id);
        emit Released(id);
    }

    function dispute(
        uint256 id
    ) external onlyBuyer(id) inState(id, EscrowStatus.AWAITING_DELIVERY) {
        escrows[id].status = EscrowStatus.DISPUTED;
        emit Disputed(id);
    }

    /*//////////////////////////////////////////////////////////////
                        TIMEOUT AUTO-RELEASE
    //////////////////////////////////////////////////////////////*/

    function autoRelease(
        uint256 id
    )
        external
        nonReentrant
        onlySeller(id)
        inState(id, EscrowStatus.AWAITING_DELIVERY)
    {
        Escrow storage e = escrows[id];
        if (block.timestamp < (e.createdAt + e.timeout))
            revert TimeoutNotReached();

        _releaseToSeller(id);
        emit AutoReleased(id);
    }

    /*//////////////////////////////////////////////////////////////
                         ARBITRATION (DISPUTE ONLY)
    //////////////////////////////////////////////////////////////*/

    function arbitrate(
        uint256 id,
        bool releaseToSeller
    ) external nonReentrant onlyArbiter(id) inState(id, EscrowStatus.DISPUTED) {
        Escrow storage e = escrows[id];
        e.status = releaseToSeller
            ? EscrowStatus.COMPLETED
            : EscrowStatus.REFUNDED;

        uint256 platformFee = (e.amount * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint256 arbiterFee = (e.amount * ARBITER_FEE_BPS) / BPS_DENOMINATOR;

        uint256 remaining = e.amount - platformFee - arbiterFee;

        I_MNEE.safeTransfer(I_OWNER, platformFee);
        I_MNEE.safeTransfer(e.arbiter, arbiterFee);

        if (releaseToSeller) {
            I_MNEE.safeTransfer(e.seller, remaining);
        } else {
            I_MNEE.safeTransfer(e.buyer, remaining);
        }

        emit Arbitrated(id, releaseToSeller);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function _releaseToSeller(uint256 id) internal {
        Escrow storage e = escrows[id];
        e.status = EscrowStatus.COMPLETED;

        uint256 platformFee = (e.amount * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = e.amount - platformFee;

        I_MNEE.safeTransfer(I_OWNER, platformFee);
        I_MNEE.safeTransfer(e.seller, payout);
    }
}
