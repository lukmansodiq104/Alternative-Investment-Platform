;; Alternative Investment Platform - Asset Management Contract
;; Manages asset registration, metadata, and valuation tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ASSET-NOT-FOUND (err u101))
(define-constant ERR-INVALID-INPUT (err u102))
(define-constant ERR-ASSET-EXISTS (err u103))

;; Data Variables
(define-data-var next-asset-id uint u1)

;; Data Maps
(define-map assets
  { asset-id: uint }
  {
    asset-type: (string-ascii 50),
    description: (string-ascii 500),
    current-value: uint,
    owner: principal,
    authenticated: bool,
    created-at: uint,
    last-updated: uint
  }
)

(define-map asset-valuations
  { asset-id: uint, valuation-id: uint }
  {
    value: uint,
    appraiser: principal,
    timestamp: uint,
    notes: (string-ascii 200)
  }
)

(define-map asset-valuation-count
  { asset-id: uint }
  { count: uint }
)

(define-map authorized-appraisers
  { appraiser: principal }
  { authorized: bool, specialty: (string-ascii 100) }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-asset-owner (asset-id uint))
  (match (map-get? assets { asset-id: asset-id })
    asset (is-eq tx-sender (get owner asset))
    false
  )
)

(define-private (is-authorized-appraiser)
  (match (map-get? authorized-appraisers { appraiser: tx-sender })
    appraiser-data (get authorized appraiser-data)
    false
  )
)

;; Public Functions

;; Register a new asset
(define-public (register-asset (asset-type (string-ascii 50)) (description (string-ascii 500)) (initial-value uint))
  (let ((asset-id (var-get next-asset-id)))
    (asserts! (> (len asset-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> initial-value u0) ERR-INVALID-INPUT)

    (map-set assets
      { asset-id: asset-id }
      {
        asset-type: asset-type,
        description: description,
        current-value: initial-value,
        owner: tx-sender,
        authenticated: false,
        created-at: block-height,
        last-updated: block-height
      }
    )

    (map-set asset-valuation-count { asset-id: asset-id } { count: u0 })
    (var-set next-asset-id (+ asset-id u1))
    (ok asset-id)
  )
)

;; Update asset valuation
(define-public (update-valuation (asset-id uint) (new-value uint) (notes (string-ascii 200)))
  (let ((asset (unwrap! (map-get? assets { asset-id: asset-id }) ERR-ASSET-NOT-FOUND))
        (valuation-count (default-to { count: u0 } (map-get? asset-valuation-count { asset-id: asset-id }))))

    (asserts! (or (is-contract-owner) (is-asset-owner asset-id) (is-authorized-appraiser)) ERR-NOT-AUTHORIZED)
    (asserts! (> new-value u0) ERR-INVALID-INPUT)

    ;; Add valuation record
    (map-set asset-valuations
      { asset-id: asset-id, valuation-id: (get count valuation-count) }
      {
        value: new-value,
        appraiser: tx-sender,
        timestamp: block-height,
        notes: notes
      }
    )

    ;; Update asset current value
    (map-set assets
      { asset-id: asset-id }
      (merge asset { current-value: new-value, last-updated: block-height })
    )

    ;; Increment valuation count
    (map-set asset-valuation-count
      { asset-id: asset-id }
      { count: (+ (get count valuation-count) u1) }
    )

    (ok true)
  )
)

;; Set authentication status
(define-public (set-authentication-status (asset-id uint) (authenticated bool))
  (let ((asset (unwrap! (map-get? assets { asset-id: asset-id }) ERR-ASSET-NOT-FOUND)))
    (asserts! (or (is-contract-owner) (is-authorized-appraiser)) ERR-NOT-AUTHORIZED)

    (map-set assets
      { asset-id: asset-id }
      (merge asset { authenticated: authenticated, last-updated: block-height })
    )
    (ok true)
  )
)

;; Authorize appraiser
(define-public (authorize-appraiser (appraiser principal) (specialty (string-ascii 100)))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> (len specialty) u0) ERR-INVALID-INPUT)

    (map-set authorized-appraisers
      { appraiser: appraiser }
      { authorized: true, specialty: specialty }
    )
    (ok true)
  )
)

;; Revoke appraiser authorization
(define-public (revoke-appraiser (appraiser principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)

    (map-set authorized-appraisers
      { appraiser: appraiser }
      { authorized: false, specialty: "" }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get asset details
(define-read-only (get-asset (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

;; Get asset valuation history
(define-read-only (get-valuation (asset-id uint) (valuation-id uint))
  (map-get? asset-valuations { asset-id: asset-id, valuation-id: valuation-id })
)

;; Get total valuations for asset
(define-read-only (get-valuation-count (asset-id uint))
  (default-to { count: u0 } (map-get? asset-valuation-count { asset-id: asset-id }))
)

;; Check if appraiser is authorized
(define-read-only (is-appraiser-authorized (appraiser principal))
  (match (map-get? authorized-appraisers { appraiser: appraiser })
    appraiser-data (get authorized appraiser-data)
    false
  )
)

;; Get next asset ID
(define-read-only (get-next-asset-id)
  (var-get next-asset-id)
)
