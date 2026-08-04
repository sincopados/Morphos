-- Ajustes sobre el esquema inicial, a partir de los advisors de Supabase.
--
-- 1. Las funciones de trigger vivian en `public` como SECURITY DEFINER, asi que
--    quedaban expuestas en /rest/v1/rpc/. Postgres igual rechaza invocar una
--    funcion de trigger directamente, pero no tienen por que estar en el
--    esquema expuesto: se mueven a `private`. Los triggers siguen funcionando
--    porque referencian la funcion por OID, no por nombre.
--
-- 2. Habia varias policies permisivas para el mismo rol y accion (SELECT), que
--    obligan a Postgres a evaluarlas todas en cada consulta. Se fusionan en una
--    sola policy por tabla con OR, y las policies `for all` se desglosan para
--    que no aporten un SELECT redundante.

-- ============================================================================
-- 1. Funciones de trigger fuera del esquema expuesto
-- ============================================================================

alter function public.handle_ledger_rejection() set schema private;
alter function public.enforce_checkin_block() set schema private;
alter function public.set_modification_window() set schema private;

revoke execute on function private.handle_ledger_rejection() from public, anon, authenticated;
revoke execute on function private.enforce_checkin_block() from public, anon, authenticated;
revoke execute on function private.set_modification_window() from public, anon, authenticated;

-- ============================================================================
-- 2. Policies de SELECT consolidadas
-- ============================================================================

-- --- users ------------------------------------------------------------------

drop policy users_select_self on public.users;
drop policy users_select_company_admin on public.users;

create policy users_select on public.users
  for select to authenticated
  using (
    auth_user_id = (select auth.uid())
    or (select private.is_company_admin(company_id))
  );

-- --- ledger_entries ---------------------------------------------------------

drop policy ledger_entries_select_own on public.ledger_entries;
drop policy ledger_entries_select_company_admin on public.ledger_entries;

create policy ledger_entries_select on public.ledger_entries
  for select to authenticated
  using (
    origin_user_id = (select private.app_user_id())
    or (select private.is_company_admin(company_id))
  );

-- --- work_sites -------------------------------------------------------------
-- El SELECT lo cubre work_sites_select_company; aqui solo escritura.

drop policy work_sites_write_admin on public.work_sites;

create policy work_sites_insert_admin on public.work_sites
  for insert to authenticated
  with check ((select private.is_company_admin(company_id)));

create policy work_sites_update_admin on public.work_sites
  for update to authenticated
  using ((select private.is_company_admin(company_id)))
  with check ((select private.is_company_admin(company_id)));

create policy work_sites_delete_admin on public.work_sites
  for delete to authenticated
  using ((select private.is_company_admin(company_id)));

-- --- assigned_shifts --------------------------------------------------------

drop policy assigned_shifts_select_own on public.assigned_shifts;
drop policy assigned_shifts_select_admin on public.assigned_shifts;
drop policy assigned_shifts_write_admin on public.assigned_shifts;

create policy assigned_shifts_select on public.assigned_shifts
  for select to authenticated
  using (
    user_id = (select private.app_user_id())
    or (select private.is_company_admin(company_id))
  );

create policy assigned_shifts_insert_admin on public.assigned_shifts
  for insert to authenticated
  with check ((select private.is_company_admin(company_id)));

create policy assigned_shifts_update_admin on public.assigned_shifts
  for update to authenticated
  using ((select private.is_company_admin(company_id)))
  with check ((select private.is_company_admin(company_id)));

create policy assigned_shifts_delete_admin on public.assigned_shifts
  for delete to authenticated
  using ((select private.is_company_admin(company_id)));
