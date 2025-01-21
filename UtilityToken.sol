// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Imports OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title UtilityToken
 * @dev Un token ERC20 avec rôle ADMIN, pouvant faire du mint/burn
 */
contract UtilityToken is ERC20, AccessControl {
    // Déclaration du rôle ADMIN
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @dev Le constructeur donne 10 000 tokens au déployeur,
     *      et lui accorde aussi le rôle ADMIN.
     */
    constructor() ERC20("MyUtilityToken", "MUT") {
        // On accorde le rôle ADMIN au déployeur
        _grantRole(ADMIN_ROLE, msg.sender);

        // Par exemple, on mint 10 000 tokens pour le déployeur
        _mint(msg.sender, 10000 * (10 ** decimals()));
    }

    /**
     * @dev Mint - seulement un ADMIN peut minter des tokens
     */
    function mint(address to, uint256 amount) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
        _mint(to, amount * 10**18);
    }

    /**
     * @dev Burn - un ADMIN peut burn depuis n’importe quelle adresse,
     *            ou un utilisateur peut se burn lui-même
     */
    function burn(address from, uint256 amount) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || msg.sender == from,
            "Not authorized to burn"
        );
        _burn(from, amount);
    }
}
