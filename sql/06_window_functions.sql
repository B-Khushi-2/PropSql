-- ROW_NUMBER keeps each tenant's most recent payment without collapsing detail too early.
SELECT *
FROM (
    SELECT t.tenant_id, t.first_name || ' ' || t.last_name AS tenant_name,
           p.payment_id, p.due_date, p.paid_date, p.amount_paid, p.payment_status,
           ROW_NUMBER() OVER (PARTITION BY t.tenant_id ORDER BY p.due_date DESC, p.payment_id DESC) AS recency_rank
    FROM tenants t
    JOIN leases l ON l.tenant_id = t.tenant_id
    JOIN payments p ON p.lease_id = l.lease_id
) ranked
WHERE recency_rank = 1
ORDER BY tenant_name;

-- Running total shows collection progress across the month.
SELECT due_date, payment_reference, amount_paid,
       SUM(amount_paid) OVER (PARTITION BY date_trunc('month', due_date)
                              ORDER BY due_date, payment_id) AS monthly_running_total
FROM payments
WHERE due_date >= date_trunc('month', CURRENT_DATE)
  AND due_date < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
ORDER BY due_date, payment_id;

-- DENSE_RANK preserves ties when ranking properties by collection percentage.
SELECT property_name, collection_percentage,
       DENSE_RANK() OVER (ORDER BY collection_percentage DESC NULLS LAST) AS collection_rank
FROM rent_collection_view;
