import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'
const supabase = createClient('YOUR_PROJECT_URL', 'YOUR_ANON_KEY')
const slug = location.pathname.split('/').pop() // join-page slug from QR link

// 1. Load the business once
const { data: biz } = await supabase
  .from('businesses').select('id, name')
  .eq('qr_slug', slug).single()

// 2. Join queue (atomic number via the counter row)
async function joinQueue(name, phone) {
  const day = new Date().toISOString().slice(0, 10)
  const { data: num } = await supabase.rpc('take_next_number', {
    p_business: biz.id, p_day: day
  }) // postgres function: increments queue_counters, returns the number
  await supabase.from('queue_entries').insert({
    business_id: biz.id, customer_name: name, phone, queue_number: num
  })
}

// 3. Live sync — replaces every manual render() call
supabase.channel(`queue-${biz.id}`)
  .on('postgres_changes',
    { event: '*', schema: 'public', table: 'queue_entries', filter: `business_id=eq.${biz.id}` },
    () => loadQueue()
  ).subscribe()

async function loadQueue() {
  const { data: rows } = await supabase
    .from('queue_entries')
    .select('*')
    .eq('business_id', biz.id)
    .in('status', ['waiting', 'serving'])
    .order('queue_number')
  queue = rows.map(r => ({
    id: r.id, num: r.queue_number, name: r.customer_name,
    status: r.status, at: new Date(r.joined_at).getTime()
  }))
  render()
}

// 4. Call next → assign to counter, timestamp it
async function callNext() {
  const next = queue.find(q => q.status === 'waiting')
  if (!next) return
  await supabase.from('queue_entries').update({
    status: 'serving', counter_id: currentCounterId, called_at: new Date()
  }).eq('id', next.id)
}

// 5. No-show
const noShow = id =>
  supabase.from('queue_entries').update({ status: 'no-show' }).eq('id', id)
