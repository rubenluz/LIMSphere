// Generated from the production security migration. Keep this bundled with the
// setup SQL so fresh LIMSphere projects receive the same RLS baseline.
const String securityHardeningSQL = r'''
-- LIMSphere Data API hardening.
-- Keeps pre-login discovery intentionally narrow while enforcing account
-- status and the application's module/action permissions at the database.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create or replace function private.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users u
    where u.user_auth_uid = (select auth.uid())
      and u.user_status = 'active'
  );
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users u
    where u.user_auth_uid = (select auth.uid())
      and u.user_status = 'active'
      and u.user_role in ('admin', 'superadmin')
  );
$$;

create or replace function private.current_user_id()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select u.user_id from public.users u
  where u.user_auth_uid = (select auth.uid()) and u.user_status = 'active'
  limit 1;
$$;

create or replace function private.has_module_action(module_id text, requested_action text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p public.users%rowtype;
  role_rank integer;
  required_rank integer := 0;
  legacy_permission text := 'write';
  page_rule jsonb;
  page_access text;
  action_value jsonb;
begin
  select * into p
  from public.users u
  where u.user_auth_uid = (select auth.uid())
    and u.user_status = 'active'
  limit 1;

  if not found then return false; end if;
  if p.user_role in ('admin', 'superadmin') then return true; end if;

  role_rank := case p.user_role
    when 'viewer' then 1 when 'technician' then 2 when 'researcher' then 3
    when 'admin' then 4 when 'superadmin' then 5 else 0 end;

  required_rank := case
    when module_id in ('dashboard','labels','chat','samples','culture_map',
      'sops_inventory','fish_tankmap','fish_lines','fish_water_qc',
      'sops_fish','sops_resources','lab','locations','reagents','equipment',
      'reservations') then 2
    when module_id in ('audit','users','settings') then 4
    else 0 end;
  if role_rank < required_rank then return false; end if;

  legacy_permission := case
    when module_id = 'dashboard' then p.user_table_dashboard
    when module_id = 'labels' then p.user_table_labels
    when module_id = 'chat' then p.user_table_chat
    when module_id = 'backups' then p.user_table_backups
    when module_id in ('strains','samples','culture_map','sops_inventory')
      then p.user_table_culture_collection
    when module_id in ('fish_stock','fish_tankmap','fish_lines','fish_water_qc','sops_fish')
      then p.user_table_fish_facility
    when module_id in ('sops_resources','lab','locations','reagents','equipment','reservations')
      then p.user_table_resources
    when module_id in ('requests','tools') then 'write'
    else 'none' end;

  page_rule := coalesce(p.user_permissions_json, '{}'::jsonb)
    -> 'pages' -> module_id;
  page_access := page_rule ->> 'page_access';
  if page_access in ('none','read','write') then
    legacy_permission := page_access;
  end if;

  action_value := page_rule -> 'actions' -> requested_action;
  if action_value is not null and action_value <> 'null'::jsonb then
    if action_value = 'true'::jsonb then return true; end if;
    if action_value = 'false'::jsonb then return false; end if;
  end if;

  if requested_action = 'view' then
    if coalesce(page_rule -> 'actions' ->> 'insert', 'false') = 'true'
      or coalesce(page_rule -> 'actions' ->> 'edit', 'false') = 'true'
      or coalesce(page_rule -> 'actions' ->> 'delete', 'false') = 'true'
      or coalesce(page_rule -> 'actions' ->> 'approve', 'false') = 'true'
      or coalesce(page_rule -> 'actions' ->> 'bulk_update', 'false') = 'true'
    then return true; end if;
    return legacy_permission in ('read', 'write');
  end if;

  return legacy_permission = 'write';
end;
$$;

revoke all on function private.is_active_user() from public, anon;
revoke all on function private.is_admin() from public, anon;
revoke all on function private.current_user_id() from public, anon;
revoke all on function private.has_module_action(text, text) from public, anon;
grant execute on function private.is_active_user() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.current_user_id() to authenticated;
grant execute on function private.has_module_action(text, text) to authenticated;

-- Only these two boolean facts are available before login.
create or replace function public.limsphere_is_initialized()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(bool_or(m.meta_initialized), false) from public.app_meta m;
$$;

create or replace function public.limsphere_has_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.users u
    where u.user_role = 'superadmin' and u.user_status = 'active'
  );
$$;

revoke all on function public.limsphere_is_initialized() from public;
revoke all on function public.limsphere_has_admin() from public;
grant execute on function public.limsphere_is_initialized() to anon, authenticated;
grant execute on function public.limsphere_has_admin() to anon, authenticated;

-- Atomic first-admin creation. Supabase Auth must have issued a session.
create or replace function public.limsphere_bootstrap_superadmin(p_name text, p_email text)
returns public.users
language plpgsql
security definer
set search_path = ''
as $$
declare
  created public.users;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  if lower(coalesce((select auth.email()), '')) <> lower(trim(coalesce(p_email, ''))) then
    raise exception 'Authenticated email does not match';
  end if;
  if exists (select 1 from public.users) then raise exception 'LIMSphere is already initialized'; end if;

  insert into public.users (
    user_auth_uid, user_name, user_email, user_role, user_status,
    user_table_dashboard, user_table_labels, user_table_chat,
    user_table_backups, user_table_culture_collection,
    user_table_fish_facility, user_table_resources, user_permissions_json
  ) values (
    (select auth.uid()), trim(p_name), lower(trim(p_email)), 'superadmin', 'active',
    'write', 'write', 'write', 'write', 'write', 'write', 'write', '{}'::jsonb
  ) returning * into created;
  return created;
end;
$$;

revoke all on function public.limsphere_bootstrap_superadmin(text, text) from public, anon;
grant execute on function public.limsphere_bootstrap_superadmin(text, text) to authenticated;

create or replace function public.limsphere_set_lab_layout(p_layout jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_id bigint;
  next_settings jsonb;
begin
  if not private.has_module_action('lab', 'edit') then raise exception 'Access denied'; end if;
  select m.meta_id, coalesce(m.meta_settings, '{}'::jsonb)
    into target_id, next_settings
  from public.app_meta m where m.meta_initialized = true
  order by m.meta_id nulls last limit 1 for update;
  if target_id is null then raise exception 'LIMSphere metadata is not initialized'; end if;
  next_settings := jsonb_set(next_settings, '{lab_layout}', coalesce(p_layout, '{}'::jsonb), true);
  update public.app_meta set meta_settings = next_settings where meta_id = target_id;
  return next_settings;
end;
$$;
revoke all on function public.limsphere_set_lab_layout(jsonb) from public, anon;
grant execute on function public.limsphere_set_lab_layout(jsonb) to authenticated;

-- Safe active-user directory. A separate read-only table avoids exposing the
-- users authorization columns and avoids a view that bypasses RLS.
do $$
begin
  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'user_directory'
      and c.relkind in ('v', 'm')
  ) then execute 'drop view public.user_directory'; end if;
end $$;
create table if not exists public.user_directory (
  user_id bigint primary key,
  user_auth_uid uuid unique,
  user_email citext not null,
  user_name text,
  user_role text,
  user_phone text,
  user_orcid text,
  user_institution text,
  user_group text,
  user_avatar_url text,
  user_bio text
);

create or replace function private.sync_user_directory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare source public.users%rowtype;
begin
  source := case when tg_op = 'DELETE' then old else new end;
  if tg_op = 'DELETE' or source.user_status <> 'active' then
    delete from public.user_directory d where d.user_id = source.user_id;
  else
    insert into public.user_directory (
      user_id, user_auth_uid, user_email, user_name, user_role, user_phone,
      user_orcid, user_institution, user_group, user_avatar_url, user_bio
    ) values (
      source.user_id, source.user_auth_uid, source.user_email, source.user_name,
      source.user_role, source.user_phone, source.user_orcid,
      source.user_institution, source.user_group, source.user_avatar_url, source.user_bio
    ) on conflict (user_id) do update set
      user_auth_uid = excluded.user_auth_uid, user_email = excluded.user_email,
      user_name = excluded.user_name, user_role = excluded.user_role,
      user_phone = excluded.user_phone, user_orcid = excluded.user_orcid,
      user_institution = excluded.user_institution, user_group = excluded.user_group,
      user_avatar_url = excluded.user_avatar_url, user_bio = excluded.user_bio;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
revoke all on function private.sync_user_directory() from public, anon, authenticated;
drop trigger if exists users_sync_directory on public.users;
create trigger users_sync_directory after insert or update or delete on public.users
for each row execute function private.sync_user_directory();
insert into public.user_directory
select u.user_id, u.user_auth_uid, u.user_email, u.user_name, u.user_role,
       u.user_phone, u.user_orcid, u.user_institution, u.user_group,
       u.user_avatar_url, u.user_bio
from public.users u where u.user_status = 'active'
on conflict (user_id) do update set
  user_auth_uid = excluded.user_auth_uid, user_email = excluded.user_email,
  user_name = excluded.user_name, user_role = excluded.user_role,
  user_phone = excluded.user_phone, user_orcid = excluded.user_orcid,
  user_institution = excluded.user_institution, user_group = excluded.user_group,
  user_avatar_url = excluded.user_avatar_url, user_bio = excluded.user_bio;
alter table public.user_directory enable row level security;
revoke all on public.user_directory from public, anon, authenticated;
grant select on public.user_directory to authenticated;

-- Prevent self-service privilege escalation while retaining profile edits and
-- the legacy one-time user_auth_uid backfill.
create or replace function private.protect_user_security_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_admin() then return new; end if;
  if old.user_auth_uid <> (select auth.uid()) then raise exception 'Access denied'; end if;
  if new.user_id is distinct from old.user_id
    or new.user_email is distinct from old.user_email
    or new.user_role is distinct from old.user_role
    or new.user_status is distinct from old.user_status
    or new.user_table_dashboard is distinct from old.user_table_dashboard
    or new.user_table_labels is distinct from old.user_table_labels
    or new.user_table_chat is distinct from old.user_table_chat
    or new.user_table_backups is distinct from old.user_table_backups
    or new.user_table_culture_collection is distinct from old.user_table_culture_collection
    or new.user_table_fish_facility is distinct from old.user_table_fish_facility
    or new.user_table_resources is distinct from old.user_table_resources
    or new.user_permissions_json is distinct from old.user_permissions_json
    or (new.user_auth_uid is distinct from old.user_auth_uid
        and not (old.user_auth_uid is null and new.user_auth_uid = (select auth.uid())))
  then raise exception 'Only administrators can change account security fields'; end if;
  return new;
end;
$$;
revoke all on function private.protect_user_security_fields() from public, anon, authenticated;
drop trigger if exists users_protect_security_fields on public.users;
create trigger users_protect_security_fields before update on public.users
for each row execute function private.protect_user_security_fields();

-- Harden trigger/helper functions and remove unused schema enumeration.
drop function if exists public.get_public_tables();
alter function public.log_audit() set search_path = public, pg_temp;
alter function public.assign_storage_location_code() set search_path = public, pg_temp;
alter function public.refresh_limsphere_qr_codes(text) set search_path = public, pg_temp;
revoke all on function public.log_audit() from public, anon, authenticated;
revoke all on function public.assign_storage_location_code() from public, anon, authenticated;
revoke all on function public.refresh_limsphere_qr_codes(text) from public, anon;
grant execute on function public.refresh_limsphere_qr_codes(text) to authenticated;

-- Remove every legacy policy on application tables before installing the
-- least-privilege policy set below.
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('app_meta','users','requests','storage_locations','samples',
        'strains','requested_strains','protocols','reagents','equipment','reservations',
        'fish_lines','fish_stocks','messages','water_qc','water_qc_maintenance',
        'water_qc_thresholds','audit_log','facility_sops','todo_items','label_templates','user_directory')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

drop function if exists public.app_is_bootstrap();

do $$
declare t text;
begin
  foreach t in array array['app_meta','users','requests','storage_locations','samples',
    'strains','requested_strains','protocols','reagents','equipment','reservations',
    'fish_lines','fish_stocks','messages','water_qc','water_qc_maintenance',
    'water_qc_thresholds','audit_log','facility_sops','todo_items','label_templates','user_directory']
  loop execute format('alter table public.%I enable row level security', t); end loop;
end $$;

revoke all privileges on all tables in schema public from anon;
revoke all privileges on all tables in schema public from authenticated;
revoke all privileges on all sequences in schema public from anon;
revoke all privileges on all sequences in schema public from authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant select on public.user_directory to authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
grant execute on function public.limsphere_is_initialized() to anon, authenticated;
grant execute on function public.limsphere_has_admin() to anon, authenticated;
grant execute on function public.limsphere_bootstrap_superadmin(text, text) to authenticated;
grant execute on function public.limsphere_set_lab_layout(jsonb) to authenticated;
grant execute on function public.refresh_limsphere_qr_codes(text) to authenticated;
grant select, update on public.app_meta to authenticated;
grant select, insert, update, delete on public.users to authenticated;
grant select on public.audit_log to authenticated;
grant select, insert, update, delete on public.requests, public.storage_locations,
  public.samples, public.strains, public.requested_strains, public.protocols,
  public.reagents, public.equipment, public.reservations, public.fish_lines,
  public.fish_stocks, public.messages, public.water_qc,
  public.water_qc_maintenance, public.water_qc_thresholds,
  public.facility_sops, public.todo_items, public.label_templates to authenticated;

create policy app_meta_select_active on public.app_meta for select to authenticated
using ((select private.is_active_user()));
create policy app_meta_update_admin on public.app_meta for update to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));

create policy user_directory_select_active on public.user_directory for select to authenticated
using ((select private.is_active_user()));

create policy users_select_self_or_admin on public.users for select to authenticated
using (user_auth_uid = (select auth.uid()) or (select private.is_admin()));
create policy users_register_self on public.users for insert to authenticated
with check (
  user_auth_uid = (select auth.uid()) and user_status = 'pending'
  and user_role = 'researcher'
  and user_table_dashboard = 'none' and user_table_labels = 'none'
  and user_table_chat = 'none' and user_table_backups = 'none'
  and user_table_culture_collection = 'none'
  and user_table_fish_facility = 'none' and user_table_resources = 'none'
  and coalesce(user_permissions_json, '{}'::jsonb) in ('{}'::jsonb, '{"version":1,"pages":{}}'::jsonb)
);
create policy users_update_self_or_admin on public.users for update to authenticated
using (user_auth_uid = (select auth.uid()) or (select private.is_admin()))
with check (user_auth_uid = (select auth.uid()) or (select private.is_admin()));
create policy users_delete_admin on public.users for delete to authenticated
using ((select private.is_admin()));

-- module table, module id. SELECT also permits dashboard widgets to read their
-- aggregate source tables without granting mutation rights.
do $$
declare m record;
begin
  for m in select * from (values
    ('samples','samples'), ('strains','strains'),
    ('requested_strains','strains'), ('protocols','sops_inventory'),
    ('reagents','reagents'), ('equipment','equipment'),
    ('fish_lines','fish_lines'), ('fish_stocks','fish_stock'),
    ('water_qc','fish_water_qc'),
    ('water_qc_maintenance','fish_water_qc'), ('water_qc_thresholds','fish_water_qc'),
    ('label_templates','labels')
  ) as x(table_name, module_id)
  loop
    execute format('create policy %I on public.%I for select to authenticated using ((select private.has_module_action(%L, ''view'')) or (select private.has_module_action(''dashboard'', ''view'')))', m.table_name || '_select', m.table_name, m.module_id);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select private.has_module_action(%L, ''insert'')))', m.table_name || '_insert', m.table_name, m.module_id);
    execute format('create policy %I on public.%I for update to authenticated using ((select private.has_module_action(%L, ''edit''))) with check ((select private.has_module_action(%L, ''edit'')))', m.table_name || '_update', m.table_name, m.module_id, m.module_id);
    execute format('create policy %I on public.%I for delete to authenticated using ((select private.has_module_action(%L, ''delete'')))', m.table_name || '_delete', m.table_name, m.module_id);
  end loop;
end $$;

create policy requests_select on public.requests for select to authenticated
using ((select private.has_module_action('requests','view')) or (select private.has_module_action('dashboard','view')));
create policy requests_insert on public.requests for insert to authenticated
with check ((select private.has_module_action('requests','insert')) and request_created_by = (select private.current_user_id()));
create policy requests_update on public.requests for update to authenticated
using ((select private.has_module_action('requests','edit'))) with check ((select private.has_module_action('requests','edit')));
create policy requests_delete on public.requests for delete to authenticated
using ((select private.has_module_action('requests','delete')));

create policy reservations_select on public.reservations for select to authenticated
using ((select private.has_module_action('reservations','view')) or (select private.has_module_action('dashboard','view')));
create policy reservations_insert on public.reservations for insert to authenticated
with check ((select private.has_module_action('reservations','insert')) and reservation_user_id = (select private.current_user_id()));
create policy reservations_update on public.reservations for update to authenticated
using ((select private.has_module_action('reservations','edit'))) with check ((select private.has_module_action('reservations','edit')));
create policy reservations_delete on public.reservations for delete to authenticated
using ((select private.has_module_action('reservations','delete')));

create policy messages_select on public.messages for select to authenticated
using ((select private.has_module_action('chat','view')));
create policy messages_insert on public.messages for insert to authenticated
with check ((select private.has_module_action('chat','insert')) and message_user_uid = (select auth.uid()));
create policy messages_update on public.messages for update to authenticated
using ((select private.has_module_action('chat','edit')) and (message_user_uid = (select auth.uid()) or (select private.is_admin())))
with check ((select private.has_module_action('chat','edit')) and (message_user_uid = (select auth.uid()) or (select private.is_admin())));
create policy messages_delete on public.messages for delete to authenticated
using ((select private.has_module_action('chat','delete')) and (message_user_uid = (select auth.uid()) or (select private.is_admin())));

create policy todo_items_select on public.todo_items for select to authenticated
using ((select private.has_module_action('dashboard','view')));
create policy todo_items_insert on public.todo_items for insert to authenticated
with check ((select private.has_module_action('dashboard','insert')) and todo_created_by = (select private.current_user_id()));
create policy todo_items_update on public.todo_items for update to authenticated
using ((select private.has_module_action('dashboard','edit'))) with check ((select private.has_module_action('dashboard','edit')));
create policy todo_items_delete on public.todo_items for delete to authenticated
using ((select private.has_module_action('dashboard','delete')));

create policy storage_locations_select on public.storage_locations for select to authenticated
using ((select private.has_module_action('locations','view'))
  or (select private.has_module_action('lab','view'))
  or (select private.has_module_action('reagents','view'))
  or (select private.has_module_action('equipment','view'))
  or (select private.has_module_action('dashboard','view')));
create policy storage_locations_insert on public.storage_locations for insert to authenticated
with check ((select private.has_module_action('locations','insert')) or (select private.has_module_action('lab','insert')));
create policy storage_locations_update on public.storage_locations for update to authenticated
using ((select private.has_module_action('locations','edit')) or (select private.has_module_action('lab','edit')))
with check ((select private.has_module_action('locations','edit')) or (select private.has_module_action('lab','edit')));
create policy storage_locations_delete on public.storage_locations for delete to authenticated
using ((select private.has_module_action('locations','delete')) or (select private.has_module_action('lab','delete')));

create policy facility_sops_select on public.facility_sops for select to authenticated
using ((select private.has_module_action('sops_inventory','view'))
  or (select private.has_module_action('sops_fish','view'))
  or (select private.has_module_action('sops_resources','view')));
create policy facility_sops_insert on public.facility_sops for insert to authenticated
with check (case lower(coalesce(sop_context,''))
  when 'fish' then (select private.has_module_action('sops_fish','insert'))
  when 'resources' then (select private.has_module_action('sops_resources','insert'))
  else (select private.has_module_action('sops_inventory','insert')) end);
create policy facility_sops_update on public.facility_sops for update to authenticated
using ((select private.has_module_action('sops_inventory','edit'))
  or (select private.has_module_action('sops_fish','edit'))
  or (select private.has_module_action('sops_resources','edit')))
with check ((select private.has_module_action('sops_inventory','edit'))
  or (select private.has_module_action('sops_fish','edit'))
  or (select private.has_module_action('sops_resources','edit')));
create policy facility_sops_delete on public.facility_sops for delete to authenticated
using ((select private.has_module_action('sops_inventory','delete'))
  or (select private.has_module_action('sops_fish','delete'))
  or (select private.has_module_action('sops_resources','delete')));

create policy audit_log_select on public.audit_log for select to authenticated
using ((select private.has_module_action('audit','view')));

-- Storage follows the same SOP permissions as the facility_sops rows.
drop policy if exists "Authenticated full access" on storage.objects;
drop policy if exists "facility_sops_authenticated_all" on storage.objects;
create policy facility_sops_select on storage.objects for select to authenticated
using (bucket_id = 'facility-sops' and (
  (select private.has_module_action('sops_inventory','view'))
  or (select private.has_module_action('sops_fish','view'))
  or (select private.has_module_action('sops_resources','view'))));
create policy facility_sops_insert on storage.objects for insert to authenticated
with check (bucket_id = 'facility-sops' and (
  (select private.has_module_action('sops_inventory','insert'))
  or (select private.has_module_action('sops_fish','insert'))
  or (select private.has_module_action('sops_resources','insert'))));
create policy facility_sops_update on storage.objects for update to authenticated
using (bucket_id = 'facility-sops' and (
  (select private.has_module_action('sops_inventory','edit'))
  or (select private.has_module_action('sops_fish','edit'))
  or (select private.has_module_action('sops_resources','edit'))))
with check (bucket_id = 'facility-sops' and (
  (select private.has_module_action('sops_inventory','edit'))
  or (select private.has_module_action('sops_fish','edit'))
  or (select private.has_module_action('sops_resources','edit'))));
create policy facility_sops_delete on storage.objects for delete to authenticated
using (bucket_id = 'facility-sops' and (
  (select private.has_module_action('sops_inventory','delete'))
  or (select private.has_module_action('sops_fish','delete'))
  or (select private.has_module_action('sops_resources','delete'))));

create index if not exists users_auth_uid_status_idx on public.users (user_auth_uid, user_status);
notify pgrst, 'reload schema';

''';
