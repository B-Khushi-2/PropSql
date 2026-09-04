\set ON_ERROR_STOP on
\ir schema.sql
\ir seed.sql
\ir indexes.sql
\ir views.sql
\ir procedures.sql

SELECT 'PropSQL database installed successfully' AS status;
