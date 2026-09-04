# PropSQL Interview Notes

## Two-minute explanation

“PropSQL is a PostgreSQL-centered property-management support and reporting system. I designed a normalized schema for properties, units, tenants, leases, payments, maintenance requests, work orders, and vendors. The seed script creates a realistic portfolio with 25 properties, 300 units, hundreds of leases and maintenance records, and more than a thousand payments.

The important part is the SQL layer. I built occupancy, rent collection, delinquency, lease-expiry, maintenance, and combined property-performance reports. I used CTEs to aggregate facts at the correct grain, `EXISTS` to avoid double-counting occupied units, conditional aggregation for KPIs, and window functions for ranking and payment history. Shared definitions live in a few justified views.

I also documented ten support cases. Each starts with a user-visible symptom, runs investigation SQL, identifies the root cause, applies a fix, and validates the result. Three optimization examples use real PostgreSQL execution plans rather than fake timings. Constraints, validation queries, a SQL test runner, and backend unit tests protect business rules.

Flask loads named statements directly from the SQL files and exposes parameterized REST endpoints. React presents the live database results in practical tables and reports. A small rule-based assistant only selects approved read-only queries and displays the SQL. The project is relevant because it combines database engineering, troubleshooting, reporting, performance thinking, testing, and maintainable application code.”

## Why PostgreSQL

PostgreSQL is a strong fit for transactional property data because relationships and consistency matter. Foreign keys protect lease, tenant, unit, and payment links; check constraints protect amounts, dates, and statuses; views provide shared business definitions; and `EXPLAIN` provides transparent optimization evidence. PostgreSQL also supports the CTEs, window functions, filtered aggregates, date arithmetic, expression indexes, and stored functions used here without another data platform.

## Database design

- A property has many units.
- A unit has lease history; each lease connects one unit and one tenant.
- A lease has monthly payment charges.
- A unit has maintenance requests, optionally submitted by a tenant.
- A request has work orders, and each work order can be assigned to a vendor.

This separates stable entities from changing transactions. Tenant contact data is not repeated on every lease. Property addresses are not repeated on every unit. Payment details are not stored on the lease. The design reduces update anomalies and makes data ownership clear.

`unit_status` is intentionally a cached operational value. Occupancy reports use date-valid active leases as the source of truth, and a validation query detects disagreement. That is a useful example of acknowledging denormalization and controlling its risk.

## Important SQL to know

1. `property_occupancy_view`: uses `COUNT(...) FILTER` and correlated `EXISTS` so each physical unit is counted once.
2. `rent_collection_report`: expected rent and collected cash are aggregated in separate CTEs before joining.
3. `delinquent_tenant_report`: groups by tenant/property and uses `HAVING` for balances or repeated late payments.
4. `maintenance_summary_view`: averages `closed_at - created_at` only for closed requests.
5. `property_performance_report`: safely joins three property-grain views.
6. Duplicate-payment support query: groups by the business key `(lease_id, due_date, amount_due)` rather than only an external reference.

## Join explanation

Use an `INNER JOIN` when both sides are required for a meaningful row, such as a lease and its tenant. Use a `LEFT JOIN` when the parent must stay visible even without a child, such as a property with no maintenance requests or a vacant unit with no active lease. Before aggregating a join, state the intended result grain. If the result should be one row per property, aggregate each one-to-many fact table to property first.

## CTE explanation

A CTE gives a named intermediate result. In the rent report, one CTE computes expected rent and another computes collected payments. Both return one row per property. Joining them is correct and readable. Joining leases directly to many payments before summing monthly rent would multiply the lease value.

## Window-function explanation

A window function calculates across related rows without collapsing them into one group. `ROW_NUMBER() OVER (PARTITION BY tenant ORDER BY due_date DESC)` ranks each tenant’s payments so I can select the latest while keeping its full columns. Running `SUM` shows cumulative collection. `DENSE_RANK` ranks property collection rates while preserving ties.

## Index explanation

Indexes are based on access patterns, not created for every column. `idx_leases_status_end` supports the common active-lease expiry range. `idx_payments_lease_due` supports payment history and lease/month access. Foreign-key indexes support joins and parent integrity checks. The lower-name expression index supports a case-insensitive surname lookup. Indexes cost storage and write work, so each should have a query reason.

## Query optimization explanation

My process is: reproduce the query, run `EXPLAIN (ANALYZE, BUFFERS)` in a safe environment, inspect scan types, join methods, row estimates, filters, and loops, then change either the query shape or index. I rerun the plan and compare it. I do not claim a fixed speedup from the seed dataset because PostgreSQL may correctly prefer a sequential scan for small tables.

One example changes `to_char(end_date)` into a direct date range. The first form prevents a simple ordered lookup on the raw column; the second is sargable and eligible for `idx_leases_status_end`. Another replaces a per-lease correlated aggregate with one grouped payment scan.

## Support-case explanation

