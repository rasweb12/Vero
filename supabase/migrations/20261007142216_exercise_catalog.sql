-- Educational catalog, not user routines or private progress photos.
create table public.exercises (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9-]{0,99}$' and id not like 'custom-%'),
  name text not null check (char_length(name) between 1 and 160),
  muscle_group text not null,
  type text not null,
  aliases jsonb not null default '[]' check (jsonb_typeof(aliases) = 'array'),
  description text not null default '',
  primary_muscle text not null default '',
  secondary_muscles jsonb not null default '[]' check (jsonb_typeof(secondary_muscles) = 'array'),
  equipment jsonb not null default '[]' check (jsonb_typeof(equipment) = 'array'),
  difficulty text not null default 'unspecified' check (difficulty in ('beginner', 'intermediate', 'advanced', 'unspecified')),
  instructions jsonb not null default '[]' check (jsonb_typeof(instructions) = 'array'),
  common_errors jsonb not null default '[]' check (jsonb_typeof(common_errors) = 'array'),
  safety_tips jsonb not null default '[]' check (jsonb_typeof(safety_tips) = 'array'),
  alternatives jsonb not null default '[]' check (jsonb_typeof(alternatives) = 'array'),
  media jsonb check (media is null or (jsonb_typeof(media) = 'object'
    and media ? 'type'
    and (media ? 'url' or media ? 'local_asset')
    and media->>'type' in ('rive', 'lottie', 'animatedWebp', 'video')
    and ((media->>'url') like 'https://%' or (media->>'local_asset') like 'assets/exercises/%'))),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.exercises enable row level security;
revoke all on public.exercises from anon, authenticated;
grant select on public.exercises to authenticated;
grant all on public.exercises to service_role;
create policy "Read active exercise catalog" on public.exercises
  for select to authenticated using (is_active);
-- No client write policy: only trusted editors publish educational content.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('exercise-media', 'exercise-media', true, 25165824,
  array['application/octet-stream', 'application/json', 'image/webp', 'video/mp4', 'image/jpeg', 'image/png'])
on conflict (id) do nothing;
-- Public files contain only educational media. Uploads remain admin-only.
-- Do not reuse this bucket for users' photos or personal information.
