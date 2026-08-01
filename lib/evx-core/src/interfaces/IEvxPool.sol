// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./pool/IEvxPoolImmutables.sol";
import "./pool/IEvxPoolState.sol";
import "./pool/IEvxPoolDerivedState.sol";
import "./pool/IEvxPoolActions.sol";
import "./pool/IEvxPoolOwnerActions.sol";
import "./pool/IEvxPoolEvents.sol";

/**
 * @title The interface for an Evx Pool
 * @notice An Evx pool facilitates swapping and automated market making between any two assets that strictly conform to the ERC20 specification
 * @dev The pool interface is composed of multiple smaller interfaces for modularity: Immutables, State, DerivedState, Actions, OwnerActions, and Events
 */
interface IEvxPool is
    IEvxPoolImmutables,
    IEvxPoolState,
    IEvxPoolDerivedState,
    IEvxPoolActions,
    IEvxPoolOwnerActions,
    IEvxPoolEvents
{
    // This interface aggregates all pool functionality; implementations must satisfy all inherited interfaces
}