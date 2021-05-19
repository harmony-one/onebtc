.. _issue-protocol:

Issue
=====

Overview
~~~~~~~~

The Issue module allows as user to create new ONEBTC tokens. The user needs to request ONEBTC through the :ref:`requestIssue` function, then send BTC to a vault, and finally complete the issuing of ONEBTC by calling the :ref:`executeIssue` function. If the user does not complete the process in time, the vault can cancel the issue request and receive a griefing collateral from the user by invoking the :ref:`cancelIssue` function. Below is a high-level step-by-step description of the protocol.

Step-by-step
------------

1. Precondition: a vault has locked collateral as described in the :ref:`Vault-registry`.
2. A user executes the :ref:`requestIssue` function to open an issue request on the BTC Parachain. The issue request includes the amount of ONEBTC the user wants to issue, the selected vault, and a small collateral to prevent :ref:`griefing`.
3. A user sends the equivalent amount of BTC that he wants to issue as ONEBTC to the vault on the Bitcoin blockchain.
4. The user or a vault acting on behalf of the user extracts a transaction inclusion proof of that locking transaction on the Bitcoin blockchain. The user or a vault acting on behalf of the user executes the :ref:`executeIssue` function on the BTC Parachain. The issue function requires a reference to the issue request and the transaction inclusion proof of the Bitcoin locking transaction. If the function completes successfully, the user receives the requested amount of ONEBTC into his account.
5. Optional: If the user is not able to complete the issue request within the predetermined time frame (``IssuePeriod``), the vault is able to call the :ref:`cancelIssue` function to cancel the issue request adn will receive the griefing collateral locked by the user.

Security
--------

- Unique identification of Bitcoin payments: :ref:`okd`

Vault Registry
--------------

The data access and state changes to the vault registry are documented in :numref:`fig-vault-registry-issue` below.

.. _fig-vault-registry-issue:
.. figure:: ../figures/VaultRegistry-Issue.png
    :alt: vault-registry-issue

    The issue protocol interacts with three functions in the vault registry that handle updating the different token balances.

Fee Model
---------

Following additions are added if the fee model is integrated.

- Issue fees are paid by users in ONEBTC when executing the request. The fees are transferred to the Parachain Fee Pool.
- If an issue request is executed, the user’s griefing collateral is returned.
- If an issue request is canceled, the vault assigned to this issue request receives the griefing collateral.


Data Model
~~~~~~~~~~

Scalars
-------

IssuePeriod
............

The time difference between when an issue request is created and required completion time by a user. Concretely, this period is the amount by which :ref:`activeBlockCount` is allowed to increase before the issue is considered to be expired. The period has an upper limit to prevent griefing of vault collateral.

IssueGriefingCollateral
........................

The minimum collateral (ONE) a user needs to provide as griefing protection.

.. note:: Serves as a measurement to disincentivize griefing attacks against a vault. A user could otherwise create an issue request, temporarily locking a vault's collateral and never execute the issue process.


Maps
----

IssueRequests
.............

Users create issue requests to issue ONEBTC. This mapping provides access from a unique hash ``IssueId`` to a ``Issue`` struct. ``<IssueId, Issue>``.


Structs
-------

Issue
.....

Stores the status and information about a single issue request.

.. tabularcolumns:: |l|l|L|

======================  ==========  =======================================================
Parameter               Type        Description
======================  ==========  =======================================================
``vault``               Account     The BTC Parachain address of the vault responsible for this commit request.
``opentime``            u256        Block height of opening the request.
``griefingCollateral``  ONE         Collateral provided by a user.
``amount``              ONEBTC      Amount of ONEBTC to be issued.
``fee``                 ONEBTC      Fee charged to the user for issuing.
``requester``           Account     User account receiving ONEBTC upon successful issuing.
``btcAddress``          bytes[20]   Base58 encoded Bitcoin public key of the Vault.
``completed``           bool        Indicates if the issue has been completed.
``cancelled``           bool        Indicates if the issue request was cancelled.
======================  ==========  =======================================================

.. *Substrate*::

  #[derive(Encode, Decode, Default, Clone, PartialEq)]
  #[cfg_attr(feature = "std", derive(Debug))]
  pub struct Issue<AccountId, BlockNumber, ONEBTC, ONE> {
        vault: AccountId,
        opentime: BlockNumber,
        griefing_collateral: ONE,
        amount: ONEBTC,
        requester: AccountId,
        btc_address: H160,
        completed: bool
  }

Functions
~~~~~~~~~

.. _requestIssue:

requestIssue
------------

A user opens an issue request to create a specific amount of ONEBTC.
When calling this function, a user provides her own parachain account identifier, the to be issued amount of ONEBTC, and the vault she wants to use in this process (parachain account identifier). Further, she provides some (small) amount of ONE collateral (``griefingCollateral``) to prevent griefing.

Specification
.............

*Function Signature*

``requestIssue(requester, amount, vault, griefingCollateral)``

*Parameters*

