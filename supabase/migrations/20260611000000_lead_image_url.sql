-- Lead-card art: the deck's cover card gets its own generated image instead
-- of borrowing the first story's, which made cards 1 and 2 visibly identical.
alter table public.briefings add column if not exists lead_image_url text;
