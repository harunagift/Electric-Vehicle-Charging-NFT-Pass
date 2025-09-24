

(define-non-fungible-token voltpass uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-not-found (err u102))
(define-constant err-invalid-station (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-already-minted (err u105))
(define-constant err-session-not-active (err u106))
(define-constant err-unauthorized-station (err u107))
(define-constant err-invalid-tier (err u108))
(define-constant err-invalid-referral (err u109))
(define-constant err-station-offline (err u110))
(define-constant err-invalid-maintenance (err u111))
(define-constant err-maintenance-active (err u112))

(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://api.voltpass.io/metadata/")

(define-map token-owners uint principal)
(define-map charging-passes uint {
    owner: principal,
    station-access: (list 20 uint),
    balance: uint,
    created-at: uint,
    expires-at: uint,
    active: bool
})

(define-map charging-stations uint {
    operator: principal,
    location: (string-ascii 100),
    rate-per-minute: uint,
    active: bool,
    total-sessions: uint
})

(define-map charging-sessions {pass-id: uint, session-id: uint} {
    station-id: uint,
    start-time: uint,
    end-time: (optional uint),
    energy-consumed: uint,
    cost: uint,
    active: bool
})

(define-map station-operators principal (list 10 uint))
(define-map pass-sessions uint (list 50 uint))

(define-map user-loyalty principal {
    total-sessions: uint,
    total-energy: uint,
    loyalty-points: uint,
    tier-level: uint,
    referral-count: uint,
    join-date: uint
})

(define-map pricing-rules uint {
    peak-start-hour: uint,
    peak-end-hour: uint,
    peak-multiplier: uint,
    off-peak-discount: uint,
    loyalty-discount-bronze: uint,
    loyalty-discount-silver: uint,
    loyalty-discount-gold: uint,
    active: bool
})

(define-map station-demand uint {
    current-sessions: uint,
    peak-sessions: uint,
    surge-multiplier: uint,
    last-updated: uint
})

(define-map station-status uint {
    state: uint,
    last-heartbeat: uint,
    total-uptime: uint,
    total-downtime: uint,
    reliability-score: uint,
    maintenance-count: uint
})

(define-map maintenance-records uint {
    station-id: uint,
    scheduled-start: uint,
    scheduled-end: uint,
    actual-start: (optional uint),
    actual-end: (optional uint),
    maintenance-type: (string-ascii 50),
    description: (string-ascii 200),
    operator: principal,
    completed: bool
})

(define-map station-maintenance-history uint (list 10 uint))
(define-map operator-incentives principal uint)

(define-data-var next-station-id uint u1)
(define-data-var next-session-id uint u1)
(define-data-var next-maintenance-id uint u1)
(define-data-var min-reliability-threshold uint u85)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (concat (var-get base-uri) (int-to-ascii token-id))))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? voltpass token-id))
)

(define-read-only (get-charging-pass (pass-id uint))
    (map-get? charging-passes pass-id)
)

(define-read-only (get-charging-station (station-id uint))
    (map-get? charging-stations station-id)
)

(define-read-only (get-session (pass-id uint) (session-id uint))
    (map-get? charging-sessions {pass-id: pass-id, session-id: session-id})
)

(define-read-only (get-station-sessions (station-id uint))
    (let ((station (unwrap! (map-get? charging-stations station-id) (err err-not-found))))
        (ok (get total-sessions station))
    )
)

(define-read-only (get-pass-balance (pass-id uint))
    (let ((pass (unwrap! (map-get? charging-passes pass-id) (err err-not-found))))
        (ok (get balance pass))
    )
)

(define-read-only (has-station-access (pass-id uint) (station-id uint))
    (let ((pass (unwrap! (map-get? charging-passes pass-id) (err err-not-found))))
        (ok (is-some (index-of (get station-access pass) station-id)))
    )
)

(define-read-only (get-user-loyalty (user principal))
    (map-get? user-loyalty user)
)

