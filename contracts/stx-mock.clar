;; stx-mock.clar
;; A mock SIP-010 fungible token used for testing the bond contract.

(define-fungible-token stx-mock)

;; --- DATA MAPS AND CONSTANTS ---

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-TRANSFER-FAILED (err u1))

;; --- PUBLIC FUNCTIONS (SIP-010 Implementation) ---

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (ft-transfer? stx-mock amount sender recipient)
    )
)

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ft-mint? stx-mock amount recipient)
    )
)

;; --- READ-ONLY FUNCTIONS ---

(define-read-only (get-balance (owner principal))
    (ok (ft-get-balance stx-mock owner))
)

(define-read-only (get-name)
    (ok "Mock STX")
)

(define-read-only (get-symbol)
    (ok "MSTX")
)

(define-read-only (get-decimals)
    (ok u8)
)
