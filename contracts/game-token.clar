
;; title: game-token
;; version: 1.0.0
;; summary: SIP-010 compliant Gaming Token (GTK) for play-to-earn ecosystem
;; description: Native fungible token with minting, burning, and administrative controls

;; traits
;; (none - following requirements to avoid trait usage)

;; token definitions
(define-fungible-token game-token)

;; constants
;; Token metadata
(define-constant token-name "Gaming Token")
(define-constant token-symbol "GTK")
(define-constant token-decimals u6)
(define-constant token-uri u"https://gaming-tokens.io/metadata")

;; Supply constants
(define-constant initial-supply u1000000000000000) ;; 1 billion GTK (with 6 decimals)
(define-constant max-supply u10000000000000000) ;; 10 billion GTK maximum
(define-constant min-transfer-amount u1) ;; Minimum transfer: 0.000001 GTK

;; Error constants
(define-constant err-owner-only (err u2000))
(define-constant err-not-token-owner (err u2001))
(define-constant err-insufficient-balance (err u2002))
(define-constant err-insufficient-allowance (err u2003))
(define-constant err-invalid-amount (err u2004))
(define-constant err-invalid-recipient (err u2005))
(define-constant err-token-not-found (err u2006))
(define-constant err-unauthorized-minter (err u2007))
(define-constant err-unauthorized-burner (err u2008))
(define-constant err-exceeds-max-supply (err u2009))
(define-constant err-transfer-failed (err u2010))
(define-constant err-invalid-spender (err u2011))
(define-constant err-self-transfer (err u2012))
(define-constant err-zero-amount (err u2013))
(define-constant err-contract-paused (err u2014))
(define-constant err-burn-exceeds-balance (err u2015))

;; Transfer fee constants (in basis points - 100 = 1%)
(define-constant transfer-fee-rate u0) ;; 0% fee initially
(define-constant max-transfer-fee-rate u500) ;; Max 5% fee

;; data vars
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var token-paused bool false)
(define-data-var mint-enabled bool true)
(define-data-var burn-enabled bool true)
(define-data-var transfer-fee-enabled bool false)
(define-data-var fee-recipient principal tx-sender)

;; data maps
;; Token balances
(define-map balances
  { owner: principal }
  { balance: uint }
)

;; Token allowances for spending
(define-map allowances
  { owner: principal, spender: principal }
  { allowance: uint }
)

;; Authorized minters
(define-map authorized-minters
  { minter: principal }
  {
    authorized: bool,
    max-mint-amount: uint,
    authorized-by: principal,
    authorized-at: uint
  }
)

;; Authorized burners
(define-map authorized-burners
  { burner: principal }
  {
    authorized: bool,
    max-burn-amount: uint,
    authorized-by: principal,
    authorized-at: uint
  }
)

;; Transaction history for auditing
(define-map transaction-history
  { tx-id: uint }
  {
    from: principal,
    to: principal,
    amount: uint,
    block-height: uint,
    tx-type: (string-ascii 16)
  }
)

;; Token holder information
(define-map token-holders
  { holder: principal }
  {
    first-received: uint,
    last-activity: uint,
    total-received: uint,
    total-sent: uint
  }
)

(define-data-var tx-counter uint u0)

;; public functions

;; SIP-010 Standard Functions

;; Transfer tokens from sender to recipient
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (var-get token-paused)) err-contract-paused)
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (>= amount min-transfer-amount) err-invalid-amount)
    (asserts! (not (is-eq sender recipient)) err-self-transfer)
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (asserts! (>= (get-balance sender) amount) err-insufficient-balance)
    
    ;; Execute the transfer
    (try! (ft-transfer? game-token amount sender recipient))
    
    ;; Update holder statistics
    (update-holder-stats sender recipient amount)
    
    ;; Record transaction
    (record-transaction sender recipient amount "transfer")
    
    ;; Print memo if provided
    (match memo m (print m) 0x)
    (print { type: "sip010-transfer", sender: sender, recipient: recipient, amount: amount })
    (ok true)
  )
)

;; Get token name
(define-read-only (get-name)
  (ok token-name)
)

;; Get token symbol
(define-read-only (get-symbol)
  (ok token-symbol)
)