(define-read-only (get-loyalty-tier (user principal))
    (let ((loyalty (default-to {total-sessions: u0, total-energy: u0, loyalty-points: u0, tier-level: u0, referral-count: u0, join-date: u0} (map-get? user-loyalty user))))
        (ok (get tier-level loyalty))
    )
)

(define-read-only (get-station-status (station-id uint))
    (map-get? station-status station-id)
)

(define-read-only (get-maintenance-record (maintenance-id uint))
    (map-get? maintenance-records maintenance-id)
)

(define-read-only (get-station-maintenance-history (station-id uint))
    (map-get? station-maintenance-history station-id)
)

(define-read-only (get-operator-incentives (operator principal))
    (default-to u0 (map-get? operator-incentives operator))
)

(define-read-only (is-station-operational (station-id uint))
    (let ((status (default-to {state: u1, last-heartbeat: u0, total-uptime: u0, total-downtime: u0, reliability-score: u100, maintenance-count: u0} (map-get? station-status station-id))))
        (ok (is-eq (get state status) u1))
    )
)

(define-read-only (calculate-reliability (station-id uint))
    (let ((status (default-to {state: u1, last-heartbeat: u0, total-uptime: u0, total-downtime: u0, reliability-score: u100, maintenance-count: u0} (map-get? station-status station-id)))
          (total-time (+ (get total-uptime status) (get total-downtime status))))
        (if (is-eq total-time u0)
            (ok u100)
            (ok (/ (* (get total-uptime status) u100) total-time))
        )
    )
)

(define-read-only (get-dynamic-rate (station-id uint) (user principal))
    (let ((station (unwrap! (map-get? charging-stations station-id) (err err-invalid-station)))
          (base-rate (get rate-per-minute station))
          (loyalty (default-to {total-sessions: u0, total-energy: u0, loyalty-points: u0, tier-level: u0, referral-count: u0, join-date: u0} (map-get? user-loyalty user)))
          (rules (default-to {peak-start-hour: u8, peak-end-hour: u18, peak-multiplier: u150, off-peak-discount: u90, loyalty-discount-bronze: u95, loyalty-discount-silver: u90, loyalty-discount-gold: u85, active: true} (map-get? pricing-rules u1)))
          (demand (default-to {current-sessions: u0, peak-sessions: u5, surge-multiplier: u100, last-updated: u0} (map-get? station-demand station-id)))
          (current-hour (mod (/ stacks-block-height u144) u24))
          (is-peak (and (>= current-hour (get peak-start-hour rules)) (<= current-hour (get peak-end-hour rules))))
          (time-adjusted-rate (if is-peak (* base-rate (get peak-multiplier rules)) (* base-rate (get off-peak-discount rules))))
          (surge-adjusted-rate (* time-adjusted-rate (get surge-multiplier demand)))
          (tier-level (get tier-level loyalty))
          (loyalty-multiplier (if (is-eq tier-level u3) (get loyalty-discount-gold rules)
                             (if (is-eq tier-level u2) (get loyalty-discount-silver rules)
                             (if (is-eq tier-level u1) (get loyalty-discount-bronze rules) u100))))
          (final-rate (/ (* surge-adjusted-rate loyalty-multiplier) u10000)))
        (ok final-rate)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (is-eq sender (unwrap! (nft-get-owner? voltpass token-id) err-not-found)) err-not-token-owner)
        (try! (nft-transfer? voltpass token-id sender recipient))
        (map-set charging-passes token-id 
            (merge (unwrap! (map-get? charging-passes token-id) err-not-found)
                   {owner: recipient}))
        (ok true)
    )
)

