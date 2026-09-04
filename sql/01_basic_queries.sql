-- Basic filtering, ordering, DISTINCT, CASE, and NULL handling.

-- Vacant units with the highest potential rent first.
SELECT u.unit_id, p.property_name, u.unit_number, u.bedrooms, u.market_rent
FROM units u
JOIN properties p ON p.property_id = u.property_id
WHERE u.unit_status = 'vacant'
ORDER BY u.market_rent DESC, p.property_name, u.unit_number;

-- DISTINCT is useful here because many properties share a city.
SELECT DISTINCT city, state_code
FROM properties
WHERE is_active
ORDER BY state_code, city;

-- CASE turns stored statuses into a business-friendly collection category.
SELECT payment_reference, due_date, amount_due, amount_paid,
       CASE
           WHEN payment_status = 'pending' AND due_date < CURRENT_DATE THEN 'overdue'
           WHEN payment_status = 'partial' THEN 'partially paid'
           ELSE payment_status
       END AS collection_category,
       COALESCE(payment_method, 'not provided') AS payment_method
FROM payments
ORDER BY due_date DESC
LIMIT 100;
