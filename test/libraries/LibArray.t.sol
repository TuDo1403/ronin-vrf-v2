// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 as console } from "forge-std/Test.sol";
import { LibArray } from "@vrf/contracts/libraries/LibArray.sol";

contract LibArrayTest is Test {
  function testFuzzGas_HeapSort(uint256[] memory values) public {
    vm.pauseGasMetering();
    vm.assume(values.length != 0);
    uint256[] memory self = new uint256[](values.length);
    for (uint256 i; i < self.length; ++i) {
      self[i] = i;
    }
    vm.resumeGasMetering();

    inlineHeapSortByValue(self, values);
    vm.pauseGasMetering();
    for (uint256 i; i < values.length - 1; ++i) {
      assertTrue(values[i] <= values[i + 1]);
    }
    vm.resumeGasMetering();
  }

  function testFuzzGas_QuickSort_100Elements(uint256[100] memory values) public {
    vm.pauseGasMetering();
    uint256[] memory v = new uint256[](100);
    for (uint256 i; i < v.length; ++i) {
      v[i] = values[i];
    }
    uint256[] memory self = new uint256[](values.length);
    for (uint256 i; i < self.length; ++i) {
      self[i] = i;
    }
    vm.resumeGasMetering();
    LibArray.inlineQuickSortByValue(self, v);
    vm.pauseGasMetering();
    for (uint256 i; i < v.length - 1; ++i) {
      assertTrue(v[i] <= v[i + 1]);
    }
    vm.resumeGasMetering();
  }

  function testFuzzGas_BubbleSort_100Elements(uint256[100] memory values) public {
    vm.pauseGasMetering();
    uint256[] memory v = new uint256[](100);
    for (uint256 i; i < v.length; ++i) {
      v[i] = values[i];
    }
    uint256[] memory self = new uint256[](values.length);
    for (uint256 i; i < self.length; ++i) {
      self[i] = i;
    }
    vm.resumeGasMetering();
    inlineBubbleSortByValue(self, v);
    vm.pauseGasMetering();
    for (uint256 i; i < v.length - 1; ++i) {
      assertTrue(v[i] <= v[i + 1]);
    }
    vm.resumeGasMetering();
  }

  function testFuzzGas_HeapSort_100Elements(uint256[100] memory values) public {
    vm.pauseGasMetering();
    uint256[] memory v = new uint256[](100);
    for (uint256 i; i < v.length; ++i) {
      v[i] = values[i];
    }
    uint256[] memory self = new uint256[](values.length);
    for (uint256 i; i < self.length; ++i) {
      self[i] = i;
    }
    vm.resumeGasMetering();
    inlineHeapSortByValue(self, v);
    vm.pauseGasMetering();
    for (uint256 i; i < v.length - 1; ++i) {
      assertTrue(v[i] <= v[i + 1]);
    }
    vm.resumeGasMetering();
  }

  function testFuzzGas_QuickSort(uint256[] memory values) public {
    vm.pauseGasMetering();
    vm.assume(values.length != 0);
    uint256[] memory self = new uint256[](values.length);
    for (uint256 i; i < self.length; ++i) {
      self[i] = i;
    }
    vm.resumeGasMetering();
    LibArray.inlineQuickSortByValue(self, values);
    vm.pauseGasMetering();
    for (uint256 i; i < values.length - 1; ++i) {
      assertTrue(values[i] <= values[i + 1]);
    }
    vm.resumeGasMetering();
  }

  function testFuzzGas_BubbleSort(uint256[] memory values) public {
    vm.pauseGasMetering();
    vm.assume(values.length != 0);
    uint256[] memory self = new uint256[](values.length);
    for (uint256 i; i < self.length; ++i) {
      self[i] = i;
    }
    vm.resumeGasMetering();
    inlineBubbleSortByValue(self, values);
    vm.pauseGasMetering();
    for (uint256 i; i < values.length - 1; ++i) {
      assertTrue(values[i] <= values[i + 1]);
    }
    vm.resumeGasMetering();
  }

  function inlineBubbleSortByValue(uint256[] memory self, uint256[] memory values)
    internal
    pure
    returns (uint256[] memory sorted)
  {
    unchecked {
      uint256 length = self.length;
      if (length != values.length) revert LibArray.LengthMismatch();

      for (uint256 i; i < length - 1; ++i) {
        for (uint256 j; j < length - i - 1; ++j) {
          if (values[j] > values[j + 1]) {
            // Swap values array
            (values[j], values[j + 1]) = (values[j + 1], values[j]);
            // Swap original array
            (self[j], self[j + 1]) = (self[j + 1], self[j]);
          }
        }
      }

      assembly ("memory-safe") {
        sorted := self
      }
    }
  }

  function inlineHeapSortByValue(uint256[] memory self, uint256[] memory values)
    internal
    pure
    returns (uint256[] memory sorted)
  {
    unchecked {
      uint256 current;
      uint256 largest;
      uint256 leftChild;
      uint256 rightChild;
      uint256 heapSize = self.length;
      if (heapSize == 1) return self;
      if (heapSize != values.length) revert LibArray.LengthMismatch();

      // Build max heap
      for (uint256 i = heapSize / 2; i != 0; --i) {
        current = i - 1;
        while (current < heapSize) {
          largest = current;
          leftChild = 2 * current + 1;
          rightChild = 2 * current + 2;

          if (leftChild < heapSize && values[leftChild] > values[largest]) largest = leftChild;
          if (rightChild < heapSize && values[rightChild] > values[largest]) largest = rightChild;
          if (largest != current) {
            (self[current], self[largest]) = (self[largest], self[current]);
            (values[current], values[largest]) = (values[largest], values[current]);
            current = largest;
          } else {
            break;
          }
        }
      }

      // Heap sort
      for (uint256 i = heapSize - 1; i > 0; i--) {
        (self[0], self[i]) = (self[i], self[0]);
        (values[0], values[i]) = (values[i], values[0]);
        delete current;
        while (current < i) {
          largest = current;
          leftChild = 2 * current + 1;
          rightChild = 2 * current + 2;

          if (leftChild < i && values[leftChild] > values[largest]) largest = leftChild;
          if (rightChild < i && values[rightChild] > values[largest]) largest = rightChild;
          if (largest != current) {
            (self[current], self[largest]) = (self[largest], self[current]);
            (values[current], values[largest]) = (values[largest], values[current]);
            current = largest;
          } else {
            break;
          }
        }
      }

      assembly ("memory-safe") {
        sorted := self
      }
    }
  }
}