(define-public (mint (recipient principal))
    (let ((token-id (+ (var-get last-token-id) u1)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (nft-mint? voltpass token-id recipient))
        (var-set last-token-id token-id)
        (map-set charging-passes token-id {
            owner: recipient,
            station-access: (list),
            balance: u0,
            created-at: stacks-block-height,
            expires-at: (+ stacks-block-height u52560),
            active: true
        })
        (map-set pass-sessions token-id (list))
        (map-set user-loyalty recipient {
            total-sessions: u0,
            total-energy: u0,
            loyalty-points: u100,
            tier-level: u0,
            referral-count: u0,
            join-date: stacks-block-height
        })
        (ok token-id)
    )
)

(define-public (register-station (operator principal) (location (string-ascii 100)) (rate uint))
    (let ((station-id (var-get next-station-id)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set charging-stations station-id {
            operator: operator,
            location: location,
            rate-per-minute: rate,
            active: true,
            total-sessions: u0
        })
        (let ((current-stations (default-to (list) (map-get? station-operators operator))))
            (map-set station-operators operator (unwrap! (as-max-len? (append current-stations station-id) u10) err-invalid-station))
        )
        (map-set station-demand station-id {
            current-sessions: u0,
            peak-sessions: u5,
            surge-multiplier: u100,
            last-updated: stacks-block-height
        })
        (map-set station-status station-id {
            state: u1,
            last-heartbeat: stacks-block-height,
            total-uptime: u0,
            total-downtime: u0,
            reliability-score: u100,
            maintenance-count: u0
        })
        (map-set station-maintenance-history station-id (list))
        (var-set next-station-id (+ station-id u1))
        (ok station-id)
    )
)

(define-public (set-pricing-rules (peak-start uint) (peak-end uint) (peak-mult uint) (off-peak-disc uint) (bronze-disc uint) (silver-disc uint) (gold-disc uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= peak-start u23) err-invalid-tier)
        (asserts! (<= peak-end u23) err-invalid-tier)
        (map-set pricing-rules u1 {
            peak-start-hour: peak-start,
            peak-end-hour: peak-end,
            peak-multiplier: peak-mult,
            off-peak-discount: off-peak-disc,
            loyalty-discount-bronze: bronze-disc,
            loyalty-discount-silver: silver-disc,
            loyalty-discount-gold: gold-disc,
            active: true
        })
        (ok true)
    )
)

(define-public (refer-user (referrer-pass-id uint) (new-user principal))
    (let ((pass (unwrap! (map-get? charging-passes referrer-pass-id) err-not-found))
          (referrer (get owner pass))
          (referrer-loyalty (default-to {total-sessions: u0, total-energy: u0, loyalty-points: u0, tier-level: u0, referral-count: u0, join-date: u0} (map-get? user-loyalty referrer)))
          (existing-user (map-get? user-loyalty new-user)))
        (asserts! (is-none existing-user) err-already-minted)
        (asserts! (is-eq tx-sender referrer) err-not-token-owner)
        (map-set user-loyalty referrer {
            total-sessions: (get total-sessions referrer-loyalty),
            total-energy: (get total-energy referrer-loyalty),
            loyalty-points: (+ (get loyalty-points referrer-loyalty) u200),
            tier-level: (get tier-level referrer-loyalty),
            referral-count: (+ (get referral-count referrer-loyalty) u1),
            join-date: (get join-date referrer-loyalty)
        })
        (map-set user-loyalty new-user {
            total-sessions: u0,
            total-energy: u0,
            loyalty-points: u150,
            tier-level: u0,
            referral-count: u0,
            join-date: stacks-block-height
        })
        (ok true)
    )
)

(define-public (add-funds (pass-id uint) (amount uint))
    (let ((pass (unwrap! (map-get? charging-passes pass-id) err-not-found))
          (current-balance (get balance pass)))
        (asserts! (is-eq tx-sender (get owner pass)) err-not-token-owner)
        (asserts! (get active pass) err-not-found)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set charging-passes pass-id 
            (merge pass {balance: (+ current-balance amount)}))
        (ok true)
    )
)

