pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { ProxiableCounter } from "@tsxo/libsol/mocks/proxy/ProxiableCounter.sol";
import { ProxyImpl } from "@tsxo/libsol/mocks/proxy/ProxyImpl.sol";

interface TestEvents {
    event Received(uint256 val);
    event Count(uint256 n);
}

contract ProxyTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // State

    ProxiableCounter counter;
    ProxyImpl impl;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        counter = new ProxiableCounter();
        impl = new ProxyImpl(address(counter));
    }

    // -------------------------------------------------------------------------
    // Tests

    function test_ProxiesCalls() public {
        bytes memory countCall = abi.encodeWithSignature("count()");
        bytes memory incCall = abi.encodeWithSignature("increment()");
        bytes memory decCall = abi.encodeWithSignature("decrement()");
        bytes memory setCall = abi.encodeWithSignature("setCount(uint256)", 10);
        bytes memory notExist = abi.encodeWithSignature("notExist()");

        // Initial state.
        (bool success, bytes memory data) = address(impl).staticcall(countCall);
        uint256 count = abi.decode(data, (uint256));

        assert(success);
        assertEq(count, 0);

        // Increment.
        vm.expectEmit(false, false, false, true, address(impl));
        emit Count(1);

        (success, data) = address(impl).call(incCall);

        assert(success);
        assertEq(data.length, 0);

        (success, data) = address(impl).staticcall(countCall);
        count = abi.decode(data, (uint256));

        assert(success);
        assertEq(count, 1);
        assertEq(counter.count(), 0);

        // Decrement.
        vm.expectEmit(false, false, false, true, address(impl));
        emit Count(0);
        (success, data) = address(impl).call(decCall);

        assert(success);
        assertEq(data.length, 0);

        (success, data) = address(impl).staticcall(countCall);
        count = abi.decode(data, (uint256));

        assert(success);
        assertEq(count, 0);
        assertEq(counter.count(), 0);

        // Set Count.
        vm.expectEmit(false, false, false, true, address(impl));
        emit Count(10);
        (success, data) = address(impl).call(setCall);

        assert(success);
        assertEq(data.length, 0);

        (success, data) = address(impl).staticcall(countCall);
        count = abi.decode(data, (uint256));

        assert(success);
        assertEq(count, 10);
        assertEq(counter.count(), 0);

        // Non-existant function.
        (success, data) = address(impl).call(notExist);
        assert(!success);
    }

    function test_ProxiesWithValue() public {
        bytes memory fundCall = abi.encodeWithSignature("fundMe()");
        address user = address(0x1234);

        vm.startPrank(user);
        vm.deal(user, 2 ether);

        // Initial state.
        assertEq(address(impl).balance, 0);
        assertEq(address(counter).balance, 0);

        // Send to receive.
        vm.expectEmit(false, false, false, true, address(impl));
        emit Received(1 ether);

        (bool success,) = address(impl).call{ value: 1 ether }("");
        assert(success);

        assertEq(address(impl).balance, 1 ether);
        assertEq(address(counter).balance, 0);

        // Send to payable function.
        vm.expectEmit(false, false, false, true, address(impl));
        emit Received(1 ether);

        (success,) = address(impl).call{ value: 1 ether }(fundCall);
        assert(success);

        assertEq(address(impl).balance, 2 ether);
        assertEq(address(counter).balance, 0);

        vm.stopPrank();
    }
}
