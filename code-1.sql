-- Businesses
create table businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete cascade,
  name text not null,
  qr_slug text unique not null,          -- e.g. "marias-hair-studio-x7k2"
  created_at timestamptz default now()
);

-- Counters (Counter 1, Counter 2, …)
create table counters (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references businesses(id) on delete cascade,
  label text not null,                    -- "Counter 1"
  current_entry_id uuid,                  -- who is being served right now
  created_at timestamptz default now()
);

-- Queue entries
create table queue_entries (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references businesses(id) on delete cascade,
  counter_id uuid references counters(id),   -- null while waiting
  customer_name text not null,
  phone text,                                 -- optional, for SMS
  queue_number int not null,
  status text not null default 'waiting'
      check (status in ('waiting','serving','served','no-show')),
  joined_at timestamptz default now(),
  called_at timestamptz
);

-- Daily counter for queue numbers, resets per business per day
create table queue_counters (
  business_id uuid,
  day date,
  last_number int default 0,
  primary key (business_id, day)
);

-- Realtime: broadcast changes on queue_entries
alter publication supabase_realtime add table queue_entries;

-- RLS: anyone can join a queue; only owners manage theirs
alter table queue_entries enable row level security;
create policy "public join" on queue_entries
  for insert with check (true);
create policy "public read" on queue_entries
  for select using (true);
create policy "owner update" on queue_entries
  for update using (
    auth.uid() = (select owner_id from businesses
                  where businesses.id = queue_entries.business_id)
  );
