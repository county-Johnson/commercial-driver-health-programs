;; Commercial Driver Wellness Management Contract
;; Handles health screenings, fitness coaching, medical certification, and lifestyle support

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-DRIVER (err u101))
(define-constant ERR-INVALID-SCREENING (err u102))
(define-constant ERR-INVALID-CERTIFICATION (err u103))
(define-constant MAX-DRIVERS u5000)
(define-constant HEALTH-SCORE-THRESHOLD u70)

(define-data-var driver-counter uint u0)
(define-data-var screening-counter uint u0)
(define-data-var total-drivers-enrolled uint u0)

(define-map drivers
  { driver-id: uint }
  {
    principal-addr: principal,
    name: (string-ascii 64),
    health-score: uint,
    certification-status: (string-ascii 16),
    last-screening: uint,
    enrollment-date: uint
  }
)

(define-map health-screenings
  { screening-id: uint }
  {
    driver-id: uint,
    blood-pressure: uint,
    heart-rate: uint,
    bmi: uint,
    screening-date: uint,
    status: (string-ascii 16)
  }
)

(define-map medical-certifications
  { cert-id: uint }
  {
    driver-id: uint,
    issue-date: uint,
    expiration-date: uint,
    physician: (string-ascii 64),
    restrictions: (string-ascii 128)
  }
)

(define-map fitness-programs
  { program-id: uint }
  {
    driver-id: uint,
    program-name: (string-ascii 64),
    start-date: uint,
    completion-date: (optional uint),
    status: (string-ascii 16)
  }
)

(define-map lifestyle-support
  { support-id: uint }
  {
    driver-id: uint,
    category: (string-ascii 32),
    resource-type: (string-ascii 32),
    created-at: uint
  }
)

(define-public (enroll-driver (name (string-ascii 64)))
  (let
    (
      (new-id (+ (var-get driver-counter) u1))
    )
    (asserts! (< new-id MAX-DRIVERS) ERR-INVALID-DRIVER)
    (map-set drivers
      { driver-id: new-id }
      {
        principal-addr: tx-sender,
        name: name,
        health-score: u50,
        certification-status: "pending",
        last-screening: burn-block-height,
        enrollment-date: burn-block-height
      }
    )
    (var-set driver-counter new-id)
    (var-set total-drivers-enrolled (+ (var-get total-drivers-enrolled) u1))
    (ok new-id)
  )
)

(define-public (record-health-screening
  (driver-id uint)
  (blood-pressure uint)
  (heart-rate uint)
  (bmi uint)
)
  (let
    (
      (driver (map-get? drivers { driver-id: driver-id }))
      (new-id (+ (var-get screening-counter) u1))
    )
    (match driver
      driver-data
      (begin
        (asserts! (and (>= blood-pressure u80) (<= blood-pressure u220)) ERR-INVALID-SCREENING)
        (asserts! (and (>= heart-rate u40) (<= heart-rate u120)) ERR-INVALID-SCREENING)
        (asserts! (and (>= bmi u15) (<= bmi u50)) ERR-INVALID-SCREENING)
        (map-set health-screenings
          { screening-id: new-id }
          {
            driver-id: driver-id,
            blood-pressure: blood-pressure,
            heart-rate: heart-rate,
            bmi: bmi,
            screening-date: burn-block-height,
            status: "completed"
          }
        )
        (let
          (
            (new-score (calculate-health-score blood-pressure heart-rate bmi))
          )
          (map-set drivers
            { driver-id: driver-id }
            (merge driver-data
              {
                health-score: new-score,
                last-screening: burn-block-height
              }
            )
          )
        )
        (var-set screening-counter new-id)
        (ok new-id)
      )
      ERR-INVALID-DRIVER
    )
  )
)

