// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { ERC1155Supply, ERC1155 } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { ERC1155Burnable } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { DefaultOperatorFilterer } from "./royalty/DefaultOperatorFilterer.sol";

// LawFi DAO + Pellar + LightLink 2022

contract Lawfi is Ownable2Step, ERC1155Burnable, ERC1155Supply, DefaultOperatorFilterer {
  using ECDSA for bytes32;

  struct TokenInfo {
    string uri;
  }

  bool public claimActive;
  address public verifier = 0x4dcd03698aE4745dED30c6C96086ff6e5dc44E0C;

  mapping(uint256 => TokenInfo) public tokens;
  mapping(address => uint256) public claimed;

  constructor() ERC1155("ipfs://QmfJaoa9KqmzfVSeQywTy9kEWh76rTo8HoMvvU4ERo1Bqp/") {}

  /* View */
  function uri(uint256 _tokenId) public view override returns (string memory) {
    require(exists(_tokenId), "Non exists token");

    if (bytes(tokens[_tokenId].uri).length > 0) {
      return tokens[_tokenId].uri;
    }

    return string(abi.encodePacked(super.uri(_tokenId), Strings.toString(_tokenId)));
  }

  /* User */
  // verified
  function claim(uint256 _tokenId, uint256 _maxAmount, uint256 _amount, bytes calldata _signature) external {
    address account = msg.sender;
    require(tx.origin == account, "Not allowed");
    require(claimActive, "Not active");
    require(_amount > 0, "Invalid amount");
    bytes32 message = keccak256(abi.encodePacked("lawfi-claim", account, _tokenId, _maxAmount));
    require(message.toEthSignedMessageHash().recover(_signature) == verifier, "Invalid signature");
    require(claimed[account] + _amount <= _maxAmount, "Exceeds max");

    claimed[account] += _amount;
    _mint(account, _tokenId, _amount, "0x");
  }

  /* Admin */
  function burn(address account, uint256 id, uint256 value) public virtual override onlyOwner {
    super.burn(account, id, value);
  }

  function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public virtual override onlyOwner {
    super.burnBatch(account, ids, values);
  }

  // verified
  function setBaseURI(string calldata _baseURI) external onlyOwner {
    _setURI(_baseURI);
  }

  // verified
  function setClaimActive(bool _active) external onlyOwner {
    claimActive = _active;
  }

  // verified
  function setVerifier(address _account) external onlyOwner {
    require(_account != address(0), "Invalid address");
    verifier = _account;
  }

  // verified
  function mint(bytes[] calldata _tokens) external onlyOwner {
    for (uint256 i = 0; i < _tokens.length; i++) {
      (uint256 tokenId, uint256 amount, address receiver) = abi.decode(_tokens[i], (uint256, uint256, address));
      _mint(receiver, tokenId, amount, "0x");
    }
  }

  // verified
  function setTokenURI(uint256[] calldata _tokenIds, string[] calldata _uris) external onlyOwner {
    require(_tokenIds.length == _uris.length, "Invalid input");
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      tokens[_tokenIds[i]].uri = _uris[i];
    }
  }

  // verified
  function withdrawETH() public onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  /* Internal */
  function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override(ERC1155Supply, ERC1155) {
    require(from == address(0) || operator == owner(), "Only owner");
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }

  /* Royalty */
  function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
    super.setApprovalForAll(operator, approved);
  }

  function safeTransferFrom(address from, address to, uint256 tokenId, uint256 amount, bytes memory data) public override onlyAllowedOperator(from) {
    super.safeTransferFrom(from, to, tokenId, amount, data);
  }

  function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override onlyAllowedOperator(from) {
    super.safeBatchTransferFrom(from, to, ids, amounts, data);
  }
}
