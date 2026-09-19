-- ============================================================
-- HEALTHSPEC
-- Migration 001: Foundation
-- profiles, workspaces, workspace_members, workspace_invitations
-- ============================================================

create extension if not exists "pgcrypto";

-- ============================================================
-- ENUM TYPES
-- ============================================================
create type public.workspace_role as enum (
  'owner',
  'admin',
  'developer',
  'viewer'
);

create type public.membership_status as enum (
  'active',
  'invited',
  'suspended'
);

-- ============================================================
-- PROFILES
-- ============================================================
create table public.profiles (
  id uuid primary key
    references auth.users(id)
    on delete cascade,
  display_name text,
  avatar_url text,
  timezone text not null default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- WORKSPACES
-- ============================================================
create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  created_by uuid not null
    references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint workspace_name_length
    check (char_length(trim(name)) between 1 and 100),
  constraint workspace_slug_format
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

-- ============================================================
-- WORKSPACE MEMBERS
-- ============================================================
create table public.workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null
    references public.workspaces(id)
    on delete cascade,
  user_id uuid not null
    references auth.users(id)
    on delete cascade,
  role public.workspace_role not null,
  status public.membership_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint unique_workspace_member
    unique (workspace_id, user_id)
);

-- ============================================================
-- WORKSPACE INVITATIONS
-- ============================================================
create table public.workspace_invitations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null
    references public.workspaces(id)
    on delete cascade,
  email text not null,
  role public.workspace_role not null,
  invited_by uuid not null
    references auth.users(id),
  token_hash text not null,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint invitation_email_not_empty
    check (char_length(trim(email)) > 0)
);

-- ============================================================
-- INDEXES
-- ============================================================
create index workspace_members_user_id_idx
  on public.workspace_members(user_id);
create index workspace_members_workspace_id_idx
  on public.workspace_members(workspace_id);
create index workspace_members_workspace_status_idx
  on public.workspace_members(workspace_id, status);
create index workspace_invitations_workspace_id_idx
  on public.workspace_invitations(workspace_id);
create index workspace_invitations_email_idx
  on public.workspace_invitations(lower(email));
create index workspaces_created_by_idx
  on public.workspaces(created_by);

-- ============================================================
-- UPDATED_AT FUNCTION + TRIGGERS
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create trigger workspaces_set_updated_at
before update on public.workspaces
for each row
execute function public.set_updated_at();

create trigger workspace_members_set_updated_at
before update on public.workspace_members
for each row
execute function public.set_updated_at();

-- ============================================================
-- PROFILE AUTO-CREATION ON SIGNUP
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.workspace_invitations enable row level security;

-- ============================================================
-- AUTHORIZATION HELPER FUNCTIONS
-- (security definer to avoid recursive RLS on workspace_members)
-- ============================================================
create or replace function public.is_workspace_member(
  target_workspace_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_members
    where workspace_id = target_workspace_id
      and user_id = auth.uid()
      and status = 'active'
  );
$$;

create or replace function public.has_workspace_role(
  target_workspace_id uuid,
  allowed_roles public.workspace_role[]
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_members
    where workspace_id = target_workspace_id
      and user_id = auth.uid()
      and status = 'active'
      and role = any(allowed_roles)
  );
$$;

-- ============================================================
-- RLS POLICIES: profiles
-- ============================================================
create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using (id = auth.uid());

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- ============================================================
-- RLS POLICIES: workspaces
-- ============================================================
create policy "Members can view their workspaces"
on public.workspaces
for select
to authenticated
using (public.is_workspace_member(id));

create policy "Admins can update workspaces"
on public.workspaces
for update
to authenticated
using (
  public.has_workspace_role(
    id,
    array['owner'::public.workspace_role, 'admin'::public.workspace_role]
  )
)
with check (
  public.has_workspace_role(
    id,
    array['owner'::public.workspace_role, 'admin'::public.workspace_role]
  )
);

-- Note: workspace creation is intentionally NOT covered by a client-facing
-- INSERT policy. Creating a workspace + its owner membership happens
-- atomically via a server-side function (added in the auth/workspace build),
-- not via direct client inserts.

-- ============================================================
-- RLS POLICIES: workspace_members
-- ============================================================
create policy "Members can view workspace members"
on public.workspace_members
for select
to authenticated
using (public.is_workspace_member(workspace_id));

create policy "Admins can manage workspace members"
on public.workspace_members
for all
to authenticated
using (
  public.has_workspace_role(
    workspace_id,
    array['owner'::public.workspace_role, 'admin'::public.workspace_role]
  )
)
with check (
  public.has_workspace_role(
    workspace_id,
    array['owner'::public.workspace_role, 'admin'::public.workspace_role]
  )
);

-- ============================================================
-- RLS POLICIES: workspace_invitations
-- ============================================================
create policy "Members can view workspace invitations"
on public.workspace_invitations
for select
to authenticated
using (public.is_workspace_member(workspace_id));

create policy "Admins can create invitations"
on public.workspace_invitations
for insert
to authenticated
with check (
  public.has_workspace_role(
    workspace_id,
    array['owner'::public.workspace_role, 'admin'::public.workspace_role]
  )
);

create policy "Admins can manage invitations"
on public.workspace_invitations
for update
to authenticated
using (
  public.has_workspace_role(
    workspace_id,
    array['owner'::public.workspace_role, 'admin'::public.workspace_role]
  )
)
with check (
  public.has_workspace_role(
    workspace_id,
    array['owner'::public.workspace_role, 'admin'::public.workspace_role]
  )
);
