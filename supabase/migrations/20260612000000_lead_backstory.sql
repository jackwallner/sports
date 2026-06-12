-- The deck's cover card gets a flip side: 2-3 sentences of context behind
-- the TL;DR, so the first card a user sees can back itself up like every
-- story card does.
alter table public.briefings add column if not exists lead_backstory text;
