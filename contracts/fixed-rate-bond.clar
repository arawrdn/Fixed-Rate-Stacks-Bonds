;; fixed-rate-bond.clar
;; Implements a fixed-rate, fixed-term bond protocol.

(define-data-var bond-counter uint u0)
(define-map bonds uint {
    issuer: principal,
    principal-amount: uint,
    term-months: uint,
    annual-rate-bps: uint, ;; Rate in basis points (e.g., 500 for 5.00%)
    issue-date: uint,
    maturity-date: uint,
    is-redeemed: bool,
    buyer: principal
})

;; ERRORS
(define-constant ERR-INVALID-TERM (err u100))
(define-constant ERR-BOND-NOT-FOUND (err u101))
(define-constant ERR-NOT-ISSUER (err u102))
(define-constant ERR-ALREADY-REDEEMED (err u103))
(define-constant ERR-NOT-MATURED (err u104))
(define-constant ERR-INVALID-RATE (err u105))

;; --- PUBLIC FUNCTIONS ---

;; @desc Issues a new bond. Transfers principal from the issuer to the contract.
;; @param principal-amount The amount of STX/Token to be locked.
;; @param term-months The duration of the bond in months.
;; @param annual-rate-bps The annual interest rate in basis points (e.g., 500 for 5%).
(define-public (issue-bond (principal-amount uint) (term-months uint) (annual-rate-bps uint))
    (let (
        (current-block-height (get-block-info block-height))
        (issue-height (unwrap-panic current-block-height))
        (maturity-height (+ issue-height (* term-months u4320))) ;; Approx. 4320 blocks per month
        (next-id (+ (var-get bond-counter) u1))
    )
        (asserts! (> term-months u0) ERR-INVALID-TERM)
        (asserts! (> annual-rate-bps u0) ERR-INVALID-RATE)

        ;; NOTE: In a real scenario, this would involve transferring STX or an asset token
        ;; (ok (try! (stx-transfer? principal-amount tx-sender (as-contract contract-caller))))

        (map-set bonds next-id {
            issuer: tx-sender,
            principal-amount: principal-amount,
            term-months: term-months,
            annual-rate-bps: annual-rate-bps,
            issue-date: issue-height,
            maturity-date: maturity-height,
            is-redeemed: false,
            buyer: tx-sender ;; Initially set to issuer, until purchased
        })
        (var-set bond-counter next-id)
        (ok next-id)
    )
)

;; @desc Calculates the total return (principal + interest) upon maturity.
;; @param bond-id The ID of the bond.
;; @returns The total amount (principal + interest) due.
(define-read-only (calculate-total-return (bond-id uint))
    (match (map-get? bonds bond-id) bond-data
        (let (
            (principal (get principal-amount bond-data))
            (annual-rate (get annual-rate-bps bond-data))
            (term (get term-months bond-data))
            ;; Interest = Principal * (Rate/10000) * (Term/12)
            (interest-num (* principal (* annual-rate term)))
            (interest-den (* u10000 u12))
            (interest-amount (/ interest-num interest-den))
        )
            (ok (+ principal interest-amount))
        )
        (err ERR-BOND-NOT-FOUND)
    )
)

;; @desc Redeems the bond, transferring total return to the buyer.
;; @param bond-id The ID of the bond to redeem.
(define-public (redeem-bond (bond-id uint))
    (match (map-get? bonds bond-id) bond-data
        (begin
            (asserts! (is-eq tx-sender (get buyer bond-data)) (err u106)) ;; Not the buyer
            (asserts! (not (get is-redeemed bond-data)) ERR-ALREADY-REDEEMED)
            (asserts! (>= (get-block-info block-height) (get maturity-date bond-data)) ERR-NOT-MATURED)

            (let (
                (total-return (unwrap-panic (calculate-total-return bond-id)))
            )
                ;; NOTE: In a real scenario, this would transfer the tokens back
                ;; (ok (try! (stx-transfer? total-return (as-contract contract-caller) tx-sender)))

                (map-set bonds bond-id (merge bond-data {is-redeemed: true}))
                (ok total-return)
            )
        )
        (err ERR-BOND-NOT-FOUND)
    )
)

;; --- READ-ONLY FUNCTIONS ---

(define-read-only (get-bond-details (bond-id uint))
    (map-get? bonds bond-id)
)

(define-read-only (get-block-info-height)
    (ok (get-block-info block-height))
)
