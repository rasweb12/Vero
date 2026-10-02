-- Apply in the Supabase SQL editor or through supabase db push.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '' check (char_length(name) <= 80),
  goal_weight numeric check (goal_weight between 20 and 500),
  weekly_goal integer not null default 3 check (weekly_goal between 1 and 7),
  reminders boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select, insert, update on public.profiles to authenticated;

create policy "Read own profile" on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy "Insert own profile" on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);
create policy "Update own profile" on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create function public.set_profile_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger profile_updated_at before update on public.profiles
  for each row execute function public.set_profile_updated_at();

-- No plan column: client-selected plans must never grant server privileges.
