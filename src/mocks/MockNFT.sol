// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../consumer/VRFConsumer.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockNFT is ERC721Enumerable, VRFConsumer {
  /// @dev Mapping from user address => flag indicating whether user is requested
  mapping(address => bool) public isUserRequested;

  /// @dev Mapping from request hash => user address
  mapping(bytes32 => address) public getUserByReqHash;

  constructor(address _vrfCoordinator) payable VRFConsumer(_vrfCoordinator) ERC721("MockNFT", "MNFT") {}

  receive() external payable {}

  function requestMintRandom() external payable {
    require(!isUserRequested[msg.sender], "MockNFT: already requested");
    _requestMintRandom(msg.sender);
  }

  function _fulfillRandomSeed(bytes32 reqHash, uint256 randomSeed) internal override {
    uint256 tokenId = randomSeed;
    address user = getUserByReqHash[reqHash];
    if (_exists(tokenId)) {
      _requestMintRandom(user);
    } else {
      _mint(user, tokenId);
    }
  }

  function callbackGaslimit() public pure returns (uint256) {
    return 500_000;
  }

  function gasPrice() public pure returns (uint256) {
    return 20e8;
  }

  function _requestMintRandom(address user) internal {
    bytes32 reqHash = _requestRandomness(address(this).balance, callbackGaslimit(), gasPrice(), user);
    isUserRequested[user] = true;
    getUserByReqHash[reqHash] = user;
  }
}