(define-public (issue-medical-certification
  (driver-id uint)
  (expiration-days uint)
  (physician (string-ascii 64))
  (restrictions (string-ascii 128))
)
  (let
    (
      (driver (map-get? drivers { driver-id: driver-id }))
      (cert-id (+ (var-get screening-counter) u1))
    )
    (match driver
      driver-data
      (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (>= (get health-score driver-data) HEALTH-SCORE-THRESHOLD) ERR-INVALID-CERTIFICATION)
        (map-set medical-certifications
          { cert-id: cert-id }
          {
            driver-id: driver-id,
            issue-date: burn-block-height,
            expiration-date: (+ burn-block-height expiration-days),
            physician: physician,
            restrictions: restrictions
          }
        )
        (map-set drivers
          { driver-id: driver-id }
          (merge driver-data { certification-status: "certified" })
        )
        (ok cert-id)
      )
      ERR-INVALID-DRIVER
    )
  )
)

(define-public (enroll-fitness-program
  (driver-id uint)
  (program-name (string-ascii 64))
)
  (let
    (
      (driver (map-get? drivers { driver-id: driver-id }))
      (program-id (+ (var-get screening-counter) u1))
    )
    (match driver
      driver-data
      (begin
        (asserts! (is-eq tx-sender (get principal-addr driver-data)) ERR-UNAUTHORIZED)
        (map-set fitness-programs
          { program-id: program-id }
          {
            driver-id: driver-id,
            program-name: program-name,
            start-date: burn-block-height,
            completion-date: none,
            status: "active"
          }
        )
        (ok program-id)
      )
      ERR-INVALID-DRIVER
    )
  )
)

(define-public (complete-fitness-program (program-id uint))
  (let
    (
      (program (map-get? fitness-programs { program-id: program-id }))
    )
    (match program
      program-data
      (begin
        (map-set fitness-programs
          { program-id: program-id }
          (merge program-data
            {
              completion-date: (some burn-block-height),
              status: "completed"
            }
          )
        )
        (ok true)
      )
      ERR-INVALID-SCREENING
    )
  )
)

(define-public (add-lifestyle-support
  (driver-id uint)
  (category (string-ascii 32))
  (resource-type (string-ascii 32))
)
  (let
    (
      (driver (map-get? drivers { driver-id: driver-id }))
      (support-id (+ (var-get screening-counter) u1))
    )
    (match driver
      driver-data
      (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map-set lifestyle-support
          { support-id: support-id }
          {
            driver-id: driver-id,
            category: category,
            resource-type: resource-type,
            created-at: burn-block-height
          }
        )
        (ok support-id)
      )
      ERR-INVALID-DRIVER
    )
  )
)

(define-public (update-driver-status (driver-id uint) (new-status (string-ascii 16)))
  (let
    (
      (driver (map-get? drivers { driver-id: driver-id }))
    )
    (match driver
      driver-data
      (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map-set drivers
          { driver-id: driver-id }
          (merge driver-data { certification-status: new-status })
        )
        (ok true)
      )
      ERR-INVALID-DRIVER
    )
  )
)

(define-private (calculate-health-score (bp uint) (hr uint) (bmi uint))
  (let
    (
      (bp-score (if (and (>= bp u120) (<= bp u140)) u25 (if (> bp u140) u20 u30)))
      (hr-score (if (and (>= hr u60) (<= hr u100)) u30 (if (or (< hr u60) (> hr u100)) u25 u30)))
      (bmi-score (if (and (>= bmi u18) (<= bmi u25)) u30 (if (and (>= bmi u25) (<= bmi u30)) u20 u15)))
    )
    (+ bp-score (+ hr-score bmi-score))
  )
)

(define-read-only (get-driver (driver-id uint))
  (map-get? drivers { driver-id: driver-id })
)

(define-read-only (get-screening (screening-id uint))
  (map-get? health-screenings { screening-id: screening-id })
)

(define-read-only (get-certification (cert-id uint))
  (map-get? medical-certifications { cert-id: cert-id })
)

(define-read-only (get-fitness-program (program-id uint))
  (map-get? fitness-programs { program-id: program-id })
)

(define-read-only (get-lifestyle-support (support-id uint))
  (map-get? lifestyle-support { support-id: support-id })
)

(define-read-only (get-total-enrolled)
  (var-get total-drivers-enrolled)
)

(define-read-only (is-certified (driver-id uint))
  (let
    (
      (driver (map-get? drivers { driver-id: driver-id }))
    )
    (match driver
      driver-data
      (is-eq (get certification-status driver-data) "certified")
      false
    )
  )
)