(define-public (grant-station-access (pass-id uint) (station-id uint))
    (let ((pass (unwrap! (map-get? charging-passes pass-id) err-not-found))
          (station (unwrap! (map-get? charging-stations station-id) err-invalid-station))
          (current-access (get station-access pass)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (get active station) err-invalid-station)
        (asserts! (is-none (index-of current-access station-id)) err-already-minted)
        (map-set charging-passes pass-id 
            (merge pass {station-access: (unwrap! (as-max-len? (append current-access station-id) u20) err-invalid-station)}))
        (ok true)
    )
)

(define-public (start-charging-session (pass-id uint) (station-id uint))
    (let ((pass (unwrap! (map-get? charging-passes pass-id) err-not-found))
          (station (unwrap! (map-get? charging-stations station-id) err-invalid-station))
          (session-id (var-get next-session-id))
          (current-sessions (default-to (list) (map-get? pass-sessions pass-id)))
          (demand (default-to {current-sessions: u0, peak-sessions: u5, surge-multiplier: u100, last-updated: u0} (map-get? station-demand station-id)))
          (new-current-sessions (+ (get current-sessions demand) u1))
          (surge-mult (if (> new-current-sessions (get peak-sessions demand)) u130 u100)))
        (asserts! (is-eq tx-sender (get owner pass)) err-not-token-owner)
        (asserts! (get active pass) err-not-found)
        (asserts! (get active station) err-invalid-station)
        (asserts! (unwrap! (is-station-operational station-id) err-invalid-station) err-station-offline)
        (asserts! (is-some (index-of (get station-access pass) station-id)) err-unauthorized-station)
        (asserts! (> (get balance pass) u0) err-insufficient-funds)
        
        (map-set charging-sessions {pass-id: pass-id, session-id: session-id} {
            station-id: station-id,
            start-time: stacks-block-height,
            end-time: none,
            energy-consumed: u0,
            cost: u0,
            active: true
        })
        
        (map-set station-demand station-id {
            current-sessions: new-current-sessions,
            peak-sessions: (get peak-sessions demand),
            surge-multiplier: surge-mult,
            last-updated: stacks-block-height
        })
        
        (map-set pass-sessions pass-id (unwrap! (as-max-len? (append current-sessions session-id) u50) err-session-not-active))
        (var-set next-session-id (+ session-id u1))
        (ok session-id)
    )
)

(define-public (end-charging-session (pass-id uint) (session-id uint) (energy-consumed uint))
    (let ((session-key {pass-id: pass-id, session-id: session-id})
          (session (unwrap! (map-get? charging-sessions session-key) err-not-found))
          (pass (unwrap! (map-get? charging-passes pass-id) err-not-found))
          (station (unwrap! (map-get? charging-stations (get station-id session)) err-invalid-station))
          (user (get owner pass))
          (dynamic-rate (unwrap! (get-dynamic-rate (get station-id session) user) err-invalid-station))
          (duration (- stacks-block-height (get start-time session)))
          (cost (* duration dynamic-rate))
          (new-balance (- (get balance pass) cost))
          (loyalty (default-to {total-sessions: u0, total-energy: u0, loyalty-points: u0, tier-level: u0, referral-count: u0, join-date: u0} (map-get? user-loyalty user)))
          (points-earned (+ u10 (/ energy-consumed u100)))
          (new-points (+ (get loyalty-points loyalty) points-earned))
          (new-total-sessions (+ (get total-sessions loyalty) u1))
          (new-total-energy (+ (get total-energy loyalty) energy-consumed))
          (new-tier (if (>= new-total-energy u10000) u3
                   (if (>= new-total-energy u5000) u2
                   (if (>= new-total-energy u1000) u1 u0))))
          (demand (default-to {current-sessions: u0, peak-sessions: u5, surge-multiplier: u100, last-updated: u0} (map-get? station-demand (get station-id session))))
          (new-demand-sessions (if (> (get current-sessions demand) u0) (- (get current-sessions demand) u1) u0)))
        
        (asserts! (get active session) err-session-not-active)
        (asserts! (or (is-eq tx-sender (get owner pass)) (is-eq tx-sender (get operator station))) err-not-token-owner)
        (asserts! (>= (get balance pass) cost) err-insufficient-funds)
        
        (map-set charging-sessions session-key 
            (merge session {
                end-time: (some stacks-block-height),
                energy-consumed: energy-consumed,
                cost: cost,
                active: false
            }))
        
        (map-set charging-passes pass-id 
            (merge pass {balance: new-balance}))
        
        (map-set charging-stations (get station-id session)
            (merge station {total-sessions: (+ (get total-sessions station) u1)}))
        
        (map-set user-loyalty user {
            total-sessions: new-total-sessions,
            total-energy: new-total-energy,
            loyalty-points: new-points,
            tier-level: new-tier,
            referral-count: (get referral-count loyalty),
            join-date: (get join-date loyalty)
        })
        
        (map-set station-demand (get station-id session) {
            current-sessions: new-demand-sessions,
            peak-sessions: (get peak-sessions demand),
            surge-multiplier: (if (<= new-demand-sessions (get peak-sessions demand)) u100 (get surge-multiplier demand)),
            last-updated: stacks-block-height
        })
        
        (let ((heartbeat-result (heartbeat-station (get station-id session))))
            (try! (as-contract (stx-transfer? cost tx-sender (get operator station)))))
        (ok cost)
    )
)

(define-public (deactivate-pass (pass-id uint))
    (let ((pass (unwrap! (map-get? charging-passes pass-id) err-not-found)))
        (asserts! (is-eq tx-sender (get owner pass)) err-not-token-owner)
        (map-set charging-passes pass-id (merge pass {active: false}))
        (ok true)
    )
)

(define-public (schedule-maintenance (station-id uint) (scheduled-start uint) (scheduled-end uint) (maintenance-type (string-ascii 50)) (description (string-ascii 200)))
    (let ((station (unwrap! (map-get? charging-stations station-id) err-invalid-station))
          (maintenance-id (var-get next-maintenance-id))
          (current-history (default-to (list) (map-get? station-maintenance-history station-id))))
        (asserts! (is-eq tx-sender (get operator station)) err-not-token-owner)
        (asserts! (> scheduled-end scheduled-start) err-invalid-maintenance)
        (asserts! (> scheduled-start stacks-block-height) err-invalid-maintenance)
        (map-set maintenance-records maintenance-id {
            station-id: station-id,
            scheduled-start: scheduled-start,
            scheduled-end: scheduled-end,
            actual-start: none,
            actual-end: none,
            maintenance-type: maintenance-type,
            description: description,
            operator: tx-sender,
            completed: false
        })
        (map-set station-maintenance-history station-id 
            (unwrap! (as-max-len? (append current-history maintenance-id) u10) err-invalid-maintenance))
        (var-set next-maintenance-id (+ maintenance-id u1))
        (ok maintenance-id)
    )
)

(define-public (start-maintenance (maintenance-id uint))
    (let ((maintenance (unwrap! (map-get? maintenance-records maintenance-id) err-not-found))
          (station-id (get station-id maintenance)))
        (asserts! (is-eq tx-sender (get operator maintenance)) err-not-token-owner)
        (asserts! (not (get completed maintenance)) err-maintenance-active)
        (asserts! (>= stacks-block-height (get scheduled-start maintenance)) err-invalid-maintenance)
        (try! (update-station-state station-id u2))
        (map-set maintenance-records maintenance-id 
            (merge maintenance {actual-start: (some stacks-block-height)}))
        (ok true)
    )
)

(define-public (complete-maintenance (maintenance-id uint))
    (let ((maintenance (unwrap! (map-get? maintenance-records maintenance-id) err-not-found))
          (station-id (get station-id maintenance))
          (status (default-to {state: u1, last-heartbeat: u0, total-uptime: u0, total-downtime: u0, reliability-score: u100, maintenance-count: u0} (map-get? station-status station-id)))
          (actual-start (unwrap! (get actual-start maintenance) err-invalid-maintenance))
          (downtime (- stacks-block-height actual-start)))
        (asserts! (is-eq tx-sender (get operator maintenance)) err-not-token-owner)
        (asserts! (is-some (get actual-start maintenance)) err-invalid-maintenance)
        (asserts! (not (get completed maintenance)) err-maintenance-active)
        (map-set maintenance-records maintenance-id 
            (merge maintenance {actual-end: (some stacks-block-height), completed: true}))
        (map-set station-status station-id 
            (merge status {
                state: u1,
                total-downtime: (+ (get total-downtime status) downtime),
                maintenance-count: (+ (get maintenance-count status) u1)
            }))
        (let ((reliability-result (update-reliability station-id)))
            (ok true))
    )
)

(define-public (update-station-state (station-id uint) (new-state uint))
    (let ((station (unwrap! (map-get? charging-stations station-id) err-invalid-station))
          (status (default-to {state: u1, last-heartbeat: u0, total-uptime: u0, total-downtime: u0, reliability-score: u100, maintenance-count: u0} (map-get? station-status station-id))))
        (asserts! (is-eq tx-sender (get operator station)) err-not-token-owner)
        (asserts! (or (is-eq new-state u1) (is-eq new-state u2) (is-eq new-state u3)) err-invalid-maintenance)
        (map-set station-status station-id (merge status {state: new-state}))
        (ok true)
    )
)

(define-private (heartbeat-station (station-id uint))
    (let ((status (default-to {state: u1, last-heartbeat: u0, total-uptime: u0, total-downtime: u0, reliability-score: u100, maintenance-count: u0} (map-get? station-status station-id)))
          (time-since-last (- stacks-block-height (get last-heartbeat status))))
        (map-set station-status station-id 
            (merge status {
                last-heartbeat: stacks-block-height,
                total-uptime: (+ (get total-uptime status) time-since-last)
            }))
        (ok true)
    )
)

(define-private (update-reliability (station-id uint))
    (let ((new-reliability (unwrap! (calculate-reliability station-id) err-invalid-station))
          (status (default-to {state: u1, last-heartbeat: u0, total-uptime: u0, total-downtime: u0, reliability-score: u100, maintenance-count: u0} (map-get? station-status station-id))))
        (map-set station-status station-id 
            (merge status {reliability-score: new-reliability}))
        (ok true)
    )
)

(define-public (claim-operator-incentive)
    (let ((stations (default-to (list) (map-get? station-operators tx-sender)))
          (total-incentive (fold calculate-station-incentive stations u0)))
        (asserts! (> total-incentive u0) err-insufficient-funds)
        (map-set operator-incentives tx-sender u0)
        (try! (as-contract (stx-transfer? total-incentive tx-sender tx-sender)))
        (ok total-incentive)
    )
)

(define-private (calculate-station-incentive (station-id uint) (acc uint))
    (let ((status (default-to {state: u1, last-heartbeat: u0, total-uptime: u0, total-downtime: u0, reliability-score: u100, maintenance-count: u0} (map-get? station-status station-id)))
          (reliability (get reliability-score status))
          (threshold (var-get min-reliability-threshold))
          (incentive-amount (if (>= reliability threshold) u10000 u0)))
        (+ acc incentive-amount)
    )
)

(define-public (set-reliability-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (and (>= new-threshold u50) (<= new-threshold u100)) err-invalid-maintenance)
        (var-set min-reliability-threshold new-threshold)
        (ok true)
    )
)

(define-public (set-base-uri (new-base-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set base-uri new-base-uri)
        (ok true)
    )
)