;; Get token decimals
(define-read-only (get-decimals)
  (ok token-decimals)
)

;; Get token balance for a principal
(define-read-only (get-balance (account principal))
  (ft-get-balance game-token account)
)

;; Get total token supply
(define-read-only (get-total-supply)
  (ok (ft-get-supply game-token))
)

;; Get token URI
(define-read-only (get-token-uri)
  (ok (some token-uri))
)

;; Transfer from allowance
(define-public (transfer-from (amount uint) (owner principal) (recipient principal) (memo (optional (buff 34))))
  (let (
    (allowance-key { owner: owner, spender: tx-sender })
    (current-allowance (default-to u0 (get allowance (map-get? allowances allowance-key))))
  )
    (asserts! (not (var-get token-paused)) err-contract-paused)
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (not (is-eq owner recipient)) err-self-transfer)
    (asserts! (>= current-allowance amount) err-insufficient-allowance)
    (asserts! (>= (get-balance owner) amount) err-insufficient-balance)
    
    ;; Update allowance
    (if (> current-allowance amount)
      (map-set allowances allowance-key { allowance: (- current-allowance amount) })
      (map-delete allowances allowance-key)
    )
    
    ;; Execute transfer
    (try! (ft-transfer? game-token amount owner recipient))
    
    ;; Update holder statistics
    (update-holder-stats owner recipient amount)
    
    ;; Record transaction
    (record-transaction owner recipient amount "transfer-from")
    
    ;; Print memo if provided
    (match memo m (print m) 0x)
    (print { type: "sip010-transfer-from", owner: owner, spender: tx-sender, recipient: recipient, amount: amount })
    (ok true)
  )
)

;; Approve spending allowance
(define-public (approve (spender principal) (amount uint))
  (begin
    (asserts! (not (is-eq tx-sender spender)) err-invalid-spender)
    (asserts! (not (var-get token-paused)) err-contract-paused)
    
    (if (> amount u0)
      (map-set allowances 
        { owner: tx-sender, spender: spender } 
        { allowance: amount }
      )
      (map-delete allowances { owner: tx-sender, spender: spender })
    )
    
    (print { type: "sip010-approve", owner: tx-sender, spender: spender, amount: amount })
    (ok true)
  )
)

;; Get allowance
(define-read-only (get-allowance (owner principal) (spender principal))
  (default-to u0 (get allowance (map-get? allowances { owner: owner, spender: spender })))
)

;; Administrative functions

;; Initialize token supply (can only be called once by owner)
(define-public (initialize-supply)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    (asserts! (is-eq (var-get total-supply) u0) (err u2016)) ;; Already initialized
    
    ;; Mint initial supply to contract owner
    (try! (ft-mint? game-token initial-supply tx-sender))
    (var-set total-supply initial-supply)
    
    ;; Initialize holder stats for owner
    (map-set token-holders
      { holder: tx-sender }
      {
        first-received: block-height,
        last-activity: block-height,
        total-received: initial-supply,
        total-sent: u0
      }
    )
    
    (record-transaction tx-sender tx-sender initial-supply "mint")
    (print { type: "token-initialize", amount: initial-supply, recipient: tx-sender })
    (ok true)
  )
)

;; Mint new tokens (authorized minters only)
(define-public (mint (amount uint) (recipient principal))
  (let (
    (minter-info (map-get? authorized-minters { minter: tx-sender }))
    (new-supply (+ (ft-get-supply game-token) amount))
  )
    (asserts! (not (var-get token-paused)) err-contract-paused)
    (asserts! (var-get mint-enabled) (err u2017))
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (<= new-supply max-supply) err-exceeds-max-supply)
    
    ;; Check minting authorization
    (asserts! (or 
      (is-eq tx-sender (var-get contract-owner))
      (match minter-info
        info (and 
          (get authorized info)
          (<= amount (get max-mint-amount info))
        )
        false
      )
    ) err-unauthorized-minter)
    
    ;; Mint tokens
    (try! (ft-mint? game-token amount recipient))
    
    ;; Update holder statistics
    (update-holder-stats (var-get contract-owner) recipient amount)
    
    (record-transaction (var-get contract-owner) recipient amount "mint")
    (print { type: "token-mint", amount: amount, recipient: recipient, minter: tx-sender })
    (ok true)
  )
)