The most representative case is an occupancy report above 100%. The user symptom suggests either bad overlapping leases or a join-grain error. The faulty query counts lease rows after joining them to units. If one unit has two active rows, it is counted twice. I investigate duplicates per unit, change the report to count units with `EXISTS`, add a partial unique index allowing one active lease per unit, and validate that no occupancy percentage exceeds 100.

This demonstrates more than writing a query: translating a client symptom into a reproduction, isolating data versus report logic, fixing the smallest responsible layer, and proving the fix.

## API architecture

React calls Flask REST endpoints. Routes validate report parameters such as 30/60/90 days and ISO months. The service layer retrieves a named SQL block from the project’s `.sql` files and passes values separately to psycopg2. The database executes the report and Flask serializes rows. Database errors become safe messages; credentials and stack traces are not returned.

The query loader keeps the real SQL visible and avoids two competing versions in Python and SQL. The connection pool reuses a small number of PostgreSQL connections.

## Relevance to a software-engineering trainee role

The project covers the full support-to-delivery loop: relational modeling, SQL report development, troubleshooting incorrect totals, performance-plan analysis, validation, testing, API integration, readable code, configuration hygiene, and a usable client interface. It also creates concrete stories for discussing communication with functional consultants: clarify the business definition, confirm report grain and date rules, reproduce with SQL, explain the root cause plainly, and validate with the stakeholder.

## 15 likely interview questions and strong sample answers

### 1. Why can occupancy exceed 100% in a bad query?

Because the query may count lease rows after a one-to-many join instead of counting physical units. Overlapping active leases or another detail join multiplies a unit. I count units through `EXISTS` and also prevent multiple active leases with a partial unique index.

### 2. How did you define an active lease?

It must have `lease_status = 'active'` and today must fall between `start_date` and `end_date`. I put that rule in `active_leases_view` so reports do not rely on a possibly stale status flag alone.

### 3. Why not calculate reports in Python?

PostgreSQL is designed to join, filter, and aggregate close to the data. Keeping report logic in SQL makes its grain and execution plan visible, reduces transferred rows, and allows the same definition to serve multiple clients. Python handles HTTP validation and errors.

### 4. What is join fan-out?

It happens when one parent row joins to multiple rows in more than one child table. For example, joining one lease to twelve payments and several maintenance requests multiplies both sets. Aggregating afterward inflates totals. I pre-aggregate each fact to the target grain before joining.

### 5. Why use a CTE in the rent report?

It clearly separates expected rent from collected payments and ensures each has one row per property. The CTE is mainly for correctness and readability; PostgreSQL can inline suitable CTEs when planning.

### 6. What is the difference between `WHERE` and `HAVING`?

`WHERE` filters input rows before grouping. `HAVING` filters completed groups, so it can use expressions such as `SUM(amount_due - amount_paid) > 0`.

### 7. Why use `EXISTS` instead of a join for occupancy?

I need a yes/no answer per unit, not columns from every lease. `EXISTS` stops the logical question at existence and preserves one unit row, which makes double-counting harder.

### 8. What constraints matter most here?

Foreign keys prevent orphan leases, payments, requests, and work orders. Check constraints prevent negative amounts, invalid lease dates, unsupported statuses, and closed records without timestamps. Unique constraints protect property codes, unit numbers within a property, emails, and payment references.

### 9. How do you find duplicate payments?

I check both technical and business identifiers. `payment_reference` is unique, but an import could retry with a new reference. Grouping by lease, due date, and amount identifies likely business duplicates for review. Whether split payments are allowed determines the final uniqueness rule.

### 10. How do you know an index improved a query?

I compare actual plans in the same environment. I inspect whether the predicate became indexable, scan and join nodes, estimated versus actual rows, loops, buffers, and total work. I avoid quoting a portfolio speedup from small seed data.

### 11. Why might PostgreSQL ignore an index?

For a small table or a query returning many rows, reading the table sequentially may be cheaper. Statistics, selectivity, function-wrapped columns, type casts, and outdated statistics also affect the choice. An unused index does not automatically mean the planner is wrong.

### 12. How is the assistant safe?

It does not generate arbitrary SQL. It maps recognized questions to a fixed catalog, rejects unsupported questions, verifies that the selected statement begins with `SELECT` or `WITH`, rejects write/DDL keywords, uses parameters, and runs on a read-only database transaction. It also displays the SQL.

### 13. How would you handle a client reporting the wrong total?

I would confirm the report filters, date basis, and intended row grain; reproduce the value with the smallest query; compare source counts before and after each join; check data-quality exceptions; identify whether the issue is data, definition, or query logic; then fix and provide validation SQL with the client’s example.

### 14. What would you test in CI?

I would start an empty PostgreSQL service, run `database/setup.sql`, run the SQL tests and validation queries, run backend unit tests, exercise key API endpoints, and build the frontend. That proves the schema can be recreated and integrations are not relying on a developer’s local state.

### 15. What would you improve for production?

I would add authentication and role-based database users, migration tooling, audited status transitions, idempotent staging for imports, pagination totals, CSV export, structured observability, automated CI with PostgreSQL, and production-scale plan testing. I would keep the current architecture simple until those needs are real.
