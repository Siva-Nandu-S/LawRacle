// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FileSharing is ReentrancyGuard {
    uint256 private constant _MAX_FILES = 100;
    uint256 private constant _PAGE_SIZE = 10;

    struct File {
        string ipfsHash;
        address sender;
        uint256 sequence;
    }

    mapping(address user => mapping(uint256 fileId => File file)) private _files;
    mapping(address user => uint256 count) private _fileCount;
    uint256 private _globalSequence;

    event FileShared(
        address indexed sender,
        address indexed receiver,
        string ipfsHash,
        uint256 indexed fileId
    );

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    function shareFile(
        address receiver,
        string calldata ipfsHash
    ) external nonReentrant onlyValidAddress(receiver) {
        require(bytes(ipfsHash).length != 0, "Empty hash");
        uint256 currentCount = _fileCount[receiver];
        require(currentCount < _MAX_FILES, "Storage full");
        
        unchecked {
            _globalSequence++;
            _fileCount[receiver] = currentCount + 1;
        }

        _files[receiver][currentCount].ipfsHash = ipfsHash;
        _files[receiver][currentCount].sender = msg.sender;
        _files[receiver][currentCount].sequence = _globalSequence;
        
        emit FileShared(msg.sender, receiver, ipfsHash, currentCount);
    }

    function getFiles(uint256 page) 
        external 
        view 
        returns (File[] memory files) 
    {
        uint256 userCount = _fileCount[msg.sender];
        uint256 start = page * _PAGE_SIZE;
        require(start <= userCount, "Invalid page");
        
        uint256 length = userCount >= start + _PAGE_SIZE ? 
            _PAGE_SIZE : userCount - start;
        
        files = new File[](length);
        for (uint256 i = 0; i < length;) {
            files[i] = _files[msg.sender][start + i];
            unchecked { ++i; }
        }
    }

    function getFileCount() external view returns (uint256) {
        return _fileCount[msg.sender];
    }
}