;; Burn tokens (authorized burners only)
(define-public (burn (amount uint) (owner principal))
  (let (
    (burner-info (map-get? authorized-burners { burner: tx-sender }))
    (owner-balance (get-balance owner))
  )
    (asserts! (not (var-get token-paused)) err-contract-paused)
    (asserts! (var-get burn-enabled) (err u2018))
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (>= owner-balance amount) err-burn-exceeds-balance)
    
    ;; Check burning authorization
    (asserts! (or 
      (is-eq tx-sender (var-get contract-owner))
      (is-eq tx-sender owner)
      (match burner-info
        info (and 
          (get authorized info)
          (<= amount (get max-burn-amount info))
        )
        false
      )
    ) err-unauthorized-burner)
    
    ;; Burn tokens
    (try! (ft-burn? game-token amount owner))
    
    ;; Update holder statistics
    (update-holder-stats owner (var-get contract-owner) amount)
    
    (record-transaction owner (var-get contract-owner) amount "burn")
    (print { type: "token-burn", amount: amount, owner: owner, burner: tx-sender })
    (ok true)
  )
)

;; Add authorized minter
(define-public (add-minter (minter principal) (max-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    
    (map-set authorized-minters
      { minter: minter }
      {
        authorized: true,
        max-mint-amount: max-amount,
        authorized-by: tx-sender,
        authorized-at: block-height
      }
    )
    (print { type: "minter-added", minter: minter, max-amount: max-amount })
    (ok true)
  )
)

;; Add authorized burner
(define-public (add-burner (burner principal) (max-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    
    (map-set authorized-burners
      { burner: burner }
      {
        authorized: true,
        max-burn-amount: max-amount,
        authorized-by: tx-sender,
        authorized-at: block-height
      }
    )
    (print { type: "burner-added", burner: burner, max-amount: max-amount })
    (ok true)
  )
)

;; Pause/unpause contract
(define-public (set-token-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    (var-set token-paused paused)
    (print { type: "token-pause-changed", paused: paused })
    (ok true)
  )
)

;; read only functions

(define-read-only (get-contract-info)
  {
    name: token-name,
    symbol: token-symbol,
    decimals: token-decimals,
    total-supply: (ft-get-supply game-token),
    max-supply: max-supply,
    owner: (var-get contract-owner),
    paused: (var-get token-paused),
    mint-enabled: (var-get mint-enabled),
    burn-enabled: (var-get burn-enabled)
  }
)

(define-read-only (get-holder-info (holder principal))
  (map-get? token-holders { holder: holder })
)

(define-read-only (is-minter (address principal))
  (match (map-get? authorized-minters { minter: address })
    info (get authorized info)
    false
  )
)

(define-read-only (is-burner (address principal))
  (match (map-get? authorized-burners { burner: address })
    info (get authorized info)
    false
  )
)

;; private functions

(define-private (update-holder-stats (from principal) (to principal) (amount uint))
  (let (
    (from-stats (default-to 
      { first-received: block-height, last-activity: u0, total-received: u0, total-sent: u0 }
      (map-get? token-holders { holder: from })
    ))
    (to-stats (default-to 
      { first-received: block-height, last-activity: u0, total-received: u0, total-sent: u0 }
      (map-get? token-holders { holder: to })
    ))
  )
    ;; Update sender stats
    (if (not (is-eq from to))
      (map-set token-holders
        { holder: from }
        (merge from-stats {
          last-activity: block-height,
          total-sent: (+ (get total-sent from-stats) amount)
        })
      )
      true
    )
    
    ;; Update recipient stats
    (if (not (is-eq from to))
      (map-set token-holders
        { holder: to }
        (merge to-stats {
          last-activity: block-height,
          total-received: (+ (get total-received to-stats) amount)
        })
      )
      true
    )
  )
)

(define-private (record-transaction (from principal) (to principal) (amount uint) (tx-type (string-ascii 16)))
  (let (
    (tx-id (var-get tx-counter))
  )
    (map-set transaction-history
      { tx-id: tx-id }
      {
        from: from,
        to: to,
        amount: amount,
        block-height: block-height,
        tx-type: tx-type
      }
    )
    (var-set tx-counter (+ tx-id u1))
  )
)
