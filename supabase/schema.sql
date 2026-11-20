-- AL SHEIKHA initial schema. Review RLS and storage policies before production.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'customer' check (role in ('customer','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  age integer check (age is null or age between 18 and 100),
  address text,
  has_location boolean not null default false,
  availability text not null default 'available' check (availability in ('available','busy','inactive')),
  hourly_price_iqd integer check (hourly_price_iqd is null or hourly_price_iqd >= 0),
  overnight_price_iqd integer check (overnight_price_iqd is null or overnight_price_iqd >= 0),
  photo_urls text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint staff_max_10_photos check (cardinality(photo_urls) <= 10)
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid references public.staff(id) on delete set null,
  session_date date not null,
  notes text,
  photo_urls text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint sessions_max_10_photos check (cardinality(photo_urls) <= 10)
);

create table if not exists public.banners (
  id uuid primary key default gen_random_uuid(),
  title text,
  image_url text not null,
  linked_staff_id uuid references public.staff(id) on delete set null,
  linked_session_id uuid references public.sessions(id) on delete set null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint banner_single_link check (not (linked_staff_id is not null and linked_session_id is not null))
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  staff_id uuid references public.staff(id) on delete set null,
  starts_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled','completed')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text,
  attachment_url text,
  shared_staff_id uuid references public.staff(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint message_has_content check (coalesce(length(trim(body)),0) > 0 or attachment_url is not null or shared_staff_id is not null)
);

create table if not exists public.favorites (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  staff_id uuid not null references public.staff(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (customer_id, staff_id)
);

create index if not exists bookings_customer_start_idx on public.bookings(customer_id, starts_at desc);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id, created_at);
create index if not exists sessions_staff_date_idx on public.sessions(staff_id, session_date desc);

create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.staff enable row level security;
alter table public.sessions enable row level security;
alter table public.banners enable row level security;
alter table public.bookings enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.favorites enable row level security;

create policy "profiles read self or admin" on public.profiles for select
using (id = auth.uid() or public.is_admin());
create policy "profiles update self or admin" on public.profiles for update
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

create policy "active staff visible" on public.staff for select
using (is_active or public.is_admin());
create policy "admin manages staff" on public.staff for all
using (public.is_admin()) with check (public.is_admin());

create policy "sessions visible to signed in" on public.sessions for select
using (auth.uid() is not null);
create policy "admin manages sessions" on public.sessions for all
using (public.is_admin()) with check (public.is_admin());

create policy "active banners visible" on public.banners for select
using (is_active or public.is_admin());
create policy "admin manages banners" on public.banners for all
using (public.is_admin()) with check (public.is_admin());

create policy "customer reads own bookings or admin" on public.bookings for select
using (customer_id = auth.uid() or public.is_admin());
create policy "customer creates own booking" on public.bookings for insert
with check (customer_id = auth.uid());
create policy "admin manages bookings" on public.bookings for all
using (public.is_admin()) with check (public.is_admin());

create policy "customer reads own conversations or admin" on public.conversations for select
using (customer_id = auth.uid() or public.is_admin());
create policy "customer creates own conversation" on public.conversations for insert
with check (customer_id = auth.uid());
create policy "participants read messages" on public.messages for select
using (
  public.is_admin() or exists (
    select 1 from public.conversations c
    where c.id = conversation_id and c.customer_id = auth.uid()
  )
);
create policy "participants send messages" on public.messages for insert
with check (
  sender_id = auth.uid() and (
    public.is_admin() or exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.customer_id = auth.uid()
    )
  )
);

create policy "customer manages own favorites" on public.favorites for all
using (customer_id = auth.uid()) with check (customer_id = auth.uid());
