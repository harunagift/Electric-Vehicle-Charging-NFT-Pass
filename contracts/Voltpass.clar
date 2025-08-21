

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

(define-data-var next-station-id uint u1)
(define-data-var next-session-id uint u1)

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
        (var-set next-station-id (+ station-id u1))
        (ok station-id)
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
          (current-sessions (default-to (list) (map-get? pass-sessions pass-id))))
        (asserts! (is-eq tx-sender (get owner pass)) err-not-token-owner)
        (asserts! (get active pass) err-not-found)
        (asserts! (get active station) err-invalid-station)
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
          (duration (- stacks-block-height (get start-time session)))
          (cost (* duration (get rate-per-minute station)))
          (new-balance (- (get balance pass) cost)))
        
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
        
        (try! (as-contract (stx-transfer? cost tx-sender (get operator station))))
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

(define-public (set-base-uri (new-base-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set base-uri new-base-uri)
        (ok true)
    )
)