* ``requester``: The user's BTC Parachain account.
* ``amount``: The amount of ONEBTC to be issued.
* ``vault``: The BTC Parachain address of the vault involved in this issue request.
* ``griefingCollateral``: The collateral amount provided by the user as griefing protection.

*Events*

* ``RequestIssue(issueId, requester, amount, vault, btcAddress)``

*Errors*

* ``ERR_VAULT_NOT_FOUND = "There exists no vault with the given account id"``: The specified vault does not exist.
* ``ERR_VAULT_BANNED = "The selected vault has been temporarily banned."``: Issue requests are not possible with temporarily banned Vaults.
* ``ERR_INSUFFICIENT_COLLATERAL``: The user did not provide enough griefing collateral.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must be set to ``RUNNING:0``.

Function Sequence
.................

1. Retrieve the ``vault`` from :ref:`vault-registry`. Return ``ERR_VAULT_NOT_FOUND`` if no vault can be found.

2. Check that the ``vault`` is currently not banned, i.e., ``vault.bannedUntil == None`` or ``vault.bannedUntil < current parachain block height``. Return ``ERR_VAULT_BANNED`` if this check fails.

3. Check if the ``griefingCollateral`` is greater or equal ``IssueGriefingCollateral``. If this check fails, return ``ERR_INSUFFICIENT_COLLATERAL``.

4. Lock the user's griefing collateral by calling the :ref:`lockCollateral` function with the ``requester`` as the sender and the ``griefingCollateral`` as the amount.

5. Call the VaultRegistry :ref:`increaseToBeIssuedTokens` function with the ``amount`` of tokens to be issued and the ``vault`` identified by its address. This function returns a unique ``btcAddress`` that the user should send Bitcoin to.

6. Generate an ``issueId`` via :ref:`generateSecureId`.

7. Store a new ``Issue`` struct in the ``IssueRequests`` mapping as ``IssueRequests[issueId] = issue``, where ``issue`` is the ``Issue`` struct as:

    - ``issue.vault`` is the ``vault``
    - ``issue.opentime`` is the current block number
    - ``issue.griefingCollateral`` is the griefing collateral provided by the user
    - ``issue.amount`` is the ``amount`` provided as input
    - ``issue.requester`` is the user's account
    - ``issue.btcAddress`` the Bitcoin address of the vault as returned in step 3

8. Issue the ``RequestIssue`` event with the ``issueId``, the ``requester`` account, ``amount``, ``vault``, and ``btcAddress``.


.. _executeIssue:

executeIssue
------------

A user completes the issue request by sending a proof of transferring the defined amount of BTC to the vault's address.

Specification
.............

*Function Signature*

``executeIssue(requester, issueId, merkleProof, rawTx)``

*Parameters*

* ``requester``: the account of the user.
* ``issueId``: the unique hash created during the ``requestIssue`` function.
* ``merkleProof``: Merkle tree path (concatenated LE SHA256 hashes).
* ``rawTx``: Raw Bitcoin transaction including the transaction inputs and outputs.


*Events*

* ``ExecuteIssue(issueId, requester, amount, vault)``: Emits an event with the information about the completed issue request.

*Errors*

* ``ERR_ISSUE_ID_NOT_FOUND``: The ``issueId`` cannot be found.
* ``ERR_COMMIT_PERIOD_EXPIRED``: The time limit as defined by the ``IssuePeriod`` is not met.
* ``ERR_UNAUTHORIZED_USER = Unauthorized: Caller must be associated user``: The caller of this function is not the associated user, and hence not authorized to take this action.


Preconditions
.............

* The BTC Parachain status in the :ref:`security` component must be set to ``RUNNING:0``.

.. todo:: REJECT any Issue request where the sender BTC address belongs to an existing Vault.



Function Sequence
.................

.. note:: Ideally the ``SecureCollateralThreshold`` in the VaultRegistry should be high enough to prevent the vault from entering into the liquidation state in-between the request and execute.

1. Checks if the ``issueId`` exists. Return ``ERR_ISSUE_ID_NOT_FOUND`` if not found. Else, loads the according issue request struct as ``issue``.
2. Checks if the issue has expired by calling :ref:`hasExpired` in the Security module. If true, this throws ``ERR_COMMIT_PERIOD_EXPIRED``.
3. Verify the transaction.

    a. Call *verifyTransactionInclusion* in :ref:`btc-relay`, providing the ``txId``, and ``merkleProof`` as parameters. If this call returns an error, abort and return the received error.
    b. Call *validateTransaction* in :ref:`btc-relay`, providing ``rawTx``, the amount of to-be-issued BTC (``issue.amount``), the ``vault``'s Bitcoin address (``issue.btcAddress``), and the ``issueId`` as parameters. If this call returns an error, abort and return the received error.

4. Call the :ref:`issueTokens` with the ``issue.vault`` and the ``amount`` to decrease the ``toBeIssuedTokens`` and increase the ``issuedTokens``.
5. Call the :ref:`mint` function in the Treasury with the ``amount`` and the user's address as the ``receiver``.
6. Remove the ``IssueRequest`` from ``IssueRequests``.
7. Emit an ``ExecuteIssue`` event with the user's address, the issueId, the amount, and the Vault's address.

