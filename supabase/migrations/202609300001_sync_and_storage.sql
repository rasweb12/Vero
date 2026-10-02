-- Apply in the Supabase SQL editor or with `supabase db push`.
-- Payloads are already encrypted locally where they contain sensitive values.
create table public.sync_records (
  owner_id uuid not null references auth.users(id) on delete cascade,
  record_type text not null check (record_type in ('profile', 'training', 'measurements', 'photos')),
  payload jsonb not null,
  updated_at timestamptz not null,
  primary key (owner_id, record_type)
);

alter table public.sync_records enable row level security;
revoke all on public.sync_records from anon, authenticated;
grant select, insert, update, delete on public.sync_records to authenticated;

create policy "Read own sync records" on public.sync_records for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "Insert own sync records" on public.sync_records for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "Update own sync records" on public.sync_records for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "Delete own sync records" on public.sync_records for delete to authenticated
  using ((select auth.uid()) = owner_id);

create table public.sync_keys (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  key text not null check (char_length(key) between 40 and 200),
  created_at timestamptz not null default now()
);

alter table public.sync_keys enable row level security;
revoke all on public.sync_keys from anon, authenticated;
grant select, insert, update on public.sync_keys to authenticated;

create policy "Read own sync key" on public.sync_keys for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "Create own sync key" on public.sync_keys for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "Update own sync key" on public.sync_keys for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);

insert into storage.buckets (id, name, public)
values ('vero-private', 'vero-private', false)
on conflict (id) do nothing;

create policy "Read own Vero files" on storage.objects for select to authenticated
  using (
    bucket_id = 'vero-private'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "Upload own Vero files" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'vero-private'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "Update own Vero files" on storage.objects for update to authenticated
  using (
    bucket_id = 'vero-private'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  ) with check (
    bucket_id = 'vero-private'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "Delete own Vero files" on storage.objects for delete to authenticated
  using (
    bucket_id = 'vero-private'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
