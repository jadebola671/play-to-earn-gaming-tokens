
;; title: achievement-rewards
;; version: 1.0.0
;; summary: Play-to-earn gaming achievement rewards system
;; description: Manages game achievements, player progress tracking, and automated reward distribution

;; traits
;; (none - following requirements to avoid cross-contract calls)

;; token definitions
;; (none)

;; constants
;; Error codes
(define-constant err-owner-only (err u1000))
(define-constant err-achievement-not-found (err u1001))
(define-constant err-achievement-already-exists (err u1002))
(define-constant err-player-not-eligible (err u1003))
(define-constant err-achievement-already-completed (err u1004))
(define-constant err-no-rewards-to-claim (err u1005))
(define-constant err-invalid-achievement-data (err u1006))
(define-constant err-insufficient-privileges (err u1007))
(define-constant err-achievement-inactive (err u1008))
(define-constant err-reward-calculation-failed (err u1009))
(define-constant err-player-progress-not-found (err u1010))

;; Achievement status codes
(define-constant achievement-status-active u1)
(define-constant achievement-status-inactive u0)

;; Achievement categories
(define-constant category-combat u1)
(define-constant category-exploration u2)
(define-constant category-crafting u3)
(define-constant category-social u4)
(define-constant category-special u5)

;; Minimum and maximum values
(define-constant min-reward-amount u1)
(define-constant max-reward-amount u1000000000) ;; 1000 GTK max reward
(define-constant max-description-length u256)

;; data vars
(define-data-var contract-owner principal tx-sender)
(define-data-var total-achievements uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var achievement-counter uint u0)
(define-data-var emergency-pause bool false)

;; data maps
;; Achievement definitions with comprehensive metadata
(define-map achievements
  { achievement-id: (string-ascii 64) }
  {
    title: (string-ascii 128),
    description: (string-ascii 256),
    category: uint,
    reward-amount: uint,
    difficulty-level: uint,
    is-active: bool,
    created-at: uint,
    created-by: principal,
    completion-count: uint,
    max-completions: (optional uint)
  }
)

;; Individual player progress for each achievement
(define-map player-achievements
  { player: principal, achievement-id: (string-ascii 64) }
  {
    progress: uint,
    completed-at: (optional uint),
    is-completed: bool,
    attempts: uint,
    last-updated: uint
  }
)

;; Player reward balances and statistics
(define-map player-rewards
  { player: principal }
  {
    total-earned: uint,
    total-claimed: uint,
    pending-rewards: uint,
    achievements-completed: uint,
    last-claim-time: uint,
    join-date: uint
  }
)

;; Achievement leaderboard entries
(define-map achievement-leaderboard
  { achievement-id: (string-ascii 64), rank: uint }
  {
    player: principal,
    completion-time: uint,
    score: uint
  }
)

;; Admin permissions for multi-admin support
(define-map admin-permissions
  { admin: principal }
  {
    can-create-achievements: bool,
    can-modify-achievements: bool,
    can-pause-contract: bool,
    added-by: principal,
    added-at: uint
  }
)

;; public functions

;; Administrative function to add a new achievement
(define-public (add-achievement 
    (achievement-id (string-ascii 64))
    (title (string-ascii 128))
    (description (string-ascii 256))
    (category uint)
    (reward-amount uint)
    (difficulty-level uint)
    (max-completions (optional uint))
  )
  (begin
    (asserts! (is-admin-or-owner tx-sender) err-insufficient-privileges)
    (asserts! (not (var-get emergency-pause)) err-achievement-inactive)
    (asserts! (is-none (map-get? achievements { achievement-id: achievement-id })) err-achievement-already-exists)
    (asserts! (>= reward-amount min-reward-amount) err-invalid-achievement-data)
    (asserts! (<= reward-amount max-reward-amount) err-invalid-achievement-data)
    (asserts! (<= (len description) max-description-length) err-invalid-achievement-data)
    (asserts! (and (>= category u1) (<= category u5)) err-invalid-achievement-data)
    (asserts! (and (>= difficulty-level u1) (<= difficulty-level u10)) err-invalid-achievement-data)
    
    (map-set achievements
      { achievement-id: achievement-id }
      {
        title: title,
        description: description,
        category: category,
        reward-amount: reward-amount,
        difficulty-level: difficulty-level,
        is-active: true,
        created-at: block-height,
        created-by: tx-sender,
        completion-count: u0,
        max-completions: max-completions
      }
    )
    
    (var-set total-achievements (+ (var-get total-achievements) u1))
    (var-set achievement-counter (+ (var-get achievement-counter) u1))
    (ok true)
  )
)

;; Update an existing achievement (admin only)
(define-public (update-achievement
    (achievement-id (string-ascii 64))
    (title (string-ascii 128))
    (description (string-ascii 256))
    (reward-amount uint)
    (is-active bool)
  )
  (let (
    (achievement (unwrap! (map-get? achievements { achievement-id: achievement-id }) err-achievement-not-found))
  )
    (asserts! (is-admin-or-owner tx-sender) err-insufficient-privileges)
    (asserts! (>= reward-amount min-reward-amount) err-invalid-achievement-data)
    (asserts! (<= reward-amount max-reward-amount) err-invalid-achievement-data)
    (asserts! (<= (len description) max-description-length) err-invalid-achievement-data)
    
    (map-set achievements
      { achievement-id: achievement-id }
      (merge achievement {
        title: title,
        description: description,
        reward-amount: reward-amount,
        is-active: is-active
      })
    )
    (ok true)
  )
)