.. _cancelIssue:

cancelIssue
-----------

If an issue request is not completed on time, the issue request can be cancelled.

Specification
.............

*Function Signature*

``cancelIssue(sender, issueId)``

*Parameters*

* ``sender``: The sender of the cancel transaction.
* ``issueId``: the unique hash of the issue request.


*Events*

* ``CancelIssue(sender, issueId)``: Issues an event with the ``issueId`` that is cancelled.

*Errors*

* ``ERR_ISSUE_ID_NOT_FOUND``: The ``issueId`` cannot be found.
* ``ERR_TIME_NOT_EXPIRED``: Raises an error if the time limit to call ``executeIssue`` has not yet passed.
* ``ERR_ISSUE_COMPLETED``: Raises an error if the issue is already completed.

Preconditions
.............

* None.


Function Sequence
.................

1. Check if an issue with id ``issueId`` exists. If not, throw ``ERR_ISSUE_ID_NOT_FOUND``. Otherwise, load the issue request  as ``issue``.

2. Check if the issue has expired by calling :ref:`hasExpired` in the Security module, and throw ``ERR_TIME_NOT_EXPIRED`` if not.

3. Check if the ``issue.completed`` field is set to true. If yes, throw ``ERR_ISSUE_COMPLETED``.

4. Call the :ref:`decreaseToBeIssuedTokens` function in the VaultRegistry with the ``issue.vault`` and the ``issue.amount`` to release the vault's collateral.

5. Call the :ref:`slashCollateral` function to transfer the ``griefingCollateral`` of the user requesting the issue to the vault assigned to this issue request with the ``issue.requester`` as sender, the ``issue.vault`` as receiver, and ``issue.griefingCollateral`` as amount.

6. Remove the ``IssueRequest`` from ``IssueRequests``.

8. Emit a ``CancelIssue`` event with the ``issueId``.


Events
~~~~~~

RequestIssue
------------

Emit a ``RequestIssue`` event if a user successfully open a issue request.

*Event Signature*

``RequestIssue(issueId, requester, amount, vault, btcAddress)``

*Parameters*

* ``issueId``: A unique hash identifying the issue request.
* ``requester``: The user's BTC Parachain account.
* ``amount``: The amount of ONEBTC to be issued.
* ``vault``: The BTC Parachain address of the vault involved in this issue request.
* ``btcAddress``: The Bitcoin address of the vault.

*Functions*

* :ref:`requestIssue`

ExecuteIssue
------------

*Event Signature*

``ExecuteIssue(issueId, requester, amount, vault)``

*Parameters*

* ``issueId``: A unique hash identifying the issue request.
* ``requester``: The user's BTC Parachain account.
* ``amount``: The amount of ONEBTC to be issued.
* ``vault``: The BTC Parachain address of the vault involved in this issue request.

*Functions*

* :ref:`executeIssue`

CancelIssue
-----------

*Event Signature*

``CancelIssue(issueId, sender)``

*Parameters*

* ``issueId``: the unique hash of the issue request.
* ``sender``: The sender of the cancel transaction.

*Functions*

* :ref:`cancelIssue`

Error Codes
~~~~~~~~~~~

``ERR_VAULT_NOT_FOUND``

* **Message**: "There exists no vault with the given account id."
* **Function**: :ref:`requestIssue`
* **Cause**: The specified vault does not exist.

``ERR_VAULT_BANNED``

* **Message**: "The selected vault has been temporarily banned."
* **Function**: :ref:`requestIssue`
* **Cause**:  Issue requests are not possible with temporarily banned Vaults

``ERR_INSUFFICIENT_COLLATERAL``

* **Message**: "User provided collateral below limit."
* **Function**: :ref:`requestIssue`
* **Cause**: User provided griefingCollateral below ``IssueGriefingCollateral``.

``ERR_UNAUTHORIZED_USER``

* **Message**: "Unauthorized: Caller must be associated user"
* **Function**: :ref:`executeIssue`
* **Cause**: The caller of this function is not the associated user, and hence not authorized to take this action.

``ERR_ISSUE_ID_NOT_FOUND``

* **Message**: "Requested issue id not found."
* **Function**: :ref:`executeIssue`
* **Cause**: Issue id not found in the ``IssueRequests`` mapping.

``ERR_COMMIT_PERIOD_EXPIRED``

* **Message**: "Time to issue ONEBTC expired."
* **Function**: :ref:`executeIssue`
* **Cause**: The user did not complete the issue request within the block time limit defined by the ``IssuePeriod``.

``ERR_TIME_NOT_EXPIRED``

* **Message**: "Time to issue ONEBTC not yet expired."
* **Function**: :ref:`cancelIssue`
* **Cause**: Raises an error if the time limit to call ``executeIssue`` has not yet passed.

``ERR_ISSUE_COMPLETED``

* **Message**: "Issue completed and cannot be cancelled."
* **Function**: :ref:`cancelIssue`
* **Cause**: Raises an error if the issue is already completed.

