;; testnet-database-core.clar
;; This contract serves as a secure, decentralized database management system 
;; for tracking and storing sensitive testnet information with role-based access control.

;; ========== Error Constants ==========
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-RECORD-ALREADY-EXISTS (err u101))
(define-constant ERR-RECORD-NOT-FOUND (err u102))
(define-constant ERR-DATABASE-LIMIT-REACHED (err u103))
(define-constant ERR-INVALID-ACCESS-TIER (err u104))
(define-constant ERR-RECORD-UPDATE-FAILED (err u105))
(define-constant ERR-ACCESS-TIER-NOT-FOUND (err u106))
(define-constant ERR-INVALID-PARAMETERS (err u109))

;; ========== Data Maps and Variables ==========

;; Access tier definitions for role-based access control
(define-map access-tiers
  { tier-id: uint }
  {
    name: (string-utf8 50),
    read-access: bool,
    write-access: bool,
    delete-access: bool
  }
)

;; Database records storage
(define-map database-records
  { record-id: uint }
  {
    data: (string-utf8 500),
    creator: principal,
    created-at: uint,
    access-tier: uint,
    last-updated: (optional uint)
  }
)

;; Record counter for generating unique record IDs
(define-data-var record-counter uint u0)

;; Access tier counter
(define-data-var tier-counter uint u0)

;; ========== Private Functions ==========

;; Check if the sender has appropriate access for a given tier
(define-private (has-access-for-tier (tier-id uint) (access-type (string-ascii 10)))
  (match (map-get? access-tiers { tier-id: tier-id })
    tier-info 
      (if (is-eq access-type "read")
          (get read-access tier-info)
          (if (is-eq access-type "write")
              (get write-access tier-info)
              (if (is-eq access-type "delete")
                  (get delete-access tier-info)
                  false
              )
          )
      )
    false
  )
)

;; ========== Read-Only Functions ==========

;; Get details of a specific record
(define-read-only (get-record (record-id uint))
  (map-get? database-records { record-id: record-id })
)

;; Get details of an access tier
(define-read-only (get-access-tier (tier-id uint))
  (map-get? access-tiers { tier-id: tier-id })
)

;; ========== Public Functions ==========

;; Create a new access tier
(define-public (create-access-tier 
  (name (string-utf8 50)) 
  (read-access bool) 
  (write-access bool) 
  (delete-access bool)
)
  (let
    (
      (sender tx-sender)
      (new-tier-id (+ (var-get tier-counter) u1))
    )
    ;; Validate parameters
    (asserts! (> (len name) u0) ERR-INVALID-PARAMETERS)
    
    ;; Increment tier counter
    (var-set tier-counter new-tier-id)
    
    ;; Create the access tier
    (map-set access-tiers
      { tier-id: new-tier-id }
      {
        name: name,
        read-access: read-access,
        write-access: write-access,
        delete-access: delete-access
      }
    )
    (ok new-tier-id)
  )
)

;; Add a new record to the database
(define-public (add-record 
  (data (string-utf8 500)) 
  (access-tier uint)
)
  (let
    (
      (sender tx-sender)
      (new-record-id (+ (var-get record-counter) u1))
    )
    ;; Verify access tier exists and sender has write access
    (asserts! (is-some (map-get? access-tiers { tier-id: access-tier })) ERR-ACCESS-TIER-NOT-FOUND)
    (asserts! (has-access-for-tier access-tier "write") ERR-NOT-AUTHORIZED)
    
    ;; Increment record counter
    (var-set record-counter new-record-id)
    
    ;; Create the record
    (map-set database-records
      { record-id: new-record-id }
      {
        data: data,
        creator: sender,
        created-at: block-height,
        access-tier: access-tier,
        last-updated: none
      }
    )
    (ok new-record-id)
  )
)

;; Update an existing record
(define-public (update-record 
  (record-id uint) 
  (new-data (string-utf8 500))
)
  (let
    (
      (sender tx-sender)
      (record-opt (map-get? database-records { record-id: record-id }))
    )
    ;; Verify record exists and sender is the creator
    (asserts! (is-some record-opt) ERR-RECORD-NOT-FOUND)
    (let
      ((record (unwrap! record-opt ERR-RECORD-NOT-FOUND)))
      
      ;; Verify sender has write access to the record's access tier
      (asserts! (has-access-for-tier (get access-tier record) "write") ERR-NOT-AUTHORIZED)
      (asserts! (is-eq sender (get creator record)) ERR-NOT-AUTHORIZED)
      
      ;; Update the record
      (map-set database-records
        { record-id: record-id }
        {
          data: new-data,
          creator: sender,
          created-at: (get created-at record),
          access-tier: (get access-tier record),
          last-updated: (some block-height)
        }
      )
      (ok true)
    )
  )
)

;; Delete a record
(define-public (delete-record (record-id uint))
  (let
    (
      (sender tx-sender)
      (record-opt (map-get? database-records { record-id: record-id }))
    )
    ;; Verify record exists
    (asserts! (is-some record-opt) ERR-RECORD-NOT-FOUND)
    (let
      ((record (unwrap! record-opt ERR-RECORD-NOT-FOUND)))
      
      ;; Verify sender has delete access to the record's access tier
      (asserts! (has-access-for-tier (get access-tier record) "delete") ERR-NOT-AUTHORIZED)
      (asserts! (is-eq sender (get creator record)) ERR-NOT-AUTHORIZED)
      
      ;; Delete the record
      (map-delete database-records { record-id: record-id })
      (ok true)
    )
  )
)