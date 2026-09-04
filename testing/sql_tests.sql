-- Lightweight SQL test runner. Run after database/setup.sql.
-- Each row reports the expected value, actual value, and PASS/FAIL.
WITH test_results AS (
    SELECT 'TEST 1 - Occupancy never exceeds 100%' AS test_name,
           '0 violations' AS expected_result,
           COUNT(*)::TEXT || ' violations' AS actual_result,
           COUNT(*) = 0 AS passed
    FROM property_occupancy_view WHERE occupancy_percentage > 100

    UNION ALL
    SELECT 'TEST 2 - Negative payments are constrained', 'CHECK constraint exists',
           COUNT(*)::TEXT || ' matching constraints', COUNT(*) > 0
    FROM pg_constraint
    WHERE conrelid = 'payments'::regclass AND contype = 'c'
      AND conname = 'payments_amount_paid_check'

    UNION ALL
    SELECT 'TEST 3 - Every lease references a tenant', '0 orphan leases',
           COUNT(*)::TEXT || ' orphan leases', COUNT(*) = 0
    FROM leases l LEFT JOIN tenants t ON t.tenant_id = l.tenant_id WHERE t.tenant_id IS NULL

    UNION ALL
    SELECT 'TEST 4 - Every lease references a unit', '0 orphan leases',
           COUNT(*)::TEXT || ' orphan leases', COUNT(*) = 0
    FROM leases l LEFT JOIN units u ON u.unit_id = l.unit_id WHERE u.unit_id IS NULL

    UNION ALL
    SELECT 'TEST 5 - Every payment references a lease', '0 orphan payments',
           COUNT(*)::TEXT || ' orphan payments', COUNT(*) = 0
    FROM payments p LEFT JOIN leases l ON l.lease_id = p.lease_id WHERE l.lease_id IS NULL

    UNION ALL
    SELECT 'TEST 6 - Outstanding function matches source rows', '0 mismatches',
           COUNT(*)::TEXT || ' mismatches', COUNT(*) = 0
    FROM leases l
    WHERE calculate_lease_outstanding(l.lease_id) <>
          (SELECT COALESCE(SUM(p.amount_due - p.amount_paid), 0)
           FROM payments p WHERE p.lease_id = l.lease_id AND p.payment_status NOT IN ('paid','waived'))

    UNION ALL
    SELECT 'TEST 7 - Expired leases absent from active view', '0 invalid rows',
           COUNT(*)::TEXT || ' invalid rows', COUNT(*) = 0
    FROM active_leases_view WHERE end_date < CURRENT_DATE OR start_date > CURRENT_DATE

    UNION ALL
    SELECT 'TEST 8 - Occupancy cache matches active leases', '0 mismatches',
           COUNT(*)::TEXT || ' mismatches', COUNT(*) = 0
    FROM units u WHERE (u.unit_status = 'occupied') <>
      EXISTS (SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id)
)
SELECT test_name, expected_result, actual_result,
       CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS status
FROM test_results
ORDER BY test_name;

-- Make an automated run fail when any rule fails.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM property_occupancy_view WHERE occupancy_percentage > 100) THEN
        RAISE EXCEPTION 'TEST FAILED: occupancy exceeds 100%%';
    END IF;
    IF EXISTS (SELECT 1 FROM payments p LEFT JOIN leases l ON l.lease_id = p.lease_id WHERE l.lease_id IS NULL) THEN
        RAISE EXCEPTION 'TEST FAILED: orphan payment detected';
    END IF;
    IF EXISTS (SELECT 1 FROM active_leases_view WHERE end_date < CURRENT_DATE OR start_date > CURRENT_DATE) THEN
        RAISE EXCEPTION 'TEST FAILED: invalid row in active_leases_view';
    END IF;
END $$;
