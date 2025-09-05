;; Simplified Peak Harvest DAO Governance Platform
;; Streamlined version with reduced complexity and error potential

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SEASON (err u101))
(define-constant ERR-MEMBER-NOT-FOUND (err u102))
(define-constant ERR-INVALID-CONTRIBUTION (err u103))
(define-constant ERR-INVALID-POD (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var current-season uint u1)
(define-data-var total-members uint u0)
(define-data-var base-reward uint u100)
(define-data-var governance-active bool true)

;; Constants
(define-constant SEASON-SPRING u1)
(define-constant SEASON-SUMMER u2)
(define-constant SEASON-AUTUMN u3)
(define-constant SEASON-WINTER u4)

(define-constant POD-STRATEGIC u1)
(define-constant POD-OPERATIONAL u2)
(define-constant POD-URGENT u3)

;; Simplified Member Structure
(define-map members 
  principal 
  {
    reputation-score: uint,
    total-contributions: uint,
    last-active-season: uint,
    is-active: bool
  }
)

;; Simplified Contribution Tracking
(define-map contributions
  {member: principal, season: uint, contribution-id: uint}
  {
    pod-type: uint,
    impact-rating: uint,
    block-height: uint,
    validated: bool
  }
)

;; Simple Pod Tracking
(define-map pods
  uint
  {
    pod-type: uint,
    active-proposals: uint,
    total-participation: uint
  }
)

;; Season Metrics
(define-map season-stats
  uint
  {
    total-activity: uint,
    member-count: uint,
    rewards-distributed: uint
  }
)

;; Simple counter for contribution IDs
(define-data-var next-contribution-id uint u1)

;; Initialize Contract
(define-private (initialize-pods)
  (begin
    (map-set pods POD-STRATEGIC {
      pod-type: POD-STRATEGIC,
      active-proposals: u0,
      total-participation: u0
    })
    (map-set pods POD-OPERATIONAL {
      pod-type: POD-OPERATIONAL,
      active-proposals: u0,
      total-participation: u0
    })
    (map-set pods POD-URGENT {
      pod-type: POD-URGENT,
      active-proposals: u0,
      total-participation: u0
    })
    (ok true)
  )
)

;; Owner Functions
(define-public (set-base-reward (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set base-reward new-reward)
    (ok true)
  )
)

(define-public (advance-season)
  (let ((current (var-get current-season)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set current-season 
      (if (is-eq current u4) u1 (+ current u1)))
    (ok true)
  )
)

(define-public (set-governance-active (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set governance-active active)
    (ok true)
  )
)

;; Member Functions
(define-public (register-member)
  (let ((member tx-sender))
    (asserts! (var-get governance-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? members member)) ERR-ALREADY-EXISTS)
    
    (map-set members member {
      reputation-score: u100,
      total-contributions: u0,
      last-active-season: (var-get current-season),
      is-active: true
    })
    (var-set total-members (+ (var-get total-members) u1))
    (ok true)
  )
)

(define-public (submit-contribution (pod-type uint) (impact-rating uint))
  (let (
    (member tx-sender)
    (season (var-get current-season))
    (contribution-id (var-get next-contribution-id))
    (member-data (unwrap! (map-get? members member) ERR-MEMBER-NOT-FOUND))
  )
    (asserts! (var-get governance-active) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= pod-type u1) (<= pod-type u3)) ERR-INVALID-POD)
    (asserts! (and (>= impact-rating u1) (<= impact-rating u10)) ERR-INVALID-CONTRIBUTION)
    
    ;; Record contribution
    (map-set contributions {member: member, season: season, contribution-id: contribution-id} {
      pod-type: pod-type,
      impact-rating: impact-rating,
      block-height: block-height,
      validated: false
    })
    
    ;; Update member data
    (map-set members member (merge member-data {
      total-contributions: (+ (get total-contributions member-data) u1),
      last-active-season: season
    }))
    
    ;; Update pod participation
    (let ((pod-data (unwrap! (map-get? pods pod-type) ERR-INVALID-POD)))
      (map-set pods pod-type (merge pod-data {
        total-participation: (+ (get total-participation pod-data) u1)
      }))
    )
    
    ;; Increment contribution counter
    (var-set next-contribution-id (+ contribution-id u1))
    (ok contribution-id)
  )
)

(define-public (validate-contribution (member principal) (season uint) (contribution-id uint))
  (let (
    (validator tx-sender)
    (contribution-key {member: member, season: season, contribution-id: contribution-id})
    (contribution-data (unwrap! (map-get? contributions contribution-key) ERR-MEMBER-NOT-FOUND))
  )
    (asserts! (var-get governance-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? members validator)) ERR-MEMBER-NOT-FOUND)
    (asserts! (not (is-eq validator member)) ERR-NOT-AUTHORIZED) ;; Can't validate own contribution
    
    ;; Mark as validated
    (map-set contributions contribution-key (merge contribution-data {
      validated: true
    }))
    
    ;; Update validator's reputation
    (let ((validator-data (unwrap! (map-get? members validator) ERR-MEMBER-NOT-FOUND)))
      (map-set members validator (merge validator-data {
        reputation-score: (+ (get reputation-score validator-data) u5)
      }))
    )
    
    (ok true)
  )
)

(define-public (distribute-season-rewards)
  (let ((season (var-get current-season)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Update season stats
    (map-set season-stats season {
      total-activity: (get-season-activity season),
      member-count: (var-get total-members),
      rewards-distributed: (* (var-get base-reward) (var-get total-members))
    })
    (ok true)
  )
)

;; Helper Functions
(define-private (get-season-activity (season uint))
  ;; Simple activity calculation - returns a placeholder value
  ;; In a real implementation, this would count actual contributions for the season
  u10
)

;; Read-Only Functions
(define-read-only (get-member-info (member principal))
  (map-get? members member)
)

(define-read-only (get-contribution (member principal) (season uint) (contribution-id uint))
  (map-get? contributions {member: member, season: season, contribution-id: contribution-id})
)

(define-read-only (get-pod-info (pod-type uint))
  (map-get? pods pod-type)
)

(define-read-only (get-season-stats (season uint))
  (map-get? season-stats season)
)

(define-read-only (get-current-season)
  (var-get current-season)
)

(define-read-only (get-governance-status)
  (var-get governance-active)
)

(define-read-only (get-contract-stats)
  {
    current-season: (var-get current-season),
    total-members: (var-get total-members),
    base-reward: (var-get base-reward),
    governance-active: (var-get governance-active),
    next-contribution-id: (var-get next-contribution-id)
  }
)

(define-read-only (get-member-contributions (member principal) (season uint))
  ;; Returns basic info about member's contributions for a season
  {
    member: member,
    season: season,
    total-contributions: (default-to u0 
      (get total-contributions (map-get? members member)))
  }
)

;; Initialize contract on deployment
(initialize-pods)