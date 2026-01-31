# Phase 1: Database Development

## Purpose
Create and initialize the hospital database with complete schema and sample data.

## Directory Structure
```
phase1-database/
├── schema/          # Database and table definitions
├── data/            # Sample data population scripts
├── procedures/      # Stored procedures
├── functions/       # User-defined functions
├── triggers/        # Triggers for auditing
└── views/           # Database views
```

## Execution Order
1. schema/01_create_database.sql
2. schema/02_create_tables.sql
3. schema/03_create_indexes.sql
4. data/01_insert_departments.sql
5. data/02_insert_staff.sql
6. data/03_insert_patients.sql
7. procedures/01_create_procedures.sql
8. functions/01_create_functions.sql
9. views/01_create_views.sql
10. triggers/01_create_triggers.sql

## How to Run
```bash
cd phase1-database
../scripts/run_phase.sh 1
```