;; Player completes an achievement
(define-public (complete-achievement 
    (achievement-id (string-ascii 64))
    (player principal)
    (score uint)
  )
  (let (
    (achievement (unwrap! (map-get? achievements { achievement-id: achievement-id }) err-achievement-not-found))
    (player-progress (default-to 
      { progress: u0, completed-at: none, is-completed: false, attempts: u0, last-updated: u0 }
      (map-get? player-achievements { player: player, achievement-id: achievement-id })
    ))
    (player-reward-info (default-to
      { total-earned: u0, total-claimed: u0, pending-rewards: u0, achievements-completed: u0, last-claim-time: u0, join-date: block-height }
      (map-get? player-rewards { player: player })
    ))
  )
    (asserts! (not (var-get emergency-pause)) err-achievement-inactive)
    (asserts! (get is-active achievement) err-achievement-inactive)
    (asserts! (not (get is-completed player-progress)) err-achievement-already-completed)
    
    ;; Check max completions limit
    (asserts! (match (get max-completions achievement)
      max-comp (< (get completion-count achievement) max-comp)
      true
    ) err-player-not-eligible)
    
    ;; Update player achievement progress
    (map-set player-achievements
      { player: player, achievement-id: achievement-id }
      {
        progress: u100,
        completed-at: (some block-height),
        is-completed: true,
        attempts: (+ (get attempts player-progress) u1),
        last-updated: block-height
      }
    )
    
    ;; Update player rewards
    (map-set player-rewards
      { player: player }
      {
        total-earned: (+ (get total-earned player-reward-info) (get reward-amount achievement)),
        total-claimed: (get total-claimed player-reward-info),
        pending-rewards: (+ (get pending-rewards player-reward-info) (get reward-amount achievement)),
        achievements-completed: (+ (get achievements-completed player-reward-info) u1),
        last-claim-time: (get last-claim-time player-reward-info),
        join-date: (get join-date player-reward-info)
      }
    )
    
    ;; Update achievement completion count
    (map-set achievements
      { achievement-id: achievement-id }
      (merge achievement { completion-count: (+ (get completion-count achievement) u1) })
    )
    
    ;; Update leaderboard (top 10 entries)
    (update-leaderboard achievement-id player score)
    
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) (get reward-amount achievement)))
    (ok true)
  )
)

;; Player claims pending rewards
(define-public (claim-rewards (player principal))
  (let (
    (player-reward-info (unwrap! (map-get? player-rewards { player: player }) err-no-rewards-to-claim))
    (pending (get pending-rewards player-reward-info))
  )
    (asserts! (not (var-get emergency-pause)) err-achievement-inactive)
    (asserts! (> pending u0) err-no-rewards-to-claim)
    
    ;; Update player reward balance
    (map-set player-rewards
      { player: player }
      (merge player-reward-info {
        total-claimed: (+ (get total-claimed player-reward-info) pending),
        pending-rewards: u0,
        last-claim-time: block-height
      })
    )
    
    ;; Note: In a real implementation, this would mint/transfer tokens
    ;; For this standalone contract, we just track the claim
    (ok pending)
  )
)

;; Administrative functions
(define-public (pause-contract)
  (begin
    (asserts! (is-admin-or-owner tx-sender) err-insufficient-privileges)
    (var-set emergency-pause true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-admin-or-owner tx-sender) err-insufficient-privileges)
    (var-set emergency-pause false)
    (ok true)
  )
)

(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    (map-set admin-permissions
      { admin: new-admin }
      {
        can-create-achievements: true,
        can-modify-achievements: true,
        can-pause-contract: false,
        added-by: tx-sender,
        added-at: block-height
      }
    )
    (ok true)
  )
)

;; read only functions

(define-read-only (get-achievement (achievement-id (string-ascii 64)))
  (map-get? achievements { achievement-id: achievement-id })
)

(define-read-only (get-player-progress (player principal) (achievement-id (string-ascii 64)))
  (map-get? player-achievements { player: player, achievement-id: achievement-id })
)

(define-read-only (get-player-rewards (player principal))
  (map-get? player-rewards { player: player })
)

(define-read-only (get-contract-stats)
  {
    total-achievements: (var-get total-achievements),
    total-rewards-distributed: (var-get total-rewards-distributed),
    contract-owner: (var-get contract-owner),
    emergency-pause: (var-get emergency-pause)
  }
)

(define-read-only (get-achievement-leaderboard (achievement-id (string-ascii 64)) (rank uint))
  (map-get? achievement-leaderboard { achievement-id: achievement-id, rank: rank })
)

(define-read-only (is-achievement-completed (player principal) (achievement-id (string-ascii 64)))
  (match (map-get? player-achievements { player: player, achievement-id: achievement-id })
    progress (get is-completed progress)
    false
  )
)

(define-read-only (get-pending-rewards (player principal))
  (match (map-get? player-rewards { player: player })
    rewards (get pending-rewards rewards)
    u0
  )
)

(define-read-only (is-admin (address principal))
  (match (map-get? admin-permissions { admin: address })
    perms true
    false
  )
)

;; private functions

(define-private (is-admin-or-owner (address principal))
  (or 
    (is-eq address (var-get contract-owner))
    (is-admin address)
  )
)

(define-private (update-leaderboard (achievement-id (string-ascii 64)) (player principal) (score uint))
  ;; Simple leaderboard update - in production this would be more sophisticated
  (map-set achievement-leaderboard
    { achievement-id: achievement-id, rank: u1 }
    {
      player: player,
      completion-time: block-height,
      score: score
    }
  )
)
