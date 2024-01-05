// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../consumer/VRFConsumer.sol";
import "../interfaces/coordinators/IRoninVRFCoordinatorForConsumers.sol";
import "../interfaces/coordinators/IRoninVRFCoordinator.sol";

contract ConsumerTest is VRFConsumer, AccessControlEnumerable {
  bytes32 constant SENTRY_ROLE = keccak256("SENTRY_ROLE");

  /// @dev Mapping from request hash => token id
  mapping(bytes32 => uint256) public randomHashOfToken;
  /// @dev Mapping from token id => random result
  mapping(uint256 => uint256) public randomResult;
  /// @dev Mapping from token id => oracleAddr
  mapping(uint256 => address) public oracleAddr;

  constructor(address vrfCoordinator_, address sentry) payable VRFConsumer(vrfCoordinator_) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(SENTRY_ROLE, _msgSender());
    _setupRole(SENTRY_ROLE, sentry);
  }

  /**
   * @dev Returns many random results.
   */
  function getManyRandomResults(uint256[] calldata _tokenIds) external view returns (uint256[] memory _randomResults) {
    _randomResults = new uint256[](_tokenIds.length);
    for (uint256 _i = 0; _i < _randomResults.length; _i++) {
      _randomResults[_i] = randomResult[_tokenIds[_i]];
    }
  }

  /**
   * @dev Returns many oracle addresses from the token id list.
   */
  function getManyOracleAddressOf(uint256[] calldata _tokenIds)
    external
    view
    returns (address[] memory _oracleAddresses)
  {
    _oracleAddresses = new address[](_tokenIds.length);
    for (uint256 _i = 0; _i < _oracleAddresses.length; _i++) {
      _oracleAddresses[_i] = oracleAddr[_tokenIds[_i]];
    }
  }

  /**
   * @dev Tests request randomness.
   */
  function testRequestRandomness(
    uint256 _callbackGaslimit,
    uint256 _gasPrice,
    address _refundAddr,
    uint256 _tokenId
  ) public payable onlyRole(SENTRY_ROLE) {
    require(_tokenId > 0, "ConsumerMock: invalid tokenId");
    bytes32 _reqHash = _requestRandomness(msg.value, _callbackGaslimit, _gasPrice, _refundAddr);
    randomHashOfToken[_reqHash] = _tokenId;
    payable(msg.sender).transfer(address(this).balance);
  }

  function testRequestRandomnessWithNotConsumerAddress(
    uint256 _callbackGasLimit,
    uint256 _gasPrice,
    address _refundAddr,
    uint256 _tokenId
  ) public payable onlyRole(SENTRY_ROLE) {
    bytes32 _reqHash = _fakeRequestRandomness(msg.value, _callbackGasLimit, _gasPrice, _refundAddr);
    randomHashOfToken[_reqHash] = _tokenId;
    payable(msg.sender).transfer(address(this).balance);
  }

  /**
   * @dev Set new Vrf coordinator address.
   */
  function setVrfCoordinator(address vrfCoordinator_) public onlyRole(DEFAULT_ADMIN_ROLE) {
    _vrfCoordinator = vrfCoordinator_;
  }

  function _fakeRequestRandomness(
    uint256 _value,
    uint256 _callbackGasLimit,
    uint256 _gasPriceToFulFill,
    address _refundAddr
  ) internal returns (bytes32 _reqHash) {
    return
      IRoninVRFCoordinatorForConsumers(_vrfCoordinator).requestRandomSeed{ value: _value }(
        _callbackGasLimit,
        _gasPriceToFulFill,
        address(0),
        _refundAddr
      );
  }

  /**
   * @dev Override `VRFVRFConsumer-_fulfillRandomSeed`.
   */
  function _fulfillRandomSeed(bytes32 _reqHash, uint256 _randomSeed) internal virtual override {
    uint256 _tokenId = randomHashOfToken[_reqHash];
    require(_tokenId > 0, "ConsumerMock: invalid request hash");
    randomResult[_tokenId] = _randomSeed;
    oracleAddr[_tokenId] = tx.origin;
  }
}
