// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Imports OpenZeppelin
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./UtilityToken.sol";

/**
 * @title MyDAppContract
 * @dev Contrat principal qui utilise un token UtilityToken,
 *      gère des propositions, des votes, et un système de dons en Ether.
 */
contract MyDAppContract is AccessControl {
    // ============================
    //  Définition des rôles
    // ============================
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant USER_ROLE  = keccak256("USER_ROLE");

    // ============================
    //  Référence vers le Token
    // ============================
    UtilityToken public utilityToken;

    // ============================
    //  Structures et stockage
    // ============================
    struct Proposal {
        string description;
        bool executed;
        uint voteCount;
        address payable creator;  // <--- on stocke l'adresse de celui qui a créé la proposition
    }

    struct Donation {
        uint proposalId;       
        address payable beneficiary; 
        uint amount;           
        bool executed;         
    }

    Proposal[] public proposals;
    Donation[] public donations;

    // Pour suivre qui a voté pour quelle proposition
    mapping (uint => mapping (address => bool)) public hasVoted;

    // ============================
    //  Événements
    // ============================
    event ProposalCreated(uint indexed proposalId, string description);
    event Voted(uint indexed proposalId, address indexed voter);
    event Executed(uint indexed proposalId);

    event DonationReceived(uint donationId, uint proposalId, address from, uint amount);
    event DonationExecuted(uint donationId, uint amount, address beneficiary);

    // ============================
    //  Constructeur
    // ============================
    /**
     * @dev Le constructeur prend l'adresse du token (déjà déployé)
     *      et accorde le rôle ADMIN au déployeur.
     */
    constructor(address _tokenAddress) {
        // Le déployeur a le rôle ADMIN
        _grantRole(ADMIN_ROLE, msg.sender);

        // On déclare que seuls les ADMIN peuvent gérer le rôle USER
        _setRoleAdmin(USER_ROLE, ADMIN_ROLE);

        // On enregistre la référence du token
        utilityToken = UtilityToken(_tokenAddress);
    }

    // ============================
    //  Fonctions principales
    // ============================

    /**
     * @dev (1) Créer une proposition (ADMIN seulement).
     *      On retient l'adresse (creator) qui l'a initiée.
     */
    function createProposal(string memory _description) external onlyRole(ADMIN_ROLE) {
        proposals.push(Proposal({
            description: _description,
            executed: false,
            voteCount: 0,
            creator: payable(msg.sender) // l'adresse ADMIN qui crée la proposition
        }));

        emit ProposalCreated(proposals.length - 1, _description);
    }

    /**
     * @dev (2) Voter (USER seulement), nécessite de détenir ≥1 token
     */
    function vote(uint _proposalId) external onlyRole(USER_ROLE) {
        require(_proposalId < proposals.length, "Proposal does not exist");
        require(
            utilityToken.balanceOf(msg.sender) >= 1 * (10 ** utilityToken.decimals()),
            "Not enough tokens to vote"
        );
        require(!hasVoted[_proposalId][msg.sender], "Already voted");

        proposals[_proposalId].voteCount++;
        hasVoted[_proposalId][msg.sender] = true;

        emit Voted(_proposalId, msg.sender);
    }

    /**
     * @dev (3) Action publique nécessitant de brûler 1 token
     *      Ici, on illustre la logique en faisant un "burn" effectif ou partiel.
     */
    function publicActionWithTokenBurn(uint _proposalId) external {
        require(_proposalId < proposals.length, "Proposal does not exist");

        // Vérifier que l'utilisateur possède au moins 1 token
        require(
            utilityToken.balanceOf(msg.sender) >= 1 * (10 ** utilityToken.decimals()),
            "Not enough tokens"
        );

        // Modification de la description pour marquer l'action
        proposals[_proposalId].description = string(abi.encodePacked(
            proposals[_proposalId].description,
            " [public action triggered]"
        ));
    }

    /**
     * @dev (4) Exécuter une proposition (ADMIN)
     */
    function executeProposal(uint _proposalId) external onlyRole(ADMIN_ROLE) {
        require(_proposalId < proposals.length, "Proposal does not exist");
        Proposal storage prop = proposals[_proposalId];
        require(!prop.executed, "Already executed");

        // On marque la proposition comme exécutée
        prop.executed = true;

        emit Executed(_proposalId);
    }

    // ============================
    //  Don en Ether vers le CREATOR de la proposition
    // ============================

   /**
    * @dev Permet à un utilisateur d'envoyer de l'Ether au contrat
    *      pour soutenir la proposition ID donnée. L'adresse bénéficiaire
    *      est automatiquement le créateur de la proposition.
    *      L'utilisateur précise le montant exact (en Wei) dans `_amountInWei`,
    *      et on vérifie que msg.value == _amountInWei.
    *
    * Par exemple, si l'utilisateur veut donner 1 Ether :
    *  - _amountInWei = 1000000000000000000 (1 * 10^18)
    *  - msg.value = 1000000000000000000
    */
    function donateToProposal(uint _proposalId, uint _amountInWei) external payable {
        require(_proposalId < proposals.length, "Proposal does not exist");
        require(_amountInWei > 0, "Amount must be > 0");
        // Vérifie que l'Ether réellement envoyé est égal à la somme déclarée
        require(msg.value == _amountInWei, "Ether sent does not match _amountInWei");

        address payable beneficiary = proposals[_proposalId].creator;

        donations.push(Donation({
            proposalId: _proposalId,
            beneficiary: beneficiary,
            amount: _amountInWei,
            executed: false
        }));

        uint donationId = donations.length - 1;
        emit DonationReceived(donationId, _proposalId, msg.sender, _amountInWei);
    }


    /**
     * @dev Exécuter le transfert de fonds vers le bénéficiaire,
     *      seulement par un ADMIN (quand la proposition est validée, par ex.)
     */
    function executeDonation(uint donationId) external onlyRole(ADMIN_ROLE) {
        require(donationId < donations.length, "Donation does not exist");
        Donation storage d = donations[donationId];
        require(!d.executed, "Already executed");

        // On effectue le transfert depuis le contrat
        d.beneficiary.transfer(d.amount);

        d.executed = true;

        emit DonationExecuted(donationId, d.amount, d.beneficiary);
    }

    // ============================
    //  Gestion des rôles
    // ============================

    /**
     * @dev Donner le rôle USER à une adresse (ADMIN only)
     */
    function addUser(address user) external onlyRole(ADMIN_ROLE) {
        _grantRole(USER_ROLE, user);
    }

    /**
     * @dev Retirer le rôle USER à une adresse (ADMIN only)
     */
    function removeUser(address user) external onlyRole(ADMIN_ROLE) {
        _revokeRole(USER_ROLE, user);
    }

    /**
     * @dev Fallback / receive
     */
    receive() external payable {
        // L'Ether reçu reste bloqué dans address(this).balance
    }
}
