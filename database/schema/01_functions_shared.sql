-- ============================================================================
--  01_functions_shared.sql — Cross-cutting helper functions
-- ============================================================================
--  Defined early because many tables' BEFORE UPDATE triggers reference it.
--  (Table-specific functions live in each feature file; security helpers that
--   need every table to exist first live in 12_security.sql.)
-- ============================================================================

-- Stamp updated_at on every row update.
create or replace function public.set_updated_at()
 returns trigger language plpgsql as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;
