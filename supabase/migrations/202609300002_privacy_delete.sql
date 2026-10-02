-- Allows the signed-in owner to remove the app data from the cloud.
-- The auth.users account itself is intentionally kept; account deletion needs
-- a trusted server-side admin flow and must never use a service key in the app.
grant delete on public.profiles to authenticated;
create policy "Delete own profile" on public.profiles for delete to authenticated
  using ((select auth.uid()) = id);

grant delete on public.sync_keys to authenticated;
create policy "Delete own sync key" on public.sync_keys for delete to authenticated
  using ((select auth.uid()) = owner_id);
