// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "./dependencies/LandOwnableUpgradeable.sol";
import "./interfaces/ILand.sol";

contract Land is ILand, LandOwnableUpgradeable {
	using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;
	uint64 public constant coinPerLand = 1e6;
	uint8 public constant targetPriceDecimals = 18;
	EnumerableMapUpgradeable.AddressToUintMap internal coins;
	mapping(bytes32 => uint256) internal balances;
	mapping(bytes32 => mapping(ICoin => uint256)) public balancesForCoin;
	bool public paused;

	modifier onlyGuardian() {
		require(msg.sender == guardian(), "Land: Caller is not guardian");
		_;
	}

	function initialize(ILandCore _core, ICoin[] memory _coins) external initializer {
		__InitCore(_core);
		for (uint256 i = 0; i < _coins.length; i++) {
			_addCoin(_coins[i]);
		}
	}

	function mint(ICoin coin, bytes32 to, uint256 amount) external {
		require(!paused, "Land: paused");
		require(coinExists(coin), "Land: nonexistent coin");
		coin.transferFrom(msg.sender, address(this), amount);
		uint256 coinAmount = formatValue(coin, amount);
		uint256 landAmount = coinAmount * coinPerLand;
		balances[to] += landAmount;
		balancesForCoin[to][coin] += landAmount;
		emit Mint(coin, amount, coinAmount, landAmount);
	}

	function addCoin(ICoin coin) external onlyGuardian {
		_addCoin(coin);
	}

	function _addCoin(ICoin coin) internal {
		require(!coinExists(coin), "Land: coin exists");
		uint8 decimals = coin.decimals();
		coins.set(address(coin), decimals);
		emit AddCoin(coin);
	}

	function removeCoin(ICoin coin) external onlyGuardian {
		_removeCoin(coin);
	}

	function _removeCoin(ICoin coin) internal {
		require(coinExists(coin), "Land: nonexistent coin");
		coins.remove(address(coin));
		emit RemoveCoin(coin);
	}

	function coinLength() public view returns(uint256) {
		return coins.length();
	}

	function coinAt(uint256 i) public view returns(address, uint256) {
		return coins.at(i);
	}

	function coinExists(ICoin coin) public view returns(bool) {
		return coins.contains(address(coin));
	}

	function decimalsOf(ICoin coin) public view returns(uint8) {
		return uint8(coins.get(address(coin)));
	}

	function balanceOf(bytes32 to) public view returns(uint256) {
		return balances[to];
	}

	function formatValue(ICoin coin, uint256 amount) public view returns(uint256) {
		uint8 decimals = decimalsOf(coin);
		if (decimals < targetPriceDecimals) {
			return amount * (10 ** (targetPriceDecimals - decimals));
		} else if (decimals  > targetPriceDecimals) {
			return amount / (10 ** (targetPriceDecimals - decimals));
		}
		return amount;
	}

	function setPaused(bool _paused) external onlyOwner {
		paused = _paused;
	}

	function withdraw(ICoin coin, address to, uint256 amount) external onlyOwner {
		if (address(coin) != address(0)) {
			coin.transfer(to, amount);
		} else {
			(bool success,) = to.call{value: amount}("");
			require(success, "Land: tranfer failed");
		}
		emit WithdrawnCoin(coin, to, amount);
	}

}