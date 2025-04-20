pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { ProxiableCounter } from "@tsxo/libsol/mocks/proxy/ProxiableCounter.sol";
import { ProxyMock } from "@tsxo/libsol/mocks/proxy/ProxyMock.sol";

interface TestEvents {
    event Received(uint256 val);
    event Count(uint256 n);
}

contract ProxyTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // State

    ProxiableCounter counter;
    ProxyMock proxy;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        counter = new ProxiableCounter();
        proxy = new ProxyMock(address(counter));
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
        (bool success, bytes memory data) = address(proxy).staticcall(countCall);
        uint256 count = abi.decode(data, (uint256));

        assert(success);
        assertEq(count, 0);

        // Increment.
        vm.expectEmit(false, false, false, true, address(proxy));
        emit Count(1);

        (success, data) = address(proxy).call(incCall);

        assert(success);
        assertEq(data.length, 0);

        (success, data) = address(proxy).staticcall(countCall);
        count = abi.decode(data, (uint256));

        assert(success);
        assertEq(count, 1);
        assertEq(counter.count(), 0);

        // Decrement.
        vm.expectEmit(false, false, false, true, address(proxy));
        emit Count(0);
        (success, data) = address(proxy).call(decCall);

        assert(success);
        assertEq(data.length, 0);

        (success, data) = address(proxy).staticcall(countCall);
        count = abi.decode(data, (uint256));

        assert(success);
        assertEq(count, 0);
        assertEq(counter.count(), 0);

        // Set Count.
        vm.expectEmit(false, false, false, true, address(proxy));
        emit Count(10);
        (success, data) = address(proxy).call(setCall);

        assert(success);
        assertEq(data.length, 0);

        (success, data) = address(proxy).staticcall(countCall);
        count = abi.decode(data, (uint256));

        assert(success);
        assertEq(count, 10);
        assertEq(counter.count(), 0);

        // Set Count wrapped.
        ProxiableCounter asCounter = ProxiableCounter(payable(address(proxy)));
        asCounter.setCount(20);
        assertEq(asCounter.count(), 20);

        // Non-existant function.
        (success, data) = address(proxy).call(notExist);
        assert(!success);
    }

    function test_ProxiesWithValue() public {
        bytes memory fundCall = abi.encodeWithSignature("fundMe()");
        address user = address(0x1234);

        vm.startPrank(user);
        vm.deal(user, 2 ether);

        // Initial state.
        assertEq(address(proxy).balance, 0);
        assertEq(address(counter).balance, 0);

        // Send to receive.
        vm.expectEmit(false, false, false, true, address(proxy));
        emit Received(1 ether);

        (bool success,) = address(proxy).call{ value: 1 ether }("");
        assert(success);

        assertEq(address(proxy).balance, 1 ether);
        assertEq(address(counter).balance, 0);

        // Send to payable function.
        vm.expectEmit(false, false, false, true, address(proxy));
        emit Received(1 ether);

        (success,) = address(proxy).call{ value: 1 ether }(fundCall);
        assert(success);

        assertEq(address(proxy).balance, 2 ether);
        assertEq(address(counter).balance, 0);

        vm.stopPrank();
    }
}